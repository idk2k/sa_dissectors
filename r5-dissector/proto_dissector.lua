-- SA-MP 0.3.7 Full Bidirectional Protocol Dissector (Incoming RakNet Frame Parser + Outgoing Scramble Decryptor)
local samp_proto = Proto("samp_proto", "SA-MP 0.3.7 Protocol")

local f_direction     = ProtoField.string("samp.direction", "Direction")
local f_checksum      = ProtoField.uint8("samp.checksum", "Packet Checksum", base.HEX)
local f_calc_checksum = ProtoField.uint8("samp.calc_checksum", "Calculated Checksum", base.HEX)
local f_checksum_ok   = ProtoField.bool("samp.checksum_valid", "Checksum Valid")
local f_session_key   = ProtoField.uint8("samp.session_key", "Port XOR Key", base.HEX)
local f_reliability   = ProtoField.string("samp.reliability", "RakNet Reliability")
local f_packet_id     = ProtoField.uint8("samp.packet_id", "SA-MP Packet ID", base.DEC)
local f_packet_name   = ProtoField.string("samp.packet_name", "Packet Type")
local f_rpc_id        = ProtoField.uint8("samp.rpc_id", "RPC ID", base.DEC)
local f_rpc_name      = ProtoField.string("samp.rpc_name", "RPC Name")
local f_payload       = ProtoField.bytes("samp.payload", "Clean Payload")

local f_field_int   = ProtoField.int32("samp.field.int", "Field (Int)", base.DEC)
local f_field_uint  = ProtoField.uint32("samp.field.uint", "Field (Uint)", base.DEC)
local f_field_hex   = ProtoField.uint32("samp.field.hex", "Field (Hex)", base.HEX)
local f_field_float = ProtoField.double("samp.field.float", "Field (Float)")
local f_field_str   = ProtoField.string("samp.field.str", "Field (String)")
local f_field_bool  = ProtoField.bool("samp.field.bool", "Field (Bool)")



samp_proto.fields = {
    f_direction, f_checksum, f_calc_checksum, f_checksum_ok,
    f_session_key, f_reliability, f_packet_id, f_packet_name,
    f_rpc_id, f_rpc_name, f_payload,
    f_field_int, f_field_uint, f_field_hex, f_field_float, f_field_str, f_field_bool

}

-- ==========================================
-- Справочники ID пакетов и RPC SA-MP
-- ==========================================
local packet_names = {}
packet_names[11] = "ID_CONNECTION_REQUEST"
packet_names[12] = "ID_AUTH_KEY"
packet_names[19] = "ID_NEW_INCOMING_CONNECTION"
packet_names[20] = "ID_RPC"
packet_names[24] = "ID_OPEN_CONNECTION_REQUEST"
packet_names[25] = "ID_OPEN_CONNECTION_REPLY"
packet_names[26] = "ID_OPEN_CONNECTION_COOKIE"
packet_names[34] = "ID_CONNECTION_REQUEST_ACCEPTED"
packet_names[34] = "ID_CONNECTION_REQUEST_ACCEPTED"
packet_names[35] = "ID_CONNECTION_ATTEMPT_FAILED"
packet_names[36] = "ID_NO_FREE_INCOMING_CONNECTIONS"
packet_names[37] = "ID_CONNECTION_BANNED"
packet_names[0] = "ID_INTERNAL_PING"
packet_names[1] = "ID_PING"
packet_names[2] = "ID_PING_OPEN_CONNECTIONS"
packet_names[3] = "ID_CONNECTED_PONG"
packet_names[4] = "ID_CONNECTION_REQUEST"
packet_names[5] = "ID_CONNECTION_REQUEST_ACCEPTED"
packet_names[6] = "ID_SECURED_CONNECTION_RESPONSE"
packet_names[7] = "ID_SECURED_CONNECTION_CONFIRMATION"
packet_names[23] = "ID_CONNECTED_PING"
packet_names[24] = "ID_OPEN_CONNECTION_REQUEST"
packet_names[30] = "ID_NEW_INCOMING_CONNECTION"
packet_names[32] = "ID_DISCONNECTION_NOTIFICATION"
packet_names[33] = "ID_DETECT_LOST_CONNECTIONS"
packet_names[40] = "ID_TIMESTAMP"
packet_names[200] = "ID_VEHICLE_SYNC (InCar)"
packet_names[201] = "ID_RCON_COMMAND"
packet_names[202] = "ID_RCON_RESPONCE"
packet_names[203] = "ID_AIM_SYNC"
packet_names[204] = "ID_WEAPONS_UPDATE"
packet_names[205] = "ID_STATS_UPDATE"
packet_names[206] = "ID_BULLET_SYNC"
packet_names[207] = "ID_PLAYER_SYNC (OnFoot)"
packet_names[208] = "ID_MARKERS_SYNC"
packet_names[209] = "ID_UNOCCUPIED_SYNC"
packet_names[210] = "ID_TRAILER_SYNC"
packet_names[211] = "ID_PASSENGER_SYNC"
packet_names[212] = "ID_SPECTATOR_SYNC"

local rpc_names = {}
rpc_names[11] = "SetPlayerName"
rpc_names[12] = "SetPlayerPos"
rpc_names[13] = "SetPlayerPosFindZ"
rpc_names[14] = "SetPlayerHealth"
rpc_names[15] = "TogglePlayerControllable"
rpc_names[16] = "PlaySound"
rpc_names[17] = "SetPlayerWorldBounds"
rpc_names[18] = "GivePlayerMoney"
rpc_names[19] = "SetPlayerFacingAngle"
rpc_names[20] = "ResetPlayerMoney"
rpc_names[21] = "ResetPlayerWeapons"
rpc_names[22] = "GivePlayerWeapon"
rpc_names[24] = "SetVehicleParamsEx"
rpc_names[25] = "CancelEdit"
rpc_names[29] = "SetPlayerTime"
rpc_names[30] = "ToggleClock"
rpc_names[32] = "WorldPlayerAdd"
rpc_names[33] = "SetPlayerShopName"
rpc_names[34] = "SetPlayerSkillLevel"
rpc_names[35] = "SetPlayerDrunkLevel"
rpc_names[36] = "Create3DTextLabel"
rpc_names[37] = "DisableCheckpoint"
rpc_names[38] = "SetRaceCheckpoint"
rpc_names[39] = "DisableRaceCheckpoint"
rpc_names[40] = "GameModeRestart"
rpc_names[41] = "PlayAudioStreamForPlayer"
rpc_names[42] = "StopAudioStreamForPlayer"
rpc_names[43] = "RemoveBuildingForPlayer"
rpc_names[44] = "CreateObject"
rpc_names[45] = "SetObjectPos"
rpc_names[46] = "SetObjectRot"
rpc_names[47] = "DestroyObject"
rpc_names[55] = "DeathMessage"
rpc_names[56] = "SetPlayerMapIcon"
rpc_names[57] = "RemoveVehicleComponent"
rpc_names[58] = "Update3DTextLabel"
rpc_names[59] = "ChatBubble"
rpc_names[60] = "UpdateSystemTime"
rpc_names[61] = "ShowDialog"
rpc_names[63] = "DestroyPickup"
rpc_names[65] = "LinkVehicleToInterior"
rpc_names[66] = "SetPlayerArmour"
rpc_names[67] = "SetPlayerArmedWeapon"
rpc_names[68] = "SetSpawnInfo"
rpc_names[69] = "SetPlayerTeam"
rpc_names[70] = "PutPlayerInVehicle"
rpc_names[71] = "RemovePlayerFromVehicle"
rpc_names[72] = "SetPlayerColor"
rpc_names[73] = "DisplayGameText"
rpc_names[74] = "ForceClassSelection"
rpc_names[75] = "AttachObjectToPlayer"
rpc_names[76] = "InitMenu"
rpc_names[77] = "ShowMenu"
rpc_names[78] = "HideMenu"
rpc_names[79] = "CreateExplosion"
rpc_names[80] = "ShowPlayerNameTagForPlayer"
rpc_names[81] = "AttachCameraToObject"
rpc_names[82] = "InterpolateCamera"
rpc_names[84] = "SetObjectMaterial"
rpc_names[85] = "GangZoneStopFlash"
rpc_names[86] = "ApplyAnimation"
rpc_names[87] = "ClearAnimations"
rpc_names[88] = "SetPlayerSpecialAction"
rpc_names[89] = "SetPlayerFightingStyle"
rpc_names[90] = "SetPlayerVelocity"
rpc_names[91] = "SetVehicleVelocity"
rpc_names[93] = "ClientMessage"
rpc_names[94] = "SetWorldTime"
rpc_names[95] = "CreatePickup"
rpc_names[99] = "MoveObject"
rpc_names[104] = "EnableStuntBonusForAll"
rpc_names[105] = "TextDrawSetString"
rpc_names[107] = "SetCheckpoint"
rpc_names[108] = "GangZoneCreate"
rpc_names[112] = "PlayCrimeReport"
rpc_names[113] = "SetPlayerAttachedObject"
rpc_names[120] = "GangZoneDestroy"
rpc_names[121] = "GangZoneFlash"
rpc_names[122] = "StopObject"
rpc_names[123] = "SetNumberPlate"
rpc_names[124] = "TogglePlayerSpectating"
rpc_names[126] = "PlayerSpectatePlayer"
rpc_names[127] = "PlayerSpectateVehicle"
rpc_names[133] = "SetPlayerWantedLevel"
rpc_names[134] = "ShowTextDraw"
rpc_names[135] = "TextDrawHideForPlayer"
rpc_names[137] = "ServerJoin"
rpc_names[138] = "ServerQuit"
rpc_names[139] = "InitGame"
rpc_names[144] = "RemovePlayerMapIcon"
rpc_names[145] = "SetPlayerAmmo"
rpc_names[146] = "SetPlayerGravity"
rpc_names[147] = "SetVehicleHealth"
rpc_names[148] = "AttachTrailerToVehicle"
rpc_names[149] = "DetachTrailerFromVehicle"
rpc_names[152] = "SetWeather"
rpc_names[153] = "SetPlayerSkin"
rpc_names[154] = "SetPlayerInterior"
rpc_names[156] = "SetPlayerCameraPos"
rpc_names[157] = "SetPlayerCameraLookAt"
rpc_names[159] = "SetVehiclePos"
rpc_names[160] = "SetVehicleZAngle"
rpc_names[161] = "SetVehicleParamsForPlayer"
rpc_names[162] = "SetCameraBehindPlayer"
rpc_names[163] = "WorldPlayerRemove"
rpc_names[164] = "WorldVehicleAdd"
rpc_names[165] = "WorldVehicleRemove"
rpc_names[166] = "WorldPlayerDeath"
rpc_names[173] = "ApplyActorAnimation"
rpc_names[52] = "Spawn"
rpc_names[129] = "RequestSpawn"

local reliability_names = {}
reliability_names[6] = "UNRELIABLE"
reliability_names[7] = "UNRELIABLE_SEQUENCED"
reliability_names[8] = "RELIABLE"
reliability_names[9] = "RELIABLE_ORDERED"
reliability_names[10] = "RELIABLE_SEQUENCED"




-- ==========================================
-- Побитовый читатель (аналог RakNet::BitStream с ReadCompressed)
-- ==========================================
local function make_bit_reader(tvb)
    local reader = {
        tvb = tvb,
        bit_pos = 0,
        total_bits = tvb:len() * 8
    }

    function reader:read_bits(count)
        if self.bit_pos + count > self.total_bits then
            return nil
        end
        local res = 0
        for _ = 1, count do
            local byte_idx = math.floor(self.bit_pos / 8)
            local bit_in_byte = 7 - (self.bit_pos % 8)
            local b = self.tvb(byte_idx, 1):uint()
            local bit_val = bit.band(bit.rshift(b, bit_in_byte), 1)
            res = bit.bor(bit.lshift(res, 1), bit_val)
            self.bit_pos = self.bit_pos + 1
        end
        return res
    end

    function reader:read_bit()
        return self:read_bits(1)
    end


    function reader:read_u32_le()
        local b0 = self:read_bits(8)
        local b1 = self:read_bits(8)
        local b2 = self:read_bits(8)
        local b3 = self:read_bits(8)
        if not b0 or not b1 or not b2 or not b3 then return nil end
        return bit.bor(b0, bit.lshift(b1, 8), bit.lshift(b2, 16), bit.lshift(b3, 24))
    end

    -- Точная копия sub_1001FA70 (BitStream::ReadCompressed для 16-битных чисел в samp.dll)
    function reader:read_u16_le()
        local b1 = self:read_bits(8)
        local b2 = self:read_bits(8)
        if not b1 or not b2 then return nil end
        return b1 + b2 * 256
    end

    function reader:read_compressed_u16()
        local is_high_zero = self:read_bit()
        if is_high_zero == nil then return nil end
        if is_high_zero == 0 then
            return self:read_u16_le()
        end
        local is_nibble_zero = self:read_bit()
        if is_nibble_zero == nil then return nil end
        if is_nibble_zero == 1 then
            return self:read_bits(4)
        else
            return self:read_bits(8)
        end
    end

    function reader:read_compressed_u16_str()
        return self:read_compressed_u16()
    end

    -- Точная копия BitStream::ReadCompressed для 32-битных чисел (длина RPC в RakNet)
        -- Точная копия BitStream::ReadCompressed для 32-битных чисел (без массивов)

    -- 1. ИСПРАВЛЕННЫЙ read_compressed_u32 (без лишнего align_to_byte!)
    function reader:read_compressed_u32()
        local z3 = self:read_bit()
        if z3 == nil then return nil end
        if z3 == 0 then
            return self:read_u32_le()
        end

        local z2 = self:read_bit()
        if z2 == nil then return nil end
        if z2 == 0 then
            local b0 = self:read_bits(8)
            local b1 = self:read_bits(8)
            local b2 = self:read_bits(8)
            if not b2 then return nil end
            return bit.bor(b0, bit.lshift(b1, 8), bit.lshift(b2, 16))
        end

        local z1 = self:read_bit()
        if z1 == nil then return nil end
        if z1 == 0 then
            return self:read_u16_le()
        end

        local z0_hi = self:read_bit()
        if z0_hi == nil then return nil end
        if z0_hi == 1 then
            return self:read_bits(4)
        else
            return self:read_bits(8)
        end
    end



    function reader:align_to_byte()
        local rem = self.bit_pos % 8
        if rem ~= 0 then
            self.bit_pos = self.bit_pos + (8 - rem)
        end
    end

    function reader:read_u8()
        return self:read_bits(8)
    end

    function reader:read_i16_le()
        local v = self:read_u16_le()
        if not v then return nil end
        return (v >= 32768) and (v - 65536) or v
    end

    function reader:read_i32_le()
        local v = self:read_u32_le()
        if not v then return nil end
        return (v >= 2147483648) and (v - 4294967296) or v
    end

    -- IEEE 754 Single Precision Float (32 бита LE)
    function reader:read_float_le()
        local b0 = self:read_bits(8)
        local b1 = self:read_bits(8)
        local b2 = self:read_bits(8)
        local b3 = self:read_bits(8)
        if not b0 or not b1 or not b2 or not b3 then return nil end
        local sign = (bit.band(b3, 0x80) ~= 0) and -1 or 1
        local exp = bit.bor(bit.lshift(bit.band(b3, 0x7F), 1), bit.rshift(b2, 7))
        local mant = bit.bor(bit.lshift(bit.band(b2, 0x7F), 16), bit.lshift(b1, 8), b0)
        if exp == 0 and mant == 0 then return 0.0 end
        if exp == 255 then return sign * math.huge end
        return sign * (1.0 + mant / 8388608.0) * (2.0 ^ (exp - 127))
    end

    -- Сжатый вектор RakNet (Vector3 -> 3x float или norm * magnitude)
    function reader:read_norm_quat()
        local cw_neg = self:read_bit()
        local cx_neg = self:read_bit()
        local cy_neg = self:read_bit()
        local cz_neg = self:read_bit()
        local cx = self:read_u16_le()
        local cy = self:read_u16_le()
        local cz = self:read_u16_le()
        if not cz then return nil end
        local x = (cx / 65535.0) * ((cx_neg == 1) and -1 or 1)
        local y = (cy / 65535.0) * ((cy_neg == 1) and -1 or 1)
        local z = (cz / 65535.0) * ((cz_neg == 1) and -1 or 1)
        local w_sq = math.max(0.0, 1.0 - (x*x + y*y + z*z))
        local w = math.sqrt(w_sq) * ((cw_neg == 1) and -1 or 1)
        return string.format("w=%.3f, x=%.3f, y=%.3f, z=%.3f", w, x, y, z)
    end

        -- Перевод байта Windows-1251 в UTF-8 для отображения русского текста в Wireshark
    local function cp1251_to_utf8(b)
        if b < 0x80 then
            if b >= 32 and b ~= 127 then return string.char(b)
            elseif b == 10 then return "\\n"
            elseif b == 9 then return "\\t"
            else return "" end
        end
        if b == 0xA8 then return "\xD0\x81" end -- Ё
        if b == 0xB8 then return "\xD1\x91" end -- ё
        if b >= 0xC0 and b <= 0xEF then
            return string.char(0xD0, b - 0x30) -- А..Я и а..п
        end
        if b >= 0xF0 and b <= 0xFF then
            return string.char(0xD1, b - 0x70) -- р..я
        end
        return string.format("\\x%02X", b)
    end

    function reader:read_string(len_bytes)
        if not len_bytes or len_bytes <= 0 then return "" end
        local chars = {}
        for _ = 1, len_bytes do
            local ch = self:read_bits(8)
            if not ch then break end
            table.insert(chars, cp1251_to_utf8(ch))
        end
        return table.concat(chars)
    end


    return reader
end

-- ==========================================
-- Дерево Хаффмана RakNet (StringCompressor::DecodeString)
-- ==========================================

-- Деревья по languageId; 0 = то, что использует ShowDialog
local huffman_trees = {}

local function build_tree_from_freq(freq)
    local nodes = {}
    local function insert_sorted(node)
        if #nodes == 0 then nodes[1] = node; return end
        if nodes[1].weight >= node.weight then table.insert(nodes, 1, node); return end
        for i = 2, #nodes do
            if nodes[i].weight >= node.weight then table.insert(nodes, i, node); return end
        end
        nodes[#nodes + 1] = node
    end
    for i = 0, 255 do
        local w = freq[i]; if w == 0 then w = 1 end
        insert_sorted({ val = i, weight = w })
    end
    while #nodes > 1 do
        local l = table.remove(nodes, 1)
        local r = table.remove(nodes, 1)
        insert_sorted({ weight = l.weight + r.weight, left = l, right = r })
    end
    return nodes[1]
end

-- 2. ИСПРАВЛЕННЫЙ парсер таблицы частот строго по декомпиляту sub_1002D8E0 из IDA
local function try_parse_frequency_table(frame_tvb)
    if frame_tvb:len() < 150 then return nil end
    local br = make_bit_reader(frame_tvb)
    br.bit_pos = 8 -- пропускаем 1 байт ID пакета (a1 + 1 в IDA)

    -- Строки 26 и 32 на скриншоте IDA: два бита флагов сжатия
    if br:read_bit() ~= 1 then return nil end
    if br:read_bit() ~= 1 then return nil end

    -- Строки 43-51 на скриншоте IDA: 256 сжатых uint32
    local freq = {}
    local non_zero = 0
    for i = 0, 255 do
        local v = br:read_compressed_u32()
        if not v or v > 5000000 then return nil end
        freq[i] = v
        if v > 0 then non_zero = non_zero + 1 end
    end

    -- Строки 53-55 на скриншоте IDA: 3 хвостовых uint32
    local s1 = br:read_compressed_u32()
    local s2 = br:read_compressed_u32()
    local s3 = br:read_compressed_u32()
    if not s1 or not s2 or not s3 then return nil end

    -- Валидация: в таблице должны быть ненулевые частоты и мы не должны выйти за границы буфера
    if non_zero < 10 or br.bit_pos > br.total_bits then return nil end
    return freq
end


local huffman_root = nil

local function build_huffman_tree()
    local weights_str = "10:722,13:2,32:11084,33:58,34:63,35:1,37:31,39:317,40:64,41:64,42:44,44:695,45:62,46:980,47:266,48:69,49:67,50:56,51:7,52:73,53:3,54:14,55:2,56:69,57:1,58:167,59:9,60:1,61:2,62:25,63:94,65:195,66:139,67:34,68:96,69:48,70:103,71:56,72:125,73:653,74:21,75:5,76:23,77:64,78:85,79:44,80:34,81:7,82:92,83:76,84:147,85:12,86:14,87:57,88:15,89:39,90:15,91:1,92:1,93:1,94:2,95:3,97:3611,98:845,99:1077,100:1884,101:5870,102:841,103:1057,104:2501,105:3212,106:164,107:531,108:2019,109:1330,110:3056,111:4037,112:848,113:47,114:2586,115:2919,116:4771,117:1707,118:535,119:1106,120:152,121:1243,122:100,124:2,126:10"

    local freq = {}
    for i = 0, 255 do freq[i] = 1 end
    for k, v in weights_str:gmatch("(%d+):(%d+)") do
        freq[tonumber(k)] = tonumber(v)
    end

    local nodes = {}

    local function insert_sorted(new_node)
        if #nodes == 0 then
            nodes[1] = new_node
            return
        end
        if nodes[1].weight >= new_node.weight then
            table.insert(nodes, 1, new_node)
            return
        end
        for i = 2, #nodes do
            if nodes[i].weight >= new_node.weight then
                table.insert(nodes, i, new_node)
                return
            end
        end
        nodes[#nodes + 1] = new_node
    end

    -- Вставляем все 256 листьев в изначально пустой отсортированный список
    for i = 0, 255 do
        insert_sorted({ val = i, weight = freq[i], left = nil, right = nil })
    end

    while #nodes > 1 do
        local left = table.remove(nodes, 1)
        local right = table.remove(nodes, 1)
        insert_sorted({
            val = nil,
            weight = left.weight + right.weight,
            left = left,
            right = right
        })
    end

    return nodes[1]
end



huffman_root = build_huffman_tree()

-- Чтение строки, сжатой StringCompressor::EncodeString (включая перекодировку CP1251 -> UTF-8)
-- Исправленное чтение Huffman-строки для SA-MP R5
local function read_huffman_string(br, max_chars)
    local bit_len = br:read_compressed_u16()
    if not bit_len or bit_len == 0 then return "" end
    
    local end_bit = br.bit_pos + bit_len
    if end_bit > br.total_bits then
        end_bit = br.total_bits
    end
    
    local chars = {}
    local limit = max_chars or 4096
    
    while br.bit_pos < end_bit and #chars < limit do
        local node = huffman_root
        -- Проходим по дереву до листа
        while node and (node.left or node.right) do
            if br.bit_pos >= end_bit then break end
            
            local b = br:read_bit()
            -- ВНИМАНИЕ: В RakNet StringCompressor 0 = RIGHT, 1 = LEFT
            -- Это обратный порядок по сравнению со стандартным Huffman
            if b == 0 then
                node = node.left
            else
                node = node.right
            end
        end
        
        if not node or node.val == nil then break end
        
        local ch = node.val
        if ch == 0 then break end -- Null terminator
        
        -- CP1251 -> UTF-8 конвертация
        if ch < 0x80 then
            if ch >= 32 and ch ~= 127 then 
                table.insert(chars, string.char(ch))
            elseif ch == 10 then 
                table.insert(chars, "\\n")
            elseif ch == 9 then 
                table.insert(chars, "\\t") 
            end
        elseif ch == 0xA8 then 
            table.insert(chars, "\xD0\x81") -- Ё
        elseif ch == 0xB8 then 
            table.insert(chars, "\xD1\x91") -- ё
        elseif ch >= 0xC0 and ch <= 0xEF then 
            table.insert(chars, string.char(0xD0, ch - 0x30))
        elseif ch >= 0xF0 and ch <= 0xFF then 
            table.insert(chars, string.char(0xD1, ch - 0x70))
        end
    end
    
    -- Важно: выравниваем позицию бита до конца строки, 
    -- даже если мы вышли раньше (например, встретили null)
    br.bit_pos = end_bit
    
    return table.concat(chars)
end


-- ==========================================
-- Парсер всех фреймов в пакете (sub_10047D20 + sub_10045650)
-- ==========================================
local function parse_all_raknet_frames(tvb)
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
    
    local br = make_bit_reader(tvb)
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





-- ==========================================
-- Таблица подстановок исходящего скремблера
-- ==========================================
local enc_table = {
    0x27,0x69,0xFD,0x87,0x60,0x7D,0x83,0x02,0xF2,0x3F,0x71,0x99,0xA3,0x7C,0x1B,0x9D,
    0x76,0x30,0x23,0x25,0xC5,0x82,0x9B,0xEB,0x1E,0xFA,0x46,0x4F,0x98,0xC9,0x37,0x88,
    0x18,0xA2,0x68,0xD6,0xD7,0x22,0xD1,0x74,0x7A,0x79,0x2E,0xD2,0x6D,0x48,0x0F,0xB1,
    0x62,0x97,0xBC,0x8B,0x59,0x7F,0x29,0xB6,0xB9,0x61,0xBE,0xC8,0xC1,0xC6,0x40,0xEF,
    0x11,0x6A,0xA5,0xC7,0x3A,0xF4,0x4C,0x13,0x6C,0x2B,0x1C,0x54,0x56,0x55,0x53,0xA8,
    0xDC,0x9C,0x9A,0x16,0xDD,0xB0,0xF5,0x2D,0xFF,0xDE,0x8A,0x90,0xFC,0x95,0xEC,0x31,
    0x85,0xC2,0x01,0x06,0xDB,0x28,0xD8,0xEA,0xA0,0xDA,0x10,0x0E,0xF0,0x2A,0x6B,0x21,
    0xF1,0x86,0xFB,0x65,0xE1,0x6F,0xF6,0x26,0x33,0x39,0xAE,0xBF,0xD4,0xE4,0xE9,0x44,
    0x75,0x3D,0x63,0xBD,0xC0,0x7B,0x9E,0xA6,0x5C,0x1F,0xB2,0xA4,0xC4,0x8D,0xB3,0xFE,
    0x8F,0x19,0x8C,0x4D,0x5E,0x34,0xCC,0xF9,0xB5,0xF3,0xF8,0xA1,0x50,0x04,0x93,0x73,
    0xE0,0xBA,0xCB,0x45,0x35,0x1A,0x49,0x47,0x6E,0x2F,0x51,0x12,0xE2,0x4A,0x72,0x05,
    0x66,0x70,0xB8,0xCD,0x00,0xE5,0xBB,0x24,0x58,0xEE,0xB4,0x80,0x81,0x36,0xA9,0x67,
    0x5A,0x4B,0xE8,0xCA,0xCF,0x9F,0xE3,0xAC,0xAA,0x14,0x5B,0x5F,0x0A,0x3B,0x77,0x92,
    0x09,0x15,0x4E,0x94,0xAD,0x17,0x64,0x52,0xD3,0x38,0x43,0x0D,0x0C,0x07,0x3C,0x1D,
    0xAF,0xED,0xE7,0x08,0xB7,0x03,0xE6,0x8E,0xAB,0x91,0x89,0x3E,0x2C,0x96,0x42,0xD9,
    0x78,0xDF,0xD0,0x57,0x5D,0x84,0x41,0x7E,0xCE,0xF7,0x32,0xC3,0xD5,0x20,0x0B,0xA7
}

local function decrypt_scramble_byte(b)
    for i, val in ipairs(enc_table) do
        if val == b then
            return i - 1
        end
    end
    return 0
end

-- ==========================================
-- Декларативные схемы пакетов и RPC (легко расширять!)
-- ==========================================
-- Доступные типы: "u8", "u16", "i16", "u32", "i32", "hex32", "float", "bool",
--                 "str8", "str16", "str32", "quat", "vec3", "hp_ap_8", "hp_ap_16"

local packet_schemas_out = {
    [12] = {
        { "Auth Key", "str8" }
    },
    [19] = {
        { "Client IP (Hex)", "hex32" },
        { "Client Port",     "u16" },
        { "Internal IP",     "hex32" },
        { "Internal Port",   "u16" },
        { "Send Timestamp",  "u32" },
        { "Recv Timestamp",  "u32" }
    },
    -- ID 207: Исходящий OnFootSync (ровно 68 байт после ID)
    [207] = {
        { "Left/Right Keys", "u16" },
        { "Up/Down Keys",    "u16" },
        { "Keys",            "u16" },
        { "Pos X",           "float" },
        { "Pos Y",           "float" },
        { "Pos Z",           "float" },
        { "Quat W",          "float" },
        { "Quat X",          "float" },
        { "Quat Y",          "float" },
        { "Quat Z",          "float" },
        { "Health",          "u8" },
        { "Armour",          "u8" },
        { "Weapon / Key",    "u8" },
        { "Special Action",  "u8" },
        { "Vel X",           "float" },
        { "Vel Y",           "float" },
        { "Vel Z",           "float" },
        { "Surf Offset X",   "float" },
        { "Surf Offset Y",   "float" },
        { "Surf Offset Z",   "float" },
        { "Surf Vehicle ID", "u16" },
        { "Anim ID",         "u16" },
        { "Anim Flags",      "u16" }
    },
    -- ID 200: Исходящий InCarSync (63 байта после ID)
    [200] = {
        { "Vehicle ID",      "u16" },
        { "Left/Right Keys", "u16" },
        { "Up/Down Keys",    "u16" },
        { "Keys",            "u16" },
        { "Quat W",          "float" },
        { "Quat X",          "float" },
        { "Quat Y",          "float" },
        { "Quat Z",          "float" },
        { "Pos X",           "float" },
        { "Pos Y",           "float" },
        { "Pos Z",           "float" },
        { "Vel X",           "float" },
        { "Vel Y",           "float" },
        { "Vel Z",           "float" },
        { "Car Health",      "float" },
        { "Player Health",   "u8" },
        { "Player Armour",   "u8" },
        { "Weapon / Key",    "u8" },
        { "Siren",           "u8" },
        { "Landing Gear",    "u8" },
        { "Trailer ID",      "u16" }
    },
    -- ID 203: AimSync
    [203] = {
        { "Cam Mode",        "u8" },
        { "Cam Front X",     "float" },
        { "Cam Front Y",     "float" },
        { "Cam Front Z",     "float" },
        { "Cam Pos X",       "float" },
        { "Cam Pos Y",       "float" },
        { "Cam Pos Z",       "float" },
        { "Aim Z",           "float" },
        { "Cam Ext / Zoom",  "u8" },
        { "Weapon State",    "u8" },
        { "Aspect Ratio",    "u8" }
    },
    -- ID 206: BulletSync
    [206] = {
        { "Hit Type",        "u8" },
        { "Hit ID",          "u16" },
        { "Origin X",        "float" },
        { "Origin Y",        "float" },
        { "Origin Z",        "float" },
        { "Target X",        "float" },
        { "Target Y",        "float" },
        { "Target Z",        "float" },
        { "Center X",        "float" },
        { "Center Y",        "float" },
        { "Center Z",        "float" },
        { "Weapon ID",       "u8" }
    }
}

local packet_schemas_in = {
    [12] = {
        { "Auth Challenge", "str8" }
    },
    [34] = {
        { "Client IP (Hex)", "hex32" },
        { "Client Port",     "u16" },
        { "Your Player ID",  "u16" },
        { "Challenge Key",   "hex32" }
    }
}



local rpc_names_out = {
    [25]  = "ClientJoin",
    [50]  = "ServerCommand",
    [52]  = "Spawn",
    [53]  = "Death",
    [101] = "Chat",
    [115] = "ClickTextDraw",
    [128] = "RequestClass",
    [129] = "RequestSpawn",
    [136] = "VehicleDestroyed",
    [154] = "GiveTakeDamage"
}

-- Схемы RPC (работают для входящих и исходящих RPC!)
local rpc_schemas = {
    -- #68: SetSpawnInfo (установка параметров спавна игрока)
    [68] = {
        { "Team",          "u8" },
        { "Skin ID",       "i32" },
        { "Unknown Byte",  "u8" },
        { "Pos X",         "float" },
        { "Pos Y",         "float" },
        { "Pos Z",         "float" },
        { "Rotation",      "float" },
        { "Weapon 1",      "i32" },
        { "Weapon 2",      "i32" },
        { "Weapon 3",      "i32" },
        { "Ammo 1",        "i32" },
        { "Ammo 2",        "i32" },
        { "Ammo 3",        "i32" }
    },
    -- #60: UpdateSystemTime (синхронизация системного времени сервера)
    [60] = {
        { "System Time (ms)", "u32" }
    },

    -- #94: SetWorldTime (установка игрового часа 0..23)
    [94] = {
        { "Hour", "u8" }
    },
    -- #134: ShowTextDraw (создание и показ текстдрава на экране)
    [134] = {
        { "TextDraw ID",     "u16" },
        { "Flags",           "u8" },
        { "Letter Width",    "float" },
        { "Letter Height",   "float" },
        { "Letter Color",    "hex32" },
        { "Line Width",      "float" },
        { "Line Height",     "float" },
        { "Box Color",       "hex32" },
        { "Shadow",          "u8" },
        { "Outline",         "u8" },
        { "Background Color","hex32" },
        { "Style",           "u8" },
        { "Selectable",      "u8" },
        { "Pos X",           "float" },
        { "Pos Y",           "float" },
        { "Model ID",        "u16" },
        { "Rot X",           "float" },
        { "Rot Y",           "float" },
        { "Rot Z",           "float" },
        { "Zoom",            "float" },
        { "Color 1",         "u16" },
        { "Color 2",         "u16" },
        { "Text",            "str16" }
    },
    -- #25: ClientJoin (отправка ника, GPCI и версии клиента при входе)
    [25] = {
        { "Version",            "u32" },
        { "Mod",                "u8" },
        { "Nickname",           "str8" },
        { "Challenge Response", "hex32" },
        { "GPCI",               "str8" },
        { "Client Version",     "str8" }
    },
    -- #44: CreateObject (создание объекта в зоне стрима)
    [44] = {
        { "Object ID",     "u16" },
        { "Model ID",      "u32" },
        { "Pos X",         "float" },
        { "Pos Y",         "float" },
        { "Pos Z",         "float" },
        { "Rot X",         "float" },
        { "Rot Y",         "float" },
        { "Rot Z",         "float" },
        { "Draw Distance", "float" },
        { "No Camera Col", "u8" }
    },
    -- #137: ServerJoin (подключение игрока на сервер)
    [137] = {
        { "Player ID", "u16" },
        { "Color",     "hex32" },
        { "Is NPC",    "u8" },
        { "Nickname",  "str8" }
    },

    -- #12: SetPlayerPos
    [12] = {
        { "Pos X", "float" },
        { "Pos Y", "float" },
        { "Pos Z", "float" }
    },
    -- #14: SetPlayerHealth
    [14] = {
        { "Health", "float" }
    },
    -- #15: TogglePlayerControllable
    [15] = {
        { "Controllable", "u8" }
    },
    -- #18: GivePlayerMoney
    [18] = {
        { "Money", "i32" }
    },
    -- #19: SetPlayerFacingAngle
    [19] = {
        { "Angle", "float" }
    },
    -- #22: GivePlayerWeapon
    [22] = {
        { "Weapon ID", "u32" },
        { "Ammo",      "u32" }
    },
    -- #32: WorldPlayerAdd (входящий стрим игрока)
    [32] = {
        { "Player ID", "u16" },
        { "Team",      "u8" },
        { "Skin ID",   "u32" },
        { "Pos X",     "float" },
        { "Pos Y",     "float" },
        { "Pos Z",     "float" },
        { "Angle",     "float" },
        { "Color",     "hex32" },
        { "FightStyle","u8" }
    },
    -- #43: RemoveBuildingForPlayer (видели на скриншоте!)
    [43] = {
        { "Model ID", "u32" },
        { "Pos X",    "float" },
        { "Pos Y",    "float" },
        { "Pos Z",    "float" },
        { "Radius",   "float" }
    },
    -- #47: DestroyObject (видели на скриншоте!)
    [47] = {
        { "Object ID", "u16" }
    },
    -- #50: ServerCommand (исходящая команда /...)
    [50] = {
        { "Command", "str32" }
    },
    -- #56: SetPlayerMapIcon (видели на скриншоте!)
    [56] = {
        { "Icon ID",  "u8" },
        { "Pos X",    "float" },
        { "Pos Y",    "float" },
        { "Pos Z",    "float" },
        { "Type",     "u8" },
        { "Color",    "hex32" },
        { "Style",    "u8" }
    },
    -- #59: ChatBubble (текст над головой игрока)
    [59] = {
        { "Player ID", "u16" },
        { "Color",     "hex32" },
        { "Distance",  "float" },
        { "Duration",  "u32" },
        { "Message",   "str8" }
    },
    -- #61: ShowDialog (заголовок и кнопки открытые, а основной текст диалога сжат Хаффманом!)
    [61] = {
        { "Dialog ID", "u16" },
        { "Style",     "u8" },
        { "Title",     "str8" },
        { "Button 1",  "str8" },
        { "Button 2",  "str8" },
        { "Body Text", "huff" }
    },
    -- #62: DialogResponse (исходящий ответ на диалог)
    [62] = {
        { "Dialog ID", "u16" },
        { "Button",    "u8" },
        { "List Item", "i16" },
        { "Input Text","str8" }
    },
    -- #66: SetPlayerArmour
    [66] = {
        { "Armour", "float" }
    },
    -- #70: PutPlayerInVehicle
    [70] = {
        { "Vehicle ID", "u16" },
        { "Seat ID",    "u8" }
    },
    -- #72: SetPlayerColor
    [72] = {
        { "Player ID", "u16" },
        { "Color",     "hex32" }
    },
    -- #73: DisplayGameText
    [73] = {
        { "Style", "u32" },
        { "Time",  "u32" },
        { "Text",  "str32" }
    },
    -- #86: ApplyAnimation
    [86] = {
        { "Player ID", "u16" },
        { "Anim Lib",  "str8" },
        { "Anim Name", "str8" },
        { "Delta",     "float" },
        { "Loop",      "u8" },
        { "Lock X",    "u8" },
        { "Lock Y",    "u8" },
        { "Freeze",    "u8" },
        { "Time",      "u32" }
    },
    -- #93: ClientMessage
    [93] = {
        { "Color",   "hex32" },
        { "Message", "str32" }
    },
    -- #95: CreatePickup (видели на скриншоте!)
    [95] = {
        { "Pickup ID", "i32" },
        { "Model ID",  "i32" },
        { "Type",      "i32" },
        { "Pos X",     "float" },
        { "Pos Y",     "float" },
        { "Pos Z",     "float" }
    },
    -- #101: Chat (исходящее сообщение в чат)
    [101] = {
        { "Text", "str8" }
    },
    -- #108: GangZoneCreate (видели на скриншоте!)
    [108] = {
        { "Zone ID", "u16" },
        { "Min X",   "float" },
        { "Min Y",   "float" },
        { "Max X",   "float" },
        { "Max Y",   "float" },
        { "Color",   "hex32" }
    },
    -- #113: SetPlayerAttachedObject (видели на скриншоте!)
    [113] = {
        { "Player ID", "u16" },
        { "Index",     "u32" },
        { "Create",    "u8" },
        { "Model ID",  "u32" },
        { "Bone",      "u32" },
        { "Offset X",  "float" },
        { "Offset Y",  "float" },
        { "Offset Z",  "float" },
        { "Rot X",     "float" },
        { "Rot Y",     "float" },
        { "Rot Z",     "float" },
        { "Scale X",   "float" },
        { "Scale Y",   "float" },
        { "Scale Z",   "float" }
    },
    -- #153: SetPlayerSkin
    [153] = {
        { "Player ID", "u32" },
        { "Skin ID",   "u32" }
    },
    -- #156: SetPlayerCameraPos (видели на скриншоте!)
    [156] = {
        { "Pos X", "float" },
        { "Pos Y", "float" },
        { "Pos Z", "float" }
    },
    -- #157: SetPlayerCameraLookAt
    [157] = {
        { "Look X", "float" },
        { "Look Y", "float" },
        { "Look Z", "float" },
        { "Cut",    "u8" }
    },
    -- #163: WorldPlayerRemove
    [163] = {
        { "Player ID", "u16" }
    },
    -- #164: WorldVehicleAdd (видели на скриншоте!)
    [164] = {
        { "Vehicle ID", "u16" },
        { "Model ID",   "u32" },
        { "Pos X",      "float" },
        { "Pos Y",      "float" },
        { "Pos Z",      "float" },
        { "Angle",      "float" },
        { "Color 1",    "u8" },
        { "Color 2",    "u8" },
        { "Health",     "float" },
        { "Interior",   "u8" },
        { "Doors",      "u32" },
        { "Panels",     "u32" },
        { "Lights",     "u8" },
        { "Tires",      "u8" },
        { "Siren",      "u8" }
    },
    -- #165: WorldVehicleRemove
    [165] = {
        { "Vehicle ID", "u16" }
    }
}

-- Движок разбора полей по схеме
local function decode_by_schema(tvb, start_bit, total_bits, schema, parent_tree)
    if not schema or (tvb:len() * 8) <= start_bit then return nil end

    local br = make_bit_reader(tvb)
    br.bit_pos = start_bit
    if total_bits and total_bits > 0 then
        br.total_bits = math.min(br.total_bits, total_bits)
    end

    local byte_off = math.floor(start_bit / 8)
    local sub_tvb = tvb(byte_off, tvb:len() - byte_off):tvb("Fields")
    local fields_tree = parent_tree:add(samp_proto, sub_tvb(), "Decoded Fields")
    local summary = {}


    for _, item in ipairs(schema) do
        local _, name = next(item)
        local _, ftype = next(item, 1)
        local val = nil
        local str_val = nil

        if ftype == "u8" then
            val = br:read_u8()
            if val then
                fields_tree:add(f_field_uint, val):set_text(string.format("%s: %d (0x%02X)", name, val, val))
                str_val = tostring(val)
            end
        elseif ftype == "u16" then
            val = br:read_u16_le()
            if val then
                fields_tree:add(f_field_uint, val):set_text(string.format("%s: %d (0x%04X)", name, val, val))
                str_val = tostring(val)
            end
        elseif ftype == "i16" then
            val = br:read_i16_le()
            if val then
                fields_tree:add(f_field_int, val):set_text(string.format("%s: %d", name, val))
                str_val = tostring(val)
            end
        elseif ftype == "u32" then
            val = br:read_u32_le()
            if val then
                fields_tree:add(f_field_uint, val):set_text(string.format("%s: %d", name, val))
                str_val = tostring(val)
            end
        elseif ftype == "i32" then
            val = br:read_i32_le()
            if val then
                fields_tree:add(f_field_int, val):set_text(string.format("%s: %d", name, val))
                str_val = tostring(val)
            end
        elseif ftype == "hex32" then
            val = br:read_u32_le()
            if val then
                fields_tree:add(f_field_hex, val):set_text(string.format("%s: 0x%08X", name, val))
                str_val = string.format("0x%08X", val)
            end
        elseif ftype == "float" then
            val = br:read_float_le()
            if val then
                fields_tree:add(f_field_float, val):set_text(string.format("%s: %.3f", name, val))
                str_val = string.format("%.2f", val)
            end
        elseif ftype == "str8" then
            local slen = br:read_u8()
            if slen then
                val = br:read_string(slen)
                fields_tree:add(f_field_str, val):set_text(string.format('%s (%d): "%s"', name, slen, val))
                str_val = string.format('"%s"', val)
            end
        elseif ftype == "str16" then
            local slen = br:read_u16_le()
            if slen then
                val = br:read_string(slen)
                fields_tree:add(f_field_str, val):set_text(string.format('%s (%d): "%s"', name, slen, val))
                str_val = string.format('"%s"', val)
            end
        elseif ftype == "str32" then
            local slen = br:read_u32_le()
            if slen and slen < 4096 then
                val = br:read_string(slen)
                fields_tree:add(f_field_str, val):set_text(string.format('%s (%d): "%s"', name, slen, val))
                str_val = string.format('"%s"', val)
            end
        elseif ftype == "huff" then
            val = read_huffman_string(br, 4096)
            if val then
                if #val > 100 then
                    local huff_node = fields_tree:add(f_field_str, val)
                    huff_node:set_text(string.format('%s (Huffman, %d bytes):', name, #val))
                    -- Разбиваем по экранированному "\n" или реальному переводу строки
                    local normalized = val:gsub("\\n", "\n")
                    for line in (normalized .. "\n"):gmatch("(.-)\n") do
                        if line ~= "" then
                            -- Безопасная нарезка UTF-8 без разрыва 2-байтовых русских букв
                            local pos = 1
                            while pos <= #line do
                                local end_pos = math.min(pos + 110, #line)
                                while end_pos < #line and bit.band(line:byte(end_pos + 1), 0xC0) == 0x80 do
                                    end_pos = end_pos + 1
                                end
                                huff_node:add(line:sub(pos, end_pos))
                                pos = end_pos + 1
                            end
                        end
                    end
                else
                    fields_tree:add(f_field_str, val):set_text(string.format('%s (Huffman): "%s"', name, val))
                end
                str_val = string.format('"%s"', val)
            end
        end


        if val == nil then break end
        if #summary < 4 then
            table.insert(summary, string.format("%s=%s", name, str_val))
        end
    end

    return (#summary > 0) and table.concat(summary, ", ") or nil
end

-- ==========================================
-- Побитовый декодер входящей синхронизации (ID 207 OnFoot / ID 200 InCar)
-- ==========================================
local function decode_incoming_sync(tvb, pkt_id, parent_tree)
    if tvb:len() < 3 then return nil end

    local sub_tvb = tvb(1, tvb:len() - 1):tvb("Incoming Sync Data")
    local br = make_bit_reader(sub_tvb)
    local tree = parent_tree:add(samp_proto, sub_tvb(), "Decoded Incoming Sync")

    -- Вспомогательная функция чтения сжатого вектора RakNet (BitStream::ReadVector)
    local function read_compressed_vec()
        local mag = br:read_float_le()
        if not mag then return nil end
        if mag > 0.00001 then
            local cx = br:read_u16_le()
            local cy = br:read_u16_le()
            local cz = br:read_u16_le()
            if not cz then return nil end
            local x = ((cx / 32767.5) - 1.0) * mag
            local y = ((cy / 32767.5) - 1.0) * mag
            local z = ((cz / 32767.5) - 1.0) * mag
            return x, y, z
        end
        return 0.0, 0.0, 0.0
    end

    -- 1. ВХОДЯЩИЙ ONFOOT SYNC (ID 207)
    if pkt_id == 207 then
        local player_id = br:read_u16_le()
        if not player_id then return nil end
        tree:add(f_field_uint, player_id):set_text(string.format("Player ID: %d", player_id))

        -- Опциональные клавиши (1 бит на каждое поле)
        if br:read_bit() == 1 then
            local lr = br:read_u16_le()
            if lr then tree:add(f_field_uint, lr):set_text(string.format("Left/Right Keys: %d", lr)) end
        end
        if br:read_bit() == 1 then
            local ud = br:read_u16_le()
            if ud then tree:add(f_field_uint, ud):set_text(string.format("Up/Down Keys: %d", ud)) end
        end
        local keys = br:read_u16_le()
        if keys then tree:add(f_field_uint, keys):set_text(string.format("Keys: 0x%04X", keys)) end

        -- Координаты позиции (всегда 3 float)
        local px = br:read_float_le()
        local py = br:read_float_le()
        local pz = br:read_float_le()
        if not pz then return string.format("Player=%d", player_id) end

        tree:add(f_field_float, px):set_text(string.format("Pos X: %.3f", px))
        tree:add(f_field_float, py):set_text(string.format("Pos Y: %.3f", py))
        tree:add(f_field_float, pz):set_text(string.format("Pos Z: %.3f", pz))

        -- Сжатый кватернион поворота
        local quat_str = br:read_norm_quat()
        if quat_str then
            tree:add(f_field_str, quat_str):set_text("Rotation Quat: " .. quat_str)
        end

        -- Упакованные HP и Armour (1 байт: старшие 4 бита * 7 = HP, младшие 4 бита * 7 = AP)
        local hp_ap = br:read_u8()
        local hp_val = 0
        if hp_ap then
            local h_nib = bit.rshift(hp_ap, 4)
            local a_nib = bit.band(hp_ap, 0x0F)
            hp_val = (h_nib == 0x0F) and 100 or (h_nib * 7)
            local ap_val = (a_nib == 0x0F) and 100 or (a_nib * 7)
            tree:add(f_field_uint, hp_val):set_text(string.format("Health: ~%d (raw 0x%X)", hp_val, h_nib))
            tree:add(f_field_uint, ap_val):set_text(string.format("Armour: ~%d (raw 0x%X)", ap_val, a_nib))
        end

        -- Оружие (6 бит) и спец. действие (8 бит)
        local weapon = br:read_bits(6)
        local spec_act = br:read_u8()
        if weapon then tree:add(f_field_uint, weapon):set_text(string.format("Weapon ID: %d", weapon)) end
        if spec_act then tree:add(f_field_uint, spec_act):set_text(string.format("Special Action: %d", spec_act)) end

        -- Сжатый вектор скорости
        local vx, vy, vz = read_compressed_vec()
        if vz then
            tree:add(f_field_str, string.format("%.3f, %.3f, %.3f", vx, vy, vz)):set_text(
                string.format("Velocity: X=%.3f, Y=%.3f, Z=%.3f", vx, vy, vz))
        end

        return string.format("Player=%d, Pos=(%.1f, %.1f, %.1f), HP=%d, Wep=%d",
            player_id, px, py, pz, hp_val, weapon or 0)
    end

    -- 2. ВХОДЯЩИЙ INCAR SYNC (ID 200)
    if pkt_id == 200 then
        local player_id = br:read_u16_le()
        local veh_id = br:read_u16_le()
        if not veh_id then return nil end

        tree:add(f_field_uint, player_id):set_text(string.format("Player ID: %d", player_id))
        tree:add(f_field_uint, veh_id):set_text(string.format("Vehicle ID: %d", veh_id))

        local lr = br:read_u16_le()
        local ud = br:read_u16_le()
        local keys = br:read_u16_le()
        if keys then tree:add(f_field_uint, keys):set_text(string.format("Keys: 0x%04X", keys)) end

        local quat_str = br:read_norm_quat()
        if quat_str then
            tree:add(f_field_str, quat_str):set_text("Rotation Quat: " .. quat_str)
        end

        local px = br:read_float_le()
        local py = br:read_float_le()
        local pz = br:read_float_le()
        if not pz then return string.format("Player=%d, Veh=%d", player_id, veh_id) end

        tree:add(f_field_float, px):set_text(string.format("Pos X: %.3f", px))
        tree:add(f_field_float, py):set_text(string.format("Pos Y: %.3f", py))
        tree:add(f_field_float, pz):set_text(string.format("Pos Z: %.3f", pz))

        local vx, vy, vz = read_compressed_vec()
        if vz then
            tree:add(f_field_str, string.format("%.3f, %.3f, %.3f", vx, vy, vz)):set_text(
                string.format("Velocity: X=%.3f, Y=%.3f, Z=%.3f", vx, vy, vz))
        end

        local car_hp = br:read_u16_le()
        if car_hp then
            tree:add(f_field_uint, car_hp):set_text(string.format("Car Health: %d", car_hp))
        end

        return string.format("Player=%d, Veh=%d, Pos=(%.1f, %.1f, %.1f), CarHP=%d",
            player_id, veh_id, px, py, pz, car_hp or 0)
    end

    -- 3. ВХОДЯЩИЙ BULLET SYNC (ID 206 — выстрелы других игроков)
    if pkt_id == 206 then
        local player_id = br:read_u16_le()
        local hit_type = br:read_u8()
        local hit_id = br:read_u16_le()
        local ox, oy, oz = br:read_float_le(), br:read_float_le(), br:read_float_le()
        local tx, ty, tz = br:read_float_le(), br:read_float_le(), br:read_float_le()
        local cx, cy, cz = br:read_float_le(), br:read_float_le(), br:read_float_le()
        local weapon = br:read_u8()
        if not cz then return nil end

        local hit_names = { [0] = "None", [1] = "Player", [2] = "Vehicle", [3] = "Object", [4] = "PlayerObject" }
        local hit_str = hit_names[hit_type] or tostring(hit_type)

        tree:add(f_field_uint, player_id):set_text(string.format("Shooter ID: %d", player_id))
        tree:add(f_field_uint, hit_type):set_text(string.format("Hit Type: %s (%d)", hit_str, hit_type))
        tree:add(f_field_uint, hit_id):set_text(string.format("Target ID: %d", hit_id))
        tree:add(f_field_str, string.format("%.2f, %.2f, %.2f", ox, oy, oz)):set_text(
            string.format("Origin: X=%.3f, Y=%.3f, Z=%.3f", ox, oy, oz))
        tree:add(f_field_str, string.format("%.2f, %.2f, %.2f", tx, ty, tz)):set_text(
            string.format("Target: X=%.3f, Y=%.3f, Z=%.3f", tx, ty, tz))
        tree:add(f_field_str, string.format("%.2f, %.2f, %.2f", cx, cy, cz)):set_text(
            string.format("Center Offset: X=%.3f, Y=%.3f, Z=%.3f", cx, cy, cz))
        if weapon then tree:add(f_field_uint, weapon):set_text(string.format("Weapon ID: %d", weapon)) end

        return string.format("Shooter=%d -> %s(%d), Wep=%d", player_id, hit_str, hit_id, weapon or 0)
    end

    -- 4. ВХОДЯЩИЙ UNOCCUPIED SYNC (ID 209 — пустые машины / толчки / физика авто)
    if pkt_id == 209 then
        local player_id = br:read_u16_le()
        local veh_id = br:read_u16_le()
        local seat_id = br:read_u8()
        local rx, ry, rz = br:read_float_le(), br:read_float_le(), br:read_float_le()
        local ux, uy, uz = br:read_float_le(), br:read_float_le(), br:read_float_le()
        local px, py, pz = br:read_float_le(), br:read_float_le(), br:read_float_le()
        local vx, vy, vz = br:read_float_le(), br:read_float_le(), br:read_float_le()
        local tx, ty, tz = br:read_float_le(), br:read_float_le(), br:read_float_le()
        local car_hp = br:read_float_le()
        if not pz then return nil end

        tree:add(f_field_uint, player_id):set_text(string.format("Syncer ID: %d", player_id))
        tree:add(f_field_uint, veh_id):set_text(string.format("Vehicle ID: %d", veh_id))
        tree:add(f_field_uint, seat_id):set_text(string.format("Seat ID: %d", seat_id))
        tree:add(f_field_float, px):set_text(string.format("Pos X: %.3f", px))
        tree:add(f_field_float, py):set_text(string.format("Pos Y: %.3f", py))
        tree:add(f_field_float, pz):set_text(string.format("Pos Z: %.3f", pz))
        if vz then
            tree:add(f_field_str, string.format("%.3f, %.3f, %.3f", vx, vy, vz)):set_text(
                string.format("Velocity: X=%.3f, Y=%.3f, Z=%.3f", vx, vy, vz))
        end
        if car_hp then tree:add(f_field_float, car_hp):set_text(string.format("Car Health: %.1f", car_hp)) end

        return string.format("Syncer=%d, Veh=%d, Pos=(%.1f, %.1f, %.1f), CarHP=%.0f",
            player_id, veh_id, px, py, pz, car_hp or 0)
    end

    -- 5. ВХОДЯЩИЙ TRAILER SYNC (ID 210 — прицепы дальнобойщиков / эвакуаторов)
    if pkt_id == 210 then
        local player_id = br:read_u16_le()
        local trailer_id = br:read_u16_le()
        local px, py, pz = br:read_float_le(), br:read_float_le(), br:read_float_le()
        local qw, qx, qy, qz = br:read_float_le(), br:read_float_le(), br:read_float_le(), br:read_float_le()
        local vx, vy, vz = br:read_float_le(), br:read_float_le(), br:read_float_le()
        local tx, ty, tz = br:read_float_le(), br:read_float_le(), br:read_float_le()
        if not pz then return nil end

        tree:add(f_field_uint, player_id):set_text(string.format("Driver ID: %d", player_id))
        tree:add(f_field_uint, trailer_id):set_text(string.format("Trailer ID: %d", trailer_id))
        tree:add(f_field_float, px):set_text(string.format("Pos X: %.3f", px))
        tree:add(f_field_float, py):set_text(string.format("Pos Y: %.3f", py))
        tree:add(f_field_float, pz):set_text(string.format("Pos Z: %.3f", pz))
        if qz then
            tree:add(f_field_str, string.format("w=%.3f, x=%.3f, y=%.3f, z=%.3f", qw, qx, qy, qz)):set_text(
                string.format("Rotation Quat: w=%.3f, x=%.3f, y=%.3f, z=%.3f", qw, qx, qy, qz))
        end
        if vz then
            tree:add(f_field_str, string.format("%.3f, %.3f, %.3f", vx, vy, vz)):set_text(
                string.format("Velocity: X=%.3f, Y=%.3f, Z=%.3f", vx, vy, vz))
        end

        return string.format("Driver=%d, Trailer=%d, Pos=(%.1f, %.1f, %.1f)",
            player_id, trailer_id, px, py, pz)
    end

    -- 6. ВХОДЯЩИЙ PASSENGER SYNC (ID 211 — пассажиры в машинах)
    if pkt_id == 211 then
        local player_id = br:read_u16_le()
        local veh_id = br:read_u16_le()
        local seat_flags = br:read_u8()
        local weapon = br:read_u8()
        local hp = br:read_u8()
        local ap = br:read_u8()
        local lr = br:read_u16_le()
        local ud = br:read_u16_le()
        local keys = br:read_u16_le()
        local px, py, pz = br:read_float_le(), br:read_float_le(), br:read_float_le()
        if not pz then return nil end

        local seat_id = bit.band(seat_flags, 0x3F)
        local driveby = bit.band(bit.rshift(seat_flags, 6), 1)

        tree:add(f_field_uint, player_id):set_text(string.format("Passenger ID: %d", player_id))
        tree:add(f_field_uint, veh_id):set_text(string.format("Vehicle ID: %d", veh_id))
        tree:add(f_field_uint, seat_id):set_text(string.format("Seat ID: %d (Drive-By: %d)", seat_id, driveby))
        tree:add(f_field_uint, weapon):set_text(string.format("Weapon ID: %d", weapon))
        tree:add(f_field_uint, hp):set_text(string.format("Health: %d", hp))
        tree:add(f_field_uint, ap):set_text(string.format("Armour: %d", ap))
        if keys then tree:add(f_field_uint, keys):set_text(string.format("Keys: 0x%04X", keys)) end
        tree:add(f_field_float, px):set_text(string.format("Pos X: %.3f", px))
        tree:add(f_field_float, py):set_text(string.format("Pos Y: %.3f", py))
        tree:add(f_field_float, pz):set_text(string.format("Pos Z: %.3f", pz))

        return string.format("Passenger=%d, Veh=%d, Seat=%d, HP=%d, Pos=(%.1f, %.1f, %.1f)",
            player_id, veh_id, seat_id, hp, px, py, pz)
    end


    return nil
end


local function decode_set_object_material(frame_tvb, bit_offset, frame_tree)
    local br = make_bit_reader(frame_tvb)
    br.bit_pos = bit_offset or 32

    local obj_id = br:read_u16_le()
    local mat_type = br:read_u8()
    local mat_idx = br:read_u8()
    if not mat_idx then return nil end

    local sub = frame_tree:add("Decoded Fields")
    sub:add(string.format("Object ID: %d (0x%04X)", obj_id, obj_id))
    sub:add(string.format("Material Type: %d (%s)", mat_type, mat_type == 1 and "Texture" or (mat_type == 2 and "Text" or "Unknown")))
    sub:add(string.format("Material Index: %d", mat_idx))

    if mat_type == 1 then
        local model_id = br:read_u16_le()
        local txd_len = br:read_u8()
        local txd_name = txd_len and br:read_string(txd_len) or ""
        local tex_len = br:read_u8()
        local tex_name = tex_len and br:read_string(tex_len) or ""
        local color = br:read_u32_le()

        if model_id then sub:add(string.format("Model ID: %d", model_id)) end
        sub:add(string.format("TXD Name: \"%s\"", txd_name))
        sub:add(string.format("Texture Name: \"%s\"", tex_name))
        if color then sub:add(string.format("Material Color: 0x%08X", color)) end

        return string.format("Obj=%d, Idx=%d, Tex=%s:%s", obj_id, mat_idx, txd_name, tex_name)

    elseif mat_type == 2 then
        local mat_size = br:read_u8()
        local font_len = br:read_u8()
        local font_name = font_len and br:read_string(font_len) or ""
        local font_size = br:read_u8()
        local bold = br:read_u8()
        local font_color = br:read_u32_le()
        local back_color = br:read_u32_le()
        local align = br:read_u8()
        local text = read_huffman_string(br, 2048)

        if mat_size then sub:add(string.format("Material Size: %d", mat_size)) end
        sub:add(string.format("Font Name: \"%s\"", font_name))
        if font_size then sub:add(string.format("Font Size: %d", font_size)) end
        if bold then sub:add(string.format("Bold: %d", bold)) end
        if font_color then sub:add(string.format("Font Color: 0x%08X", font_color)) end
        if back_color then sub:add(string.format("Back Color: 0x%08X", back_color)) end
        if align then sub:add(string.format("Alignment: %d", align)) end
        if text then sub:add(string.format("Text (Huffman): \"%s\"", text)) end

        return string.format("Obj=%d, Idx=%d, Text=\"%s\"", obj_id, mat_idx, text or "")
    end

    return string.format("Obj=%d, Type=%d, Idx=%d", obj_id, mat_type, mat_idx)
end


local function decode_init_game(frame_tvb, bit_offset, frame_tree)
    local br = make_bit_reader(frame_tvb)
    br.bit_pos = bit_offset

    local zone_names      = br:read_bit()
    local use_cj_walk     = br:read_bit()
    local allow_weapons   = br:read_bit()
    local limit_chat_rad  = br:read_bit()
    local chat_radius     = br:read_float_le()
    local stunt_bonus     = br:read_bit()
    local nametag_dist    = br:read_float_le()
    local enter_exit      = br:read_bit()
    local tire_popping    = br:read_bit()
    local classes_avail   = br:read_u32_le()
    local player_id       = br:read_u16_le()
    local show_nametags   = br:read_bit()
    local show_markers    = br:read_bit()
    local world_time      = br:read_u8()
    local weather         = br:read_u8()
    local gravity         = br:read_float_le()
    local lan_mode        = br:read_bit()
    local drop_money      = br:read_u32_le()
    local instagib        = br:read_bit()
    local onfoot_rate     = br:read_u32_le()
    local incar_rate      = br:read_u32_le()
    local weapon_rate     = br:read_u32_le()
    local multiplier      = br:read_u32_le()
    local lag_comp        = br:read_u32_le()
    local host_len        = br:read_u8()
    local hostname        = host_len and br:read_string(host_len) or ""

    if not player_id then return nil end

    local sub = frame_tree:add("Decoded Fields")
    sub:add(string.format("Your Player ID: %d (0x%04X)", player_id, player_id))
    if hostname ~= "" then sub:add(string.format("Server Hostname: \"%s\"", hostname)) end
    if world_time then sub:add(string.format("World Time: %02d:00", world_time)) end
    if weather then sub:add(string.format("Weather ID: %d", weather)) end
    if gravity then sub:add(string.format("Gravity: %.4f", gravity)) end
    if nametag_dist then sub:add(string.format("Nametag Distance: %.1f", nametag_dist)) end
    if classes_avail then sub:add(string.format("Classes Available: %d", classes_avail)) end
    if lag_comp then sub:add(string.format("Lag Compensation: %d", lag_comp)) end
    sub:add(string.format("Sync Rates (ms): OnFoot=%d, InCar=%d, Weapon=%d", onfoot_rate or 0, incar_rate or 0, weapon_rate or 0))
    sub:add(string.format("Flags: ZoneNames=%d, CJWalk=%d, Nametags=%d, Markers=%d, StuntBonus=%d",
        zone_names or 0, use_cj_walk or 0, show_nametags or 0, show_markers or 0, stunt_bonus or 0))

    return string.format("ID=%d, Host=\"%s\", Time=%02d:00, Weather=%d", player_id, hostname, world_time or 0, weather or 0)
end


local split_reassembly = {}      -- временный буфер при первом проходе
local reassembled_cache = {}     -- готовые склеенные пакеты по pinfo.number

function samp_proto.init()
    split_reassembly = {}
    reassembled_cache = {}
end

local function process_split_frame(fr, pinfo_number, visited)
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


local function decode_raknet_acks(tvb, parent_tree)
    local br = make_bit_reader(tvb)
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


-- ==========================================
-- Главный обработчик обоих направлений
-- ==========================================
function samp_proto.dissector(buffer, pinfo, tree)
    local len = buffer:len()
    if len < 2 then return end

    if len >= 4 and buffer(0, 4):string() == "SAMP" then
        pinfo.cols.protocol = "SA-MP Query"
        pinfo.cols.info = "Launcher Server Query"
        return
    end

       -- 1. ВХОДЯЩИЕ ПАКЕТЫ ОТ СЕРВЕРА (src_port == 7777)
    if pinfo.src_port == 7777 then
        pinfo.cols.protocol = "SA-MP In"

        local subtree = tree:add(samp_proto, buffer(), "SA-MP Incoming Packet")
        subtree:add(f_direction, "Server -> Client"):set_generated()

        local raw_first = buffer(0, 1):uint()
        if len <= 7 and (raw_first == 12 or raw_first == 24 or raw_first == 25 or raw_first == 26 or raw_first == 30 or raw_first == 31 or raw_first == 36) then
            local p_name = packet_names[raw_first] or "Handshake Packet"
            subtree:add(f_packet_id, buffer(0, 1))
            subtree:add(f_packet_name, p_name):set_generated()
            subtree:add(f_payload, buffer())
            pinfo.cols.info = string.format("Handshake: %s (ID %d) | Len: %d", p_name, raw_first, len)
            return
        end


        local frames = parse_all_raknet_frames(buffer)
        if #frames > 0 then
            local summary_parts = {}

            for idx, fr in ipairs(frames) do
                local full_tvb, is_ready = process_split_frame(fr, pinfo.number, pinfo.visited)

                if not is_ready then
                    local rel_name = reliability_names[fr.reliability] or tostring(fr.reliability)
                    local chunk_tree = subtree:add(samp_proto, fr.frame_tvb(), string.format("Frame #%d: Split Chunk [%d/%d]", idx, (fr.split_index or 0) + 1, fr.split_count or 0))
                    chunk_tree:add(f_reliability, rel_name):set_generated()
                    chunk_tree:add(f_payload, fr.frame_tvb())

                    table.insert(summary_parts, string.format("Split Chunk [%d/%d] (ID=%d)", (fr.split_index or 0) + 1, fr.split_count or 0, fr.split_id or 0))
                else
                    if fr.is_split then
                        fr.frame_tvb = full_tvb
                        fr.is_split = false
                        fr.pkt_id = full_tvb(0, 1):uint()
                        if fr.pkt_id == 20 and full_tvb:len() >= 2 then
                            fr.rpc_id = full_tvb(1, 1):uint()
                        end
                    end

                    local rel_name = reliability_names[fr.reliability] or tostring(fr.reliability)
                    local pkt_name = packet_names[fr.pkt_id] or ("ID " .. tostring(fr.pkt_id))
                    
                    local node_title = string.format("Frame #%d: %s", idx, pkt_name)
                    if fr.rpc_id then
                        local r_name = rpc_names[fr.rpc_id] or ("RPC #" .. tostring(fr.rpc_id))
                        node_title = string.format("Frame #%d: %s (%s)", idx, pkt_name, r_name)
                    end

                    local frame_tree = subtree:add(samp_proto, fr.frame_tvb(), node_title)
                    
                    --local frame_tree = subtree:add(samp_proto, fr.frame_tvb(), string.format("Frame #%d: %s", idx, pkt_name))

                    frame_tree:add(f_reliability, rel_name):set_generated()

                    if fr.rpc_id then
                        local r_name = rpc_names[fr.rpc_id] or ("RPC #" .. tostring(fr.rpc_id))
                        frame_tree:add(f_packet_id, fr.frame_tvb(0, 1))
                        frame_tree:add(f_packet_name, pkt_name):set_generated()
                        frame_tree:add(f_rpc_id, fr.frame_tvb(1, 1))
                        frame_tree:add(f_rpc_name, r_name):set_generated()

                        local details = nil
                        if fr.frame_tvb:len() >= 3 then
                            local rpc_br = make_bit_reader(fr.frame_tvb)
                            rpc_br.bit_pos = 16 -- 8 бит ID=20 + 8 бит rpc_id
                            local rpc_bit_len = rpc_br:read_compressed_u32() or 0
                            local start_bit = rpc_br.bit_pos
                            local total_bits = start_bit + rpc_bit_len

                            if fr.rpc_id == 84 then
                                details = decode_set_object_material(fr.frame_tvb, start_bit, frame_tree)
                            elseif fr.rpc_id == 139 then
                                details = decode_init_game(fr.frame_tvb, start_bit, frame_tree)
                            else
                                details = decode_by_schema(fr.frame_tvb, start_bit, total_bits, rpc_schemas[fr.rpc_id], frame_tree)
                            end
                        end

                        if details then
                            table.insert(summary_parts, string.format("RPC:%s(%s)", r_name, details))
                        else
                            table.insert(summary_parts, string.format("RPC:%s(#%d)", r_name, fr.rpc_id))
                        end
                    else
                        frame_tree:add(f_packet_id, fr.frame_tvb(0, 1))
                        frame_tree:add(f_packet_name, pkt_name):set_generated()

                        local sync_details = nil
                        if fr.pkt_id == 200 or fr.pkt_id == 206 or fr.pkt_id == 207 or fr.pkt_id == 209 or fr.pkt_id == 210 or fr.pkt_id == 211 then
                            sync_details = decode_incoming_sync(fr.frame_tvb, fr.pkt_id, frame_tree)
                        elseif packet_schemas_in[fr.pkt_id] then
                            sync_details = decode_by_schema(fr.frame_tvb, 8, fr.frame_tvb:len() * 8, packet_schemas_in[fr.pkt_id], frame_tree)
                        end

                        if sync_details then
                            table.insert(summary_parts, string.format("%s (%s)", pkt_name, sync_details))
                        else
                            table.insert(summary_parts, pkt_name)
                        end
                    end

                    -- ВАЖНО: эта строка должна быть строго ВНУТРИ блока else!
                    frame_tree:add(f_payload, fr.frame_tvb())
                end
            end

            pinfo.cols.info = table.concat(summary_parts, " | ")
        else
            local ack_str = decode_raknet_acks(buffer, subtree)
            if ack_str then
                pinfo.cols.info = string.format("RakNet Pure ACK [Msg: %s] | Len: %d", ack_str, len)
            else
                pinfo.cols.info = string.format("RakNet Control / Empty (0x%02X) | Len: %d", raw_first, len)
            end
            subtree:add(f_payload, buffer())
        end

        return
    end


    -- 2. ИСХОДЯЩИЕ ПАКЕТЫ К СЕРВЕРУ (Скремблер + разбор фрейма RakNet)
    pinfo.cols.protocol = "SA-MP Out"

    local dst_port = pinfo.dst_port
    local key = bit.band(bit.bxor(dst_port, 0xCCCC), 0xFF)

    local orig_checksum = buffer(0, 1):uint()
    local calc_sum = 0
    local hex_chars = {}
    local odd_flag = false

    for i = 1, len - 1 do
        local b = buffer(i, 1):uint()
        if odd_flag then
            b = bit.bxor(b, key)
        end
        odd_flag = not odd_flag

        local plain = decrypt_scramble_byte(b)
        calc_sum = bit.bxor(calc_sum, bit.band(plain, 0xAA))
        table.insert(hex_chars, string.format("%02x", plain))
    end

    local is_valid = (orig_checksum == calc_sum)
    local dec_tvb = ByteArray.new(table.concat(hex_chars)):tvb("Decrypted SA-MP Outgoing Packet")

    local subtree = tree:add(samp_proto, buffer(), "SA-MP Outgoing Packet (Decrypted)")
    subtree:add(f_direction, "Client -> Server"):set_generated()
    subtree:add(f_checksum, buffer(0, 1))
    subtree:add(f_calc_checksum, calc_sum):set_generated()
    subtree:add(f_session_key, key):set_generated()
    subtree:add(f_checksum_ok, is_valid):set_generated()

    local frames = parse_all_raknet_frames(dec_tvb)
    if #frames > 0 then
        local out_summary = {}

        for idx, fr in ipairs(frames) do
            local pkt_name = packet_names[fr.pkt_id] or ("Packet ID " .. tostring(fr.pkt_id))
            
            local node_title = string.format("Out Frame #%d: %s", idx, pkt_name)
            if fr.rpc_id then
                local r_name = rpc_names_out[fr.rpc_id] or rpc_names[fr.rpc_id] or ("RPC #" .. tostring(fr.rpc_id))
                node_title = string.format("Out Frame #%d: %s (%s)", idx, pkt_name, r_name)
            end

            local frame_tree = subtree:add(samp_proto, fr.frame_tvb(), node_title)
            
            --local frame_tree = subtree:add(samp_proto, fr.frame_tvb(), string.format("Out Frame #%d: %s", idx, pkt_name))
            frame_tree:add(f_packet_id, fr.frame_tvb(0, 1))
            frame_tree:add(f_packet_name, pkt_name):set_generated()

            if fr.rpc_id then
                local r_name = rpc_names_out[fr.rpc_id] or rpc_names[fr.rpc_id] or ("RPC #" .. tostring(fr.rpc_id))

                frame_tree:add(f_rpc_id, fr.frame_tvb(1, 1))
                frame_tree:add(f_rpc_name, r_name):set_generated()
                local details = nil
                if fr.frame_tvb:len() >= 3 then
                    local rpc_br = make_bit_reader(fr.frame_tvb)
                    rpc_br.bit_pos = 16
                    local rpc_bit_len = rpc_br:read_compressed_u32() or 0
                    local start_bit = rpc_br.bit_pos
                    if start_bit < (fr.frame_tvb:len() * 8) then
                        details = decode_by_schema(fr.frame_tvb, start_bit, start_bit + rpc_bit_len, rpc_schemas[fr.rpc_id], frame_tree)
                    end
                end
                table.insert(out_summary, string.format("Out RPC: %s%s", r_name, details and (" (" .. details .. ")") or ""))
            else
                local details = nil
                if packet_schemas_out[fr.pkt_id] then
                    details = decode_by_schema(fr.frame_tvb, 8, fr.frame_tvb:len() * 8, packet_schemas_out[fr.pkt_id], frame_tree)
                end
                table.insert(out_summary, string.format("Out %s%s", pkt_name, details and (" (" .. details .. ")") or ""))
            end

            frame_tree:add(f_payload, fr.frame_tvb())
        end

        pinfo.cols.info = string.format("[%s] %s", is_valid and "OK" or "FAIL", table.concat(out_summary, " | "))
    else
        local first_byte = dec_tvb(0, 1):uint()
        local ack_str = decode_raknet_acks(dec_tvb, subtree)
        if ack_str then
            pinfo.cols.info = string.format("[%s] Out Pure ACK [Msg: %s] | Len: %d",
                is_valid and "OK" or "FAIL", ack_str, dec_tvb:len())
        elseif first_byte == 0x00 and dec_tvb:len() == 1 then
            pinfo.cols.info = string.format("[%s] Out RakNet Keep-Alive (0x00)",
                is_valid and "OK" or "FAIL")
        else
            local p_name = packet_names[first_byte] or "Control / Ping"
            pinfo.cols.info = string.format("[%s] Out %s (0x%02X) | Len: %d",
                is_valid and "OK" or "FAIL", p_name, first_byte, dec_tvb:len())
        end
        subtree:add(f_payload, dec_tvb())
    end
end




local udp_port = DissectorTable.get("udp.port")
udp_port:add(7777, samp_proto)

-- =========================================================================
-- ЭКСПОРТ ВСЕХ РАСПАКОВАННЫХ И СКЛЕЕННЫХ ФРЕЙМОВ В ОТДЕЛЬНЫЙ PCAP
-- =========================================================================

-- Построитель минимального заголовка Ethernet + IPv4 + UDP для Dumper (WTAP_ENCAP_ETHERNET)
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

-- Оборачиваем сырой SA-MP фрейм в минимальный валидный заголовок RakNet (1 фрейм в пакете),
-- чтобы при открытии samp_unpacked.pcap наш же диссектор samp_proto его сразу прочитал!
local function wrap_single_raknet_frame(frame_bytes)
    -- Магический байт 0xFE означает "уже распакованный одиночный фрейм SA-MP"
    local out = ByteArray.new("FE")
    out:append(frame_bytes)
    return out
end



local export_dumper = nil
local export_active = false
local export_count = 0
local export_split_buf = {}

local function unpack_to_pcap_menu()
    if not gui_enabled() then return end

    local out_path = persconffile_path("samp_unpacked.pcap")
    export_dumper = Dumper.new(out_path, wtap_encaps.ETHERNET)
    if not export_dumper then
        report_failure("Не удалось создать файл: " .. out_path)
        return
    end

    export_active = true
    export_count = 0
    export_split_buf = {}

    -- Запускаем проход по всем пакетам текущего дампа
    retap_packets()

    export_dumper:flush()
    export_dumper:close()
    export_dumper = nil
    export_active = false
    export_split_buf = {}

    local win = TextWindow.new("SA-MP Unpack Complete")
    win:set(string.format(
        "Распаковка завершена успешно!\n\nСохранено отдельных фреймов: %d\nПуть к файлу:\n%s\n\nОткройте этот файл в Wireshark (File -> Open), чтобы увидеть каждый фрейм на отдельной строке.",
        export_count, out_path
    ))
end

-- Листенер перебирает все UDP-пакеты порта 7777 при вызове retap_packets()
local export_tap = Listener.new("udp", "udp.port == 7777")
function export_tap.packet(pinfo, tvb)
    if not export_active or not export_dumper then return end

    -- Извлекаем UDP payload из полного кадра
    local udp_len = tvb:len()
    -- Listener("udp") передаёт в tvb весь кадр с уровня Ethernet/IP, находим смещение UDP-данных:
    local src_port = pinfo.src_port
    local dst_port = pinfo.dst_port
    local src_ip = tostring(pinfo.src)
    local dst_ip = tostring(pinfo.dst)

    -- Находим начало UDP payload по длине (последние len байт кадра, если нет Ethernet padding)
    -- Надёжнее взять через Field extractor или по заголовкам IPv4:
    local ip_hdr_len = bit.band(tvb(14, 1):uint(), 0x0F) * 4
    local udp_offset = 14 + ip_hdr_len + 8
    if udp_offset >= tvb:len() then return end

    local payload_tvb = tvb(udp_offset):tvb("UDP Payload")
    if payload_tvb:len() <= 7 then return end

    local frames = parse_all_raknet_frames(payload_tvb)
    for _, fr in ipairs(frames) do
        local ready_bytes = nil

        if not fr.is_split then
            ready_bytes = fr.frame_tvb:bytes()
        else
            local key = string.format("%s:%d_%d", src_ip, src_port, fr.split_id)
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
            export_count = export_count + 1
        end
    end
end

register_menu("Unpack SA-MP Frames to PCAP", unpack_to_pcap_menu, MENU_TOOLS_UNSORTED)
