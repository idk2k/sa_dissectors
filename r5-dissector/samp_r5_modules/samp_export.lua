

local crypto = require("samp_r5_modules.crypto")

local M = {}

local export_dumper = nil
local export_active = false
local export_count_in = 0
local export_count_out = 0
local export_split_buf = {}

local target_port = 7777


local function build_udp_pcap_packet(src_ip_str, dst_ip_str, src_port, dst_port, payload_bytes)
    local function ip_to_bytes(ip)
        local b1, b2, b3, b4 = ip:match("(%d+)%.(%d+)%.(%d+)%.(%d+)")
        if not b1 then return "\127\0\0\1" end
        return string.char(tonumber(b1), tonumber(b2), tonumber(b3), tonumber(b4))
    end

    local function u16_be(n)
        return string.char(bit.band(bit.rshift(n, 8), 0xFF), bit.band(n, 0xFF))
    end

    local payload_str = payload_bytes:raw()
    local udp_len = 8 + #payload_str
    local ip_len = 20 + udp_len

    -- Ethernet Header (14 bytes): Dst MAC + Src MAC + EtherType IPv4 (0x0800)
    local eth = "\0\0\0\0\0\1\0\0\0\0\0\2\8\0"

    -- IPv4 Header (20 bytes)
    local ip_hdr = "\69\0" .. u16_be(ip_len) .. "\0\0\64\0\64\17\0\0" ..
                   ip_to_bytes(src_ip_str) .. ip_to_bytes(dst_ip_str)

    -- UDP Header (8 bytes)
    local udp_hdr = u16_be(src_port) .. u16_be(dst_port) .. u16_be(udp_len) .. "\0\0"

    return ByteArray.new(eth .. ip_hdr .. udp_hdr .. payload_str, true)
end

local function wrap_single_raknet_frame(frame_bytes)
    local out = ByteArray.new("FE")
    out:append(frame_bytes)
    return out
end

local function unpack_to_pcap_menu()
    if not gui_enabled() then return end

    local out_path = persconffile_path("samp_unpacked.pcap")
    export_dumper = Dumper.new(out_path, wtap_encaps.ETHERNET)
    if not export_dumper then
        report_failure("Не удалось создать файл: " .. out_path)
        return
    end

    export_active = true
    export_count_in = 0
    export_count_out = 0
    export_split_buf = {}

    retap_packets()

    export_dumper:flush()
    export_dumper:close()
    export_dumper = nil
    export_active = false
    export_split_buf = {}

    local win = TextWindow.new("SA-MP Unpack Complete")
    win:set(string.format(
        "Распаковка завершена успешно!\n\nВходящих фреймов (Server -> Client): %d\nИсходящих фреймов (Client -> Server): %d\nВсего сохранено: %d\n\nПуть к файлу:\n%s\n\nОткройте этот файл в Wireshark (File -> Open).",
        export_count_in, export_count_out, export_count_in + export_count_out, out_path
    ))
end

function M.init(samp_proto, get_port_fn, parse_all_raknet_frames)
    local export_tap = Listener.new("udp")

    function export_tap.packet(pinfo, tvb)
        if not export_active or not export_dumper then return end

        local srv_port = samp_proto.prefs.server_port
        local src_port = pinfo.src_port
        local dst_port = pinfo.dst_port

        if src_port ~= srv_port and dst_port ~= srv_port then
            return
        end

        local src_ip = tostring(pinfo.src)
        local dst_ip = tostring(pinfo.dst)

        -- Поддержка Ethernet (14 байт) + IPv4
        if tvb:len() < 34 then return end
        local ip_hdr_len = bit.band(tvb(14, 1):uint(), 0x0F) * 4
        local udp_offset = 14 + ip_hdr_len + 8
        if udp_offset >= tvb:len() then return end

        local payload_tvb = tvb(udp_offset):tvb("UDP Payload")
        if payload_tvb:len() < 2 then return end

        -- Пропускаем Query-пакеты лаунчера
        if payload_tvb:len() >= 4 and payload_tvb(0, 4):string() == "SAMP" then
            return
        end

        local is_incoming = (src_port == srv_port)
        local work_tvb = payload_tvb

        -- Если пакет исходящий (Client -> Server), сначала снимаем скремблер!
        if not is_incoming then
            local dec_tvb, is_valid = crypto.decrypt_outgoing_packet(payload_tvb, dst_port)
            if not dec_tvb or not is_valid then
                return
            end
            work_tvb = dec_tvb
        end

        local frames = parse_all_raknet_frames(work_tvb)
        for _, fr in ipairs(frames) do
            local ready_bytes = nil

            if not fr.is_split then
                ready_bytes = fr.frame_tvb:bytes()
            else
                local key = string.format("%s:%d->%s:%d_%d", src_ip, src_port, dst_ip, dst_port, fr.split_id)
                if not export_split_buf[key] then
                    export_split_buf[key] = { count = fr.split_count, received = 0, chunks = {} }
                end
                local entry = export_split_buf[key]
                if not entry.chunks[fr.split_index] then
                    entry.chunks[fr.split_index] = fr.frame_tvb:bytes()
                    entry.received = entry.received + 1
                end
                if entry.received >= entry.count then
                    local merged = ByteArray.new()
                    for i = 0, entry.count - 1 do
                        if entry.chunks[i] then merged:append(entry.chunks[i]) end
                    end
                    export_split_buf[key] = nil
                    ready_bytes = merged
                end
            end

            if ready_bytes then
                local wrapped = wrap_single_raknet_frame(ready_bytes)
                local raw_pkt = build_udp_pcap_packet(src_ip, dst_ip, src_port, dst_port, wrapped)
                export_dumper:dump(pinfo.abs_ts, PseudoHeader.none(), raw_pkt)
                if is_incoming then
                    export_count_in = export_count_in + 1
                else
                    export_count_out = export_count_out + 1
                end
            end
        end
    end

    register_menu("Unpack SA-MP Frames to PCAP", unpack_to_pcap_menu, MENU_TOOLS_UNSORTED)
end

return M