
local M = {}

local bitstream = require("samp_r5_modules.bitstream")

-- =========================================================
-- Parse all frames in packet (sub_10047D20 + sub_10045650)
-- =========================================================
function M.parse_all_raknet_frames(tvb)
    -- Если пакет создан нашим экспортером (начинается с 0xFE), возвращаем его целиком как 1 фрейм
    if tvb:len() >= 2 and tvb(0, 1):uint() == 0xFE then
        local frame_tvb = tvb(1):tvb("Unpacked SA-MP Frame")
        local pkt_id = frame_tvb(0, 1):uint()
        local rpc_id = (pkt_id == 20 and frame_tvb:len() >= 2) and frame_tvb(1, 1):uint() or nil
        return {{
            reliability = 8,
            is_split = false,
            split_id = 0,
            split_index = 0,
            split_count = 0,
            pkt_id = pkt_id,
            rpc_id = rpc_id,
            frame_tvb = frame_tvb
        }}
    end
    
    local br = bitstream.make_bit_reader(tvb)
    local frames = {}

    -- 1. Читаем 1 бит наличия ACK
    local has_acks = br:read_bit()
    if has_acks == nil then return frames end

    if has_acks == 1 then
        local count = br:read_compressed_u16()
        if not count or count > 128 then return frames end
        for _ = 1, count do
            local min_eq_max = br:read_bit()
            if min_eq_max == nil then return frames end
            if min_eq_max == 1 then
                if not br:read_u16_le() then return frames end
            else
                if not br:read_u16_le() or not br:read_u16_le() then return frames end
            end
        end
    end

    -- 2. Читаем все кадры подряд
    local safety_limit = 0
    while br.bit_pos + 16 <= br.total_bits and safety_limit < 64 do
        safety_limit = safety_limit + 1

        local msg_num = br:read_u16_le()
        local reliability = br:read_bits(4)

        if not msg_num or not reliability or reliability < 6 or reliability > 10 then
            break
        end

        if reliability == 7 or reliability == 9 or reliability == 10 then
            if not br:read_bits(5) then break end
            if not br:read_u16_le() then break end
        end

        local has_split = br:read_bit()
        local split_id = 0
        local split_index = 0
        local split_count = 0
        if has_split == nil then break end
        if has_split == 1 then
            split_id = br:read_u16_le()            -- splitPacketId
            split_index = br:read_u32_le()         -- splitPacketIndex
            split_count = br:read_u32_le()         -- splitPacketCount
            if not split_id or not split_index or not split_count then break end
        end

        -- Длина полезных данных в битах
        local data_bit_len = br:read_compressed_u16()
        if not data_bit_len or data_bit_len == 0 then
            break
        end

        br:align_to_byte()
        local byte_offset = math.floor(br.bit_pos / 8)
        local byte_len = math.ceil(data_bit_len / 8)

        if byte_offset + byte_len > tvb:len() then
            break
        end

        local frame_tvb = tvb(byte_offset, byte_len):tvb("SA-MP Frame")
        local pkt_id = frame_tvb(0, 1):uint()
        local rpc_id = nil

        if pkt_id == 20 and (has_split == 0 or split_index == 0) and frame_tvb:len() >= 2 then
            rpc_id = frame_tvb(1, 1):uint()
        end

        table.insert(frames, {
            reliability = reliability,
            is_split = (has_split == 1),
            split_id = split_id,
            split_index = split_index,
            split_count = split_count,
            pkt_id = pkt_id,
            rpc_id = rpc_id,
            frame_tvb = frame_tvb
        })

        -- Сдвигаем позицию на границу байта после полезных данных фрейма
        br.bit_pos = (byte_offset + byte_len) * 8
    end

    return frames
end

function M.process_split_frame(fr, pinfo_number, visited)
    if not fr.is_split then
        return fr.frame_tvb, true
    end

    -- Если пакет уже обрабатывался при первом проходе, берём результат из кеша
    if visited then
        local cached = reassembled_cache[pinfo_number]
        if cached then
            return cached:tvb("Reassembled SA-MP Frame"), true
        end
        return nil, false
    end

    local sid = fr.split_id
    if not split_reassembly[sid] then
        split_reassembly[sid] = {
            count = fr.split_count,
            received = 0,
            chunks = {}
        }
    end

    local entry = split_reassembly[sid]
    if not entry.chunks[fr.split_index] then
        entry.chunks[fr.split_index] = fr.frame_tvb:bytes()
        entry.received = entry.received + 1
    end

    if entry.received < entry.count then
        return nil, false
    end

    local full_bytes = ByteArray.new()
    for i = 0, entry.count - 1 do
        if entry.chunks[i] then
            full_bytes:append(entry.chunks[i])
        end
    end

    split_reassembly[sid] = nil
    reassembled_cache[pinfo_number] = full_bytes
    return full_bytes:tvb("Reassembled SA-MP Frame"), true
end

function M.decode_raknet_acks(tvb, parent_tree)
    local br = bitstream.make_bit_reader(tvb)
    local has_acks = br:read_bit()
    if has_acks ~= 1 then
        return nil
    end

    local count = br:read_compressed_u16()
    if not count or count == 0 or count > 128 then
        return nil
    end

    local ack_tree = parent_tree:add(string.format("RakNet ACK Ranges (%d):", count))
    local ranges = {}

    for i = 1, count do
        local min_eq_max = br:read_bit()
        if min_eq_max == nil then break end

        if min_eq_max == 1 then
            local seq = br:read_u16_le()
            if not seq then break end
            ack_tree:add(string.format("Range #%d: Msg #%d", i, seq))
            table.insert(ranges, tostring(seq))
        else
            local min_seq = br:read_u16_le()
            local max_seq = br:read_u16_le()
            if not min_seq or not max_seq then break end
            ack_tree:add(string.format("Range #%d: Msg #%d .. #%d", i, min_seq, max_seq))
            table.insert(ranges, string.format("%d..%d", min_seq, max_seq))
        end
    end

    if #ranges == 0 then return nil end
    return table.concat(ranges, ", ")
end

return M