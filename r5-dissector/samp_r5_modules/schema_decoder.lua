



local M = {}

local deps = {}

function M.init(dependencies)
    deps = dependencies
    local required = {
        "samp_proto", "make_bit_reader", "read_huffman_string",
        "f_field_uint", "f_field_int", "f_field_hex", "f_field_float", "f_field_str"
    }
    for _, key in ipairs(required) do
        if deps[key] == nil then
            error("schema_decoder.init: missing dependency '" .. key .. "'")
        end
    end
end

function M.decode_by_schema(tvb, start_bit, total_bits, schema, parent_tree)
    if not schema or (tvb:len() * 8) <= start_bit then return nil end

    local br = deps.make_bit_reader(tvb)
    br.bit_pos = start_bit
    if total_bits and total_bits > 0 then
        br.total_bits = math.min(br.total_bits, total_bits)
    end

    local byte_off = math.floor(start_bit / 8)
    local sub_tvb = tvb(byte_off, tvb:len() - byte_off):tvb("Fields")
    local fields_tree = parent_tree:add(deps.samp_proto, sub_tvb(), "Decoded Fields")
    local summary = {}


    for _, item in ipairs(schema) do
        local _, name = next(item)
        local _, ftype = next(item, 1)
        local val = nil
        local str_val = nil

        if ftype == "u8" then
            val = br:read_u8()
            if val then
                fields_tree:add(deps.f_field_uint, val):set_text(string.format("%s: %d (0x%02X)", name, val, val))
                str_val = tostring(val)
            end
        elseif ftype == "u16" then
            val = br:read_u16_le()
            if val then
                fields_tree:add(deps.f_field_uint, val):set_text(string.format("%s: %d (0x%04X)", name, val, val))
                str_val = tostring(val)
            end
        elseif ftype == "i16" then
            val = br:read_i16_le()
            if val then
                fields_tree:add(deps.f_field_int, val):set_text(string.format("%s: %d", name, val))
                str_val = tostring(val)
            end
        elseif ftype == "u32" then
            val = br:read_u32_le()
            if val then
                fields_tree:add(deps.f_field_uint, val):set_text(string.format("%s: %d", name, val))
                str_val = tostring(val)
            end
        elseif ftype == "i32" then
            val = br:read_i32_le()
            if val then
                fields_tree:add(deps.f_field_int, val):set_text(string.format("%s: %d", name, val))
                str_val = tostring(val)
            end
        elseif ftype == "hex32" then
            val = br:read_u32_le()
            if val then
                fields_tree:add(deps.f_field_hex, val):set_text(string.format("%s: 0x%08X", name, val))
                str_val = string.format("0x%08X", val)
            end
        elseif ftype == "float" then
            val = br:read_float_le()
            if val then
                fields_tree:add(deps.f_field_float, val):set_text(string.format("%s: %.3f", name, val))
                str_val = string.format("%.2f", val)
            end
        elseif ftype == "wep_key" then
            val = br:read_u8()
            if val then
                local add_key = bit.rshift(val, 6)
                local wep_id  = bit.band(val, 0x3F)
                fields_tree:add(deps.f_field_uint, wep_id):set_text(
                    string.format("%s: Weapon=%d, AddKey=%d (raw 0x%02X)", name, wep_id, add_key, val))
                str_val = string.format("Wep:%d/Key:%d", wep_id, add_key)
            end
        elseif ftype == "aim_zoom" then
            val = br:read_u8()
            if val then
                local wep_state = bit.rshift(val, 6)
                local cam_zoom  = bit.band(val, 0x3F)
                fields_tree:add(deps.f_field_uint, cam_zoom):set_text(
                    string.format("%s: Zoom=%d, WepState=%d (raw 0x%02X)", name, cam_zoom, wep_state, val))
                str_val = string.format("Zoom:%d/State:%d", cam_zoom, wep_state)
            end
        elseif ftype == "seat_db" then
            val = br:read_u8()
            if val then
                local drive_by = bit.rshift(val, 6)
                local seat_id  = bit.band(val, 0x3F)
                fields_tree:add(deps.f_field_uint, seat_id):set_text(
                    string.format("%s: Seat=%d, DriveBy=%d (raw 0x%02X)", name, seat_id, drive_by, val))
                str_val = string.format("Seat:%d/DB:%d", seat_id, drive_by)
            end
        elseif ftype == "str8" then
            local slen = br:read_u8()
            if slen then
                val = br:read_string(slen)
                fields_tree:add(deps.f_field_str, val):set_text(string.format('%s (%d): "%s"', name, slen, val))
                str_val = string.format('"%s"', val)
            end
        elseif ftype == "str16" then
            local slen = br:read_u16_le()
            if slen then
                val = br:read_string(slen)
                fields_tree:add(deps.f_field_str, val):set_text(string.format('%s (%d): "%s"', name, slen, val))
                str_val = string.format('"%s"', val)
            end
        elseif ftype == "str32" then
            local slen = br:read_u32_le()
            if slen and slen < 4096 then
                val = br:read_string(slen)
                fields_tree:add(deps.f_field_str, val):set_text(string.format('%s (%d): "%s"', name, slen, val))
                str_val = string.format('"%s"', val)
            end
        elseif ftype == "huff" then
            val = deps.read_huffman_string(br, 4096)
            if val then
                if #val > 100 then
                    local huff_node = fields_tree:add(deps.f_field_str, val)
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
                    fields_tree:add(deps.f_field_str, val):set_text(string.format('%s (Huffman): "%s"', name, val))
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


return M