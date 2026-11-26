
local M = {}

local deps = {}

function M.init(dependencies)
    deps = dependencies
end
-- ==========================================
-- Побитовый декодер входящей синхронизации (ID 207 OnFoot / ID 200 InCar)
-- ==========================================
function M.decode_incoming_sync(tvb, pkt_id, parent_tree)
    if tvb:len() < 3 then return nil end

    local sub_tvb = tvb(1, tvb:len() - 1):tvb("Incoming Sync Data")
    local br = deps.make_bit_reader(sub_tvb)
    local tree = parent_tree:add(deps.samp_proto, sub_tvb(), "Decoded Incoming Sync")

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
        tree:add(deps.f_field_uint, player_id):set_text(string.format("Player ID: %d", player_id))

        -- Опциональные клавиши (1 бит на каждое поле)
        if br:read_bit() == 1 then
            local lr = br:read_u16_le()
            if lr then tree:add(deps.f_field_uint, lr):set_text(string.format("Left/Right Keys: %d", lr)) end
        end
        if br:read_bit() == 1 then
            local ud = br:read_u16_le()
            if ud then tree:add(deps.f_field_uint, ud):set_text(string.format("Up/Down Keys: %d", ud)) end
        end
        local keys = br:read_u16_le()
        if keys then tree:add(deps.f_field_uint, keys):set_text(string.format("Keys: 0x%04X", keys)) end

        -- Координаты позиции (всегда 3 float)
        local px = br:read_float_le()
        local py = br:read_float_le()
        local pz = br:read_float_le()
        if not pz then return string.format("Player=%d", player_id) end

        tree:add(deps.f_field_float, px):set_text(string.format("Pos X: %.3f", px))
        tree:add(deps.f_field_float, py):set_text(string.format("Pos Y: %.3f", py))
        tree:add(deps.f_field_float, pz):set_text(string.format("Pos Z: %.3f", pz))

        -- Сжатый кватернион поворота
        local quat_str = br:read_norm_quat()
        if quat_str then
            tree:add(deps.f_field_str, quat_str):set_text("Rotation Quat: " .. quat_str)
        end

        -- Упакованные HP и Armour (1 байт: старшие 4 бита * 7 = HP, младшие 4 бита * 7 = AP)
        local hp_ap = br:read_u8()
        local hp_val = 0
        if hp_ap then
            local h_nib = bit.rshift(hp_ap, 4)
            local a_nib = bit.band(hp_ap, 0x0F)
            hp_val = (h_nib == 0x0F) and 100 or (h_nib * 7)
            local ap_val = (a_nib == 0x0F) and 100 or (a_nib * 7)
            tree:add(deps.f_field_uint, hp_val):set_text(string.format("Health: ~%d (raw 0x%X)", hp_val, h_nib))
            tree:add(deps.f_field_uint, ap_val):set_text(string.format("Armour: ~%d (raw 0x%X)", ap_val, a_nib))
        end

        -- Оружие (6 бит) и спец. действие (8 бит)
        local weapon = br:read_bits(6)
        local spec_act = br:read_u8()
        if weapon then tree:add(deps.f_field_uint, weapon):set_text(string.format("Weapon ID: %d", weapon)) end
        if spec_act then tree:add(deps.f_field_uint, spec_act):set_text(string.format("Special Action: %d", spec_act)) end

        -- Сжатый вектор скорости
        local vx, vy, vz = read_compressed_vec()
        if vz then
            tree:add(deps.f_field_str, string.format("%.3f, %.3f, %.3f", vx, vy, vz)):set_text(
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

        tree:add(deps.f_field_uint, player_id):set_text(string.format("Player ID: %d", player_id))
        tree:add(deps.f_field_uint, veh_id):set_text(string.format("Vehicle ID: %d", veh_id))

        local lr = br:read_u16_le()
        local ud = br:read_u16_le()
        local keys = br:read_u16_le()
        if keys then tree:add(deps.f_field_uint, keys):set_text(string.format("Keys: 0x%04X", keys)) end

        local quat_str = br:read_norm_quat()
        if quat_str then
            tree:add(deps.f_field_str, quat_str):set_text("Rotation Quat: " .. quat_str)
        end

        local px = br:read_float_le()
        local py = br:read_float_le()
        local pz = br:read_float_le()
        if not pz then return string.format("Player=%d, Veh=%d", player_id, veh_id) end

        tree:add(deps.f_field_float, px):set_text(string.format("Pos X: %.3f", px))
        tree:add(deps.f_field_float, py):set_text(string.format("Pos Y: %.3f", py))
        tree:add(deps.f_field_float, pz):set_text(string.format("Pos Z: %.3f", pz))

        local vx, vy, vz = read_compressed_vec()
        if vz then
            tree:add(deps.f_field_str, string.format("%.3f, %.3f, %.3f", vx, vy, vz)):set_text(
                string.format("Velocity: X=%.3f, Y=%.3f, Z=%.3f", vx, vy, vz))
        end

        local car_hp = br:read_u16_le()
        if car_hp then
            tree:add(deps.f_field_uint, car_hp):set_text(string.format("Car Health: %d", car_hp))
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

        tree:add(deps.f_field_uint, player_id):set_text(string.format("Shooter ID: %d", player_id))
        tree:add(deps.f_field_uint, hit_type):set_text(string.format("Hit Type: %s (%d)", hit_str, hit_type))
        tree:add(deps.f_field_uint, hit_id):set_text(string.format("Target ID: %d", hit_id))
        tree:add(deps.f_field_str, string.format("%.2f, %.2f, %.2f", ox, oy, oz)):set_text(
            string.format("Origin: X=%.3f, Y=%.3f, Z=%.3f", ox, oy, oz))
        tree:add(deps.f_field_str, string.format("%.2f, %.2f, %.2f", tx, ty, tz)):set_text(
            string.format("Target: X=%.3f, Y=%.3f, Z=%.3f", tx, ty, tz))
        tree:add(deps.f_field_str, string.format("%.2f, %.2f, %.2f", cx, cy, cz)):set_text(
            string.format("Center Offset: X=%.3f, Y=%.3f, Z=%.3f", cx, cy, cz))
        if weapon then tree:add(deps.f_field_uint, weapon):set_text(string.format("Weapon ID: %d", weapon)) end

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

        tree:add(deps.f_field_uint, player_id):set_text(string.format("Syncer ID: %d", player_id))
        tree:add(deps.f_field_uint, veh_id):set_text(string.format("Vehicle ID: %d", veh_id))
        tree:add(deps.f_field_uint, seat_id):set_text(string.format("Seat ID: %d", seat_id))
        tree:add(deps.f_field_float, px):set_text(string.format("Pos X: %.3f", px))
        tree:add(deps.f_field_float, py):set_text(string.format("Pos Y: %.3f", py))
        tree:add(deps.f_field_float, pz):set_text(string.format("Pos Z: %.3f", pz))
        if vz then
            tree:add(deps.f_field_str, string.format("%.3f, %.3f, %.3f", vx, vy, vz)):set_text(
                string.format("Velocity: X=%.3f, Y=%.3f, Z=%.3f", vx, vy, vz))
        end
        if car_hp then tree:add(deps.f_field_float, car_hp):set_text(string.format("Car Health: %.1f", car_hp)) end

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

        tree:add(deps.f_field_uint, player_id):set_text(string.format("Driver ID: %d", player_id))
        tree:add(deps.f_field_uint, trailer_id):set_text(string.format("Trailer ID: %d", trailer_id))
        tree:add(deps.f_field_float, px):set_text(string.format("Pos X: %.3f", px))
        tree:add(deps.f_field_float, py):set_text(string.format("Pos Y: %.3f", py))
        tree:add(deps.f_field_float, pz):set_text(string.format("Pos Z: %.3f", pz))
        if qz then
            tree:add(deps.f_field_str, string.format("w=%.3f, x=%.3f, y=%.3f, z=%.3f", qw, qx, qy, qz)):set_text(
                string.format("Rotation Quat: w=%.3f, x=%.3f, y=%.3f, z=%.3f", qw, qx, qy, qz))
        end
        if vz then
            tree:add(deps.f_field_str, string.format("%.3f, %.3f, %.3f", vx, vy, vz)):set_text(
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

        tree:add(deps.f_field_uint, player_id):set_text(string.format("Passenger ID: %d", player_id))
        tree:add(deps.f_field_uint, veh_id):set_text(string.format("Vehicle ID: %d", veh_id))
        tree:add(deps.f_field_uint, seat_id):set_text(string.format("Seat ID: %d (Drive-By: %d)", seat_id, driveby))
        tree:add(deps.f_field_uint, weapon):set_text(string.format("Weapon ID: %d", weapon))
        tree:add(deps.f_field_uint, hp):set_text(string.format("Health: %d", hp))
        tree:add(deps.f_field_uint, ap):set_text(string.format("Armour: %d", ap))
        if keys then tree:add(deps.f_field_uint, keys):set_text(string.format("Keys: 0x%04X", keys)) end
        tree:add(deps.f_field_float, px):set_text(string.format("Pos X: %.3f", px))
        tree:add(deps.f_field_float, py):set_text(string.format("Pos Y: %.3f", py))
        tree:add(deps.f_field_float, pz):set_text(string.format("Pos Z: %.3f", pz))

        return string.format("Passenger=%d, Veh=%d, Seat=%d, HP=%d, Pos=(%.1f, %.1f, %.1f)",
            player_id, veh_id, seat_id, hp, px, py, pz)
    end

    -- 7. ВХОДЯЩИЙ MARKERS SYNC (ID 208 — маркеры игроков на радаре)
    if pkt_id == 208 then
        local count = br:read_u32_le()
        if not count or count > 1004 then return nil end

        tree:add(deps.f_field_uint, count):set_text(string.format("Players Count: %d", count))

        local active_count = 0
        for i = 1, count do
            local player_id = br:read_u16_le()
            local is_active = br:read_bit()
            if player_id == nil or is_active == nil then break end

            if is_active == 1 then
                local px = br:read_i16_le()
                local py = br:read_i16_le()
                local pz = br:read_i16_le()
                if not pz then break end
                active_count = active_count + 1
                tree:add(deps.f_field_str, string.format("ID=%d (%d, %d, %d)", player_id, px, py, pz)):set_text(
                    string.format("Marker #%d: Player ID=%d | Pos=(%d, %d, %d)", i, player_id, px, py, pz))
            else
                tree:add(deps.f_field_uint, player_id):set_text(
                    string.format("Marker #%d: Player ID=%d (Hidden / Inactive)", i, player_id))
            end
        end

        return string.format("Markers: %d total (%d active)", count, active_count)
    end



    return nil
end

function M.decode_set_object_material(frame_tvb, bit_offset, frame_tree)
    local br = deps.make_bit_reader(frame_tvb)
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
        local text = deps.read_huffman_string(br, 2048)

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

function M.decode_init_game(frame_tvb, bit_offset, frame_tree)
    local br = deps.make_bit_reader(frame_tvb)
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


return M