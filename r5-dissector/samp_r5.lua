-- SA-MP 0.3.7 Full Bidirectional Protocol Dissector (Incoming RakNet Frame Parser + Outgoing Scramble Decryptor)

-- good path handling
local plugins_dir = persconffile_path("plugins")
package.path = package.path .. ";" .. plugins_dir .. "/?.lua;" .. plugins_dir .. "/?/init.lua"

-- constants
package.loaded["samp_r5_modules.constants"] = nil
local constants = require("samp_r5_modules.constants")
local packet_names = constants.packet_names
local rpc_names = constants.rpc_names
local reliability_names = constants.reliability_names

-- schema_decoder
package.loaded["samp_r5_modules.schema_decoder"] = nil
local schema_decoder = require("samp_r5_modules.schema_decoder")
local decode_by_schema = schema_decoder.decode_by_schema

--
local samp_proto = Proto("samp_proto", "SA-MP 0.3.7 Protocol")
samp_proto.prefs.server_port = Pref.uint("Server UDP Port", 7777, "Server Port SA-MP (by default 7777)")
local current_registered_port = 7777

function samp_proto.prefs_changed()
    local udp_table = DissectorTable.get("udp.port")
    if current_registered_port ~= samp_proto.prefs.server_port then
        udp_table:remove(current_registered_port, samp_proto)
        current_registered_port = samp_proto.prefs.server_port
        udp_table:add(current_registered_port, samp_proto)
    end
end

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

-- bitstream
package.loaded["samp_r5_modules.bitstream"] = nil
local bitstream = require("samp_r5_modules.bitstream")
local make_bit_reader = bitstream.make_bit_reader
local cp1251_to_utf8  = bitstream.cp1251_to_utf8

-- huffman
package.loaded["samp_r5_modules.huffman"] = nil
local huffman = require("samp_r5_modules.huffman")
local read_huffman_string = huffman.read_huffman_string

-- raknet
package.loaded["samp_r5_modules.raknet"] = nil
local raknet = require("samp_r5_modules.raknet")
local parse_all_raknet_frames = raknet.parse_all_raknet_frames

-- crypto
package.loaded["samp_r5_modules.crypto"] = nil
local crypto = require("samp_r5_modules.crypto")
local decrypt_outgoing_packet = crypto.decrypt_outgoing_packet

--
local packet_schemas_out = constants.packet_schemas_out
local packet_schemas_in = constants.packet_schemas_in

local rpc_names_out = constants.rpc_names_out
local rpc_schemas = constants.rpc_schemas

-- decoders
package.loaded["samp_r5_modules.decoders"] = nil
local decoders = require("samp_r5_modules.decoders")
decoders.init({
    samp_proto          = samp_proto,
    make_bit_reader     = make_bit_reader,
    read_huffman_string = read_huffman_string,
    f_field_uint        = f_field_uint,
    f_field_int         = f_field_int,
    f_field_hex         = f_field_hex,
    f_field_float       = f_field_float,
    f_field_str         = f_field_str,
    f_field_bool        = f_field_bool
})
local decode_incoming_sync = decoders.decode_incoming_sync
local decode_set_object_material = decoders.decode_set_object_material
local decode_init_game = decoders.decode_init_game

function samp_proto.init()
    split_reassembly = {}
    reassembled_cache = {}
end

local process_split_frame = raknet.process_split_frame
local decode_raknet_acks = raknet.decode_raknet_acks

schema_decoder.init({
    samp_proto          = samp_proto,
    make_bit_reader     = make_bit_reader,
    read_huffman_string = read_huffman_string,
    f_field_uint        = f_field_uint,
    f_field_int         = f_field_int,
    f_field_hex         = f_field_hex,
    f_field_float       = f_field_float,
    f_field_str         = f_field_str
})

-- ==========================================
-- Main Handler for In/Out-Coming packets
-- ==========================================
function samp_proto.dissector(buffer, pinfo, tree)
    local len = buffer:len()
    if len < 2 then return end

    if len >= 4 and buffer(0, 4):string() == "SAMP" then
        pinfo.cols.protocol = "SA-MP Query"
        pinfo.cols.info = "Launcher Server Query"
        return
    end

    -- 1. Incoming pakets from Server (src_port == 7777)
    if pinfo.src_port == samp_proto.prefs.server_port then

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
                            rpc_br.bit_pos = 16 -- 8 bit ID=20 + 8 bit rpc_id
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
                        if fr.pkt_id == 200 or fr.pkt_id == 206 or fr.pkt_id == 207 or fr.pkt_id == 208 or fr.pkt_id == 209 or fr.pkt_id == 210 or fr.pkt_id == 211 then
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

    -- 2. Outgoing packets to Server (Scrambler + parse RakNet frames)
    pinfo.cols.protocol = "SA-MP Out"
    local dec_tvb, is_valid, orig_checksum, calc_sum, key

    -- If packet from samp_unpacked.pcap (begins with 0xFE), it already decrypted!
    if buffer(0, 1):uint() == 0xFE then
        dec_tvb = buffer
        is_valid = true
        orig_checksum = 0
        calc_sum = 0
        key = 0
    else
        dec_tvb, is_valid, orig_checksum, calc_sum, key = decrypt_outgoing_packet(buffer, pinfo.dst_port)
        if not dec_tvb then return end
    end

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
udp_port:add(current_registered_port, samp_proto)

-- samp_export
package.loaded["samp_r5_modules.samp_export"] = nil
local samp_export = require("samp_r5_modules.samp_export")
samp_export.init(
    samp_proto, 
    function()
        return current_registered_port
    end, 
    parse_all_raknet_frames
)