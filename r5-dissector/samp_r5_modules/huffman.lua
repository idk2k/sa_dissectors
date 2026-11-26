
local M = {}




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

local huffman_root = build_huffman_tree()

-- Чтение строки, сжатой StringCompressor::EncodeString (включая перекодировку CP1251 -> UTF-8)
-- Исправленное чтение Huffman-строки для SA-MP R5
function M.read_huffman_string(br, max_chars)
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


return M