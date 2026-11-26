
local M = {}

-- Перевод байта Windows-1251 в UTF-8 для отображения русского текста в Wireshark
function M.cp1251_to_utf8(b)
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

-- ==========================================
-- Побитовый читатель (аналог RakNet::BitStream с ReadCompressed)
-- ==========================================
function M.make_bit_reader(tvb)
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



    function reader:read_string(len_bytes)
        if not len_bytes or len_bytes <= 0 then return "" end
        local chars = {}
        for _ = 1, len_bytes do
            local ch = self:read_bits(8)
            if not ch then break end
            table.insert(chars, M.cp1251_to_utf8(ch))
        end
        return table.concat(chars)
    end


    return reader
end

return M