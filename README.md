# sa_dissectors

Custom Wireshark Lua dissector suite for analyzing SA network traffic, including support for **0.3.7-R5** (`r5-dissector`).

## Features

- **RakNet Packet & Frame Parsing**: Parses bundled RakNet frames (`parse_all_raknet_frames`), handles split-packet reassembly (`process_split_frame`), and decodes `ACK` acknowledgments (`decode_raknet_acks`).
- **Outgoing Packet Decryption**: Decrypts scrambled outgoing SA-MP client packets (`decrypt_outgoing_packet`, `decrypt_scramble_byte`).
- **BitStream & Compressed Types**: Full bitstream reader supporting standard integers/floats, compressed integers (`read_compressed_u16`, `read_compressed_u32`), compressed vectors (`read_compressed_vec`), and normalized quaternions (`read_norm_quat`).
- **Huffman & CP1251 String Decoding**: Decodes RakNet Huffman-encoded strings (`read_huffman_string`, `build_huffman_tree`) and converts Windows-1251 (`CP1251`) Cyrillic text to UTF-8 (`cp1251_to_utf8`).
- **RPC & Sync Packet Decoding**: Schema-driven RPC decoding (`decode_by_schema`) alongside dedicated parsers for `InitGame` (`decode_init_game`), `SetObjectMaterial` (`decode_set_object_material`), and incoming synchronization packets (`decode_incoming_sync`).
- **PCAP Unpacker Tool**: Built-in Wireshark menu action (`unpack_to_pcap_menu`) that decrypts and unpacks bundled RakNet frames into individual UDP packets saved as a new `.pcap` file.

## Repository Structure

- **`r5-dissector/`** — Main Wireshark Lua dissector for SA-MP 0.3.7-R5 traffic.
- **`misc/`** — Supplementary scripts, schemas, or helper utilities.

## Installation

1. Open Wireshark and go to **Help > About Wireshark > Folders** (or **Wireshark > About Wireshark > Folders** on macOS).
2. Double-click the path next to **Personal Lua Plugins** to open your local plugins folder.
3. Copy the `.lua` files from `r5-dissector/` (and any required modules) into that directory.
4. Restart Wireshark or press **Ctrl + Shift + L** (**Cmd + Shift + L** on macOS) to reload Lua plugins.

## Usage

### Inspecting Traffic
1. Open a `.pcap` / `.pcapng` capture or start a live capture on your SA-MP server port (default UDP `7777`).
2. Expand the dissected RakNet / SA-MP layer in the **Packet Details** pane to view decoded headers, RPC parameters, sync data, and UTF-8 strings.

### Unpacking Frames to PCAP
1. With a capture open, navigate to **Tools** in the top menu bar and select the unpack-to-PCAP option.
2. Each decrypted and unbundled RakNet frame is wrapped as an individual UDP packet (`wrap_single_raknet_frame`) and exported to a clean `.pcap` file for easier frame-by-frame filtering.

### Preferences
1. Navigate to **Edit > Preferences > Protocols** (or **Wireshark > Settings > Protocols** on macOS).
2. Select the dissector protocol entry to configure UDP ports or decoding options.