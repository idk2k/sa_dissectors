import socket
import struct
import time
import hashlib
import secrets

ENC_TABLE  = [
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
]

MEM_100 = bytes.fromhex(
    "89 50 4E 47 0D 0A 1A 0A 00 00 00 0D 49 48 44 52 00 00 01 00 00 00 00 80 "
    "08 06 00 00 00 E4 B5 B7 0A 00 00 00 09 70 48 59 73 00 00 0B 13 00 00 0B "
    "13 01 00 9A 9C 18 00 00 00 04 67 41 4D 41 00 00 B1 8E 7C FB 51 93 00 00 "
    "00 20 63 48 52 4D 00 00 7A 25 00 00 80 83 00 00 F9 FF 00 00 80 E9 00 00 "
    "75 30 00 00"
)

MEM_20_4D3AA0 = bytes.fromhex(
    "FF 25 34 39 4D 00 90 90 90 90 56 57 50 8B 44 24 14 8D 0C 80"
)

class BitWriter:
    def __init__(self):
        self.bits = []

    def align_to_byte(self):
        while len(self.bits) % 8 != 0:
            self.write_bit(0)

    def write_bit(self, b: int):
        self.bits.append(b & 1)

    def write_bits(self, val: int, count: int):
        for i in range(count - 1, -1, -1):
            self.write_bit((val >> i) & 1)

    def write_u8(self, val: int):
        self.write_bits(val & 0xFF, 8)

    def write_u16_le(self, val: int):
        self.write_u8(val & 0xFF)
        self.write_u8((val >> 8) & 0xFF)

    def write_bytes(self, data: bytes):
        for b in data:
            self.write_u8(b)
    def write_compressed_u16(self, val: int):
        b0 = val & 0xFF
        b1 = (val >> 8) & 0xFF

        if b1 == 0:
            self.write_bit(1)
        else:
            self.write_bit(0)
            self.write_u8(b0)
            self.write_u8(b1)
            return

        if (b0 & 0xF0) == 0:
            self.write_bit(1)
            self.write_bits(b0 & 0x0F, 4)
        else:
            self.write_bit(0)
            self.write_u8(b0)

    def write_compressed_u32(self, val: int):
        b0 = val & 0xFF
        b1 = (val >> 8) & 0xFF
        b2 = (val >> 16) & 0xFF
        b3 = (val >> 24) & 0xFF

        if b3 == 0:
            self.write_bit(1)
        else:
            self.write_bit(0)
            self.write_u8(b0)
            self.write_u8(b1)
            self.write_u8(b2)
            self.write_u8(b3)
            return

        if b2 == 0:
            self.write_bit(1)
        else:
            self.write_bit(0)
            self.write_u8(b0)
            self.write_u8(b1)
            self.write_u8(b2)
            return

        if b1 == 0:
            self.write_bit(1)
        else:
            self.write_bit(0)
            self.write_u8(b0)
            self.write_u8(b1)
            return

        if (b0 & 0xF0) == 0:
            self.write_bit(1)
            self.write_bits(b0 & 0x0F, 4)
        else:
            self.write_bit(0)
            self.write_u8(b0)

    def get_bytes(self) -> bytes:
        while len(self.bits) % 8 != 0:
            self.bits.append(0)
        out = bytearray()
        for i in range(0, len(self.bits), 8):
            byte_val = 0
            for b in self.bits[i : i + 8]:
                byte_val = (byte_val << 1) | b
            out.append(byte_val)
        return bytes(out)

def generate_samp_r5_auth_key(challenge_str: str) -> str:
    sha1_digest = hashlib.sha1(challenge_str.encode("ascii")).digest()
    words = struct.unpack(">5I", sha1_digest)
    buf = bytearray(struct.pack("<5I", *words))

    for block_idx, xkey in enumerate([0x2F, 0x45, 0x6F, 0xDB]):
        for i in range(block_idx * 5, (block_idx + 1) * 5):
            val = buf[i]
            for j in range(100):
                val ^= MEM_100[j] ^ xkey
            buf[i] = val

    w27 = struct.unpack("<5I", MEM_20_4D3AA0)
    mask_20 = struct.pack("<5I", w27[0], w27[1], w27[2], w27[3], w27[4])
    for i in range(20):
        buf[i] ^= mask_20[i]

    return buf.hex().upper()

def scramble_outgoing(payload: bytes, dst_port: int) -> bytes:
    if len(ENC_TABLE) != 256:
        raise ValueError("Fill ENC_TABLE!")

    key = (dst_port ^ 0xCCCC) & 0xFF
    checksum = 0
    out = bytearray(len(payload) + 1)
    odd_flag = False

    for i, plain in enumerate(payload):
        checksum ^= (plain & 0xAA)
        enc = ENC_TABLE[plain]
        if odd_flag:
            enc ^= key
        odd_flag = not odd_flag
        out[i + 1] = enc

    out[0] = checksum
    return bytes(out)

def build_frame(data: bytes, msg_num: int, ordered: bool = False, order_idx: int = 0) -> bytes:
    bw = BitWriter()
    bw.write_bit(0)                         # has_acks = 0
    bw.write_u16_le(msg_num)                # messageNumber (16 bit LE)
    if ordered:
        bw.write_bits(3, 3)                 # ReliableOrdered (011)
        bw.write_u16_le(order_idx)          # orderingIndex (16 bit LE)
        bw.write_bits(0, 5)                 # orderingChannel (5 bit)
        bw.write_bit(0)                     # is_split = 0
        bw.write_compressed_u16(len(data) * 8)
    else:
        bw.write_bits(4, 3)                 # Reliable (100)
        bw.write_bit(0)                     # is_split = 0
        bw.write_bit(0)                     # bit alignment (0x43 0x80)
        bw.write_compressed_u16(len(data) * 8)
    bw.align_to_byte()
    bw.write_bytes(data)
    return bw.get_bytes()

def build_ack_packet(recv_msg_num: int) -> bytes:
    bw = BitWriter()
    bw.write_bit(1)                         # has_acks = 1
    bw.write_compressed_u16(1)              # 1 диапазон
    bw.write_bit(1)                         # single_id = 1
    bw.write_u16_le(recv_msg_num)
    return bw.get_bytes()

def generate_samp_r5_gpci(seed_str: str = None, multiplier: int = 1001) -> bytes:
    """43-GPCI (bit sorting + multiply by a3 in Little-Endian)."""
    if seed_str is None:
        seed_str = secrets.token_hex(16)

    while True:
        digest = bytearray(hashlib.sha1(seed_str.encode("ascii")).digest())

        # 1. sorting 2-bit bairs (sub_1005FFA0)
        for i in range(20):
            v4 = digest[i]
            v5 = v4 & 3
            v6 = (v4 >> 2) & 3
            v7 = (v4 >> 4) & 3
            v8 = v4 >> 6

            v9 = (v5 | (4 * v6)) if v5 <= v6 else (v6 | (4 * v5))
            v10 = (v7 | (4 * v8)) if v7 <= v8 else (v8 | (4 * v7))
            digest[i] = v9 | (16 * v10)

        # 2. Translate 20 byte to 160-bit number (Little-Endian, like in DWORD v8[0..4])
        big_num = int.from_bytes(digest, byteorder="little")

        # 3. Multiply by factor of revision (sub_100598C0) and transform to HEX
        result_hex = f"{big_num * multiplier:X}"

        if len(result_hex) == 43:
            return result_hex.encode("ascii")

        seed_str = secrets.token_hex(16)

def build_client_join_rpc(nickname: str, challenge: int, rpc_id: int = 25) -> bytes:
    nick_bytes = nickname.encode("cp1251")
    gpci = generate_samp_r5_gpci()
    ver_str = b"0.3.7-R5"

    body = bytearray()
    body += struct.pack("<i", 4057)                       # Version: 4057
    body += struct.pack("<B", 1)                          # Mod: 1
    body += struct.pack("<B", len(nick_bytes)) + nick_bytes
    body += struct.pack("<I", challenge)                  # Challenge Response
    body += struct.pack("<B", len(gpci)) + gpci           # GPCI (43)
    body += struct.pack("<B", len(ver_str)) + ver_str     # Client Version (8): "0.3.7-R5"
    body += struct.pack("<I", challenge)                  # Neccessary 2-й challenge for R5

    bit_len = len(body) * 8

    bw = BitWriter()
    bw.write_u8(0x14)                                     # ID_RPC (20)
    bw.write_u8(rpc_id)                                   # RPC ID (25)
    bw.write_compressed_u32(bit_len)                      # Compressed length in bits (cf 00 5b...)
    bw.write_bytes(body)                                  # Без align_to_byte()!
    return bw.get_bytes()

def run_interactive_bot():
    host = input("Server IP: ").strip() or "127.0.0.1"
    port = int(input("Server PORT: ").strip() or "7777")
    nickname = input("Bot Nickname [TestBot_R5]: ").strip() or "TestBot_R5"

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(3.0)
    addr = (host, port)
    msg_num = 0
    order_idx = 0

    def send_raw(raw_bytes: bytes, label: str):
        pkt = scramble_outgoing(raw_bytes, port)
        sock.sendto(pkt, addr)
        print(f"[->] Sent ({label}) [plain={raw_bytes.hex(' ')}] -> [enc={pkt.hex(' ')}]")

    # Step 1
    input("\n[Шаг 1] Press Enter, for starting handshake...")
    send_raw(b"\x18\x69\x69", "ID_OPEN_CONNECTION_REQUEST")

    for _ in range(4):
        resp, _ = sock.recvfrom(2048)
        print(f"[<-] Server response: {resp.hex(' ')}")

        if resp.startswith(b"\x19"):  # ID_OPEN_CONNECTION_REPLY (25)
            print("[+] Handshake finished (received 0x19)!")
            break

        if resp.startswith(b"\x1a") and len(resp) >= 3:
            c1, c2 = resp[1], resp[2]
            masked_cookie = bytes([c1 ^ 0x69, c2 ^ 0x69])
            print(f"[*] Received cookie: {resp[1:3].hex(' ')} -> с маской 0x6969: {masked_cookie.hex(' ')}")
            send_raw(b"\x18" + masked_cookie, "ID_OPEN_CONNECTION_REQUEST + Masked Cookie")
    else:
        print("[-] Cant get ID_OPEN_CONNECTION_REPLY (0x19).")
        return

    # Step 2
    send_raw(build_frame(b"\x0B", msg_num, ordered=False), "ID_CONNECTION_REQUEST")
    msg_num += 1

    # Step 3
    data, _ = sock.recvfrom(2048)
    print(f"[<-] Packet from Server (AuthKey): {data.hex(' ')}")
    send_raw(build_ack_packet(0), "Pure ACK (Msg 0)")

    if b"\x0c" in data:
        idx = data.index(b"\x0c")
        key_len = data[idx + 1]
        raw_challenge = data[idx + 2 : idx + 2 + key_len]
        challenge_str = raw_challenge.rstrip(b"\x00").decode("ascii")
        print(f"[*] Received ID_AUTH_KEY challenge (len={key_len}): '{challenge_str}'")

        auth_resp = generate_samp_r5_auth_key(challenge_str)
        print(f"[*] Responce generated R5: {auth_resp}")

        auth_pkt = b"\x0c" + bytes([len(auth_resp)]) + auth_resp.encode("ascii")
        send_raw(build_frame(auth_pkt, msg_num, ordered=False), "ID_AUTH_KEY Response")
        msg_num += 1

    server_challenge = 0
    for _ in range(3):
        data, _ = sock.recvfrom(2048)
        print(f"[<-] Packet from Server: {data.hex(' ')}")
        if b"\x22" in data:
            idx = data.index(b"\x22")
            if idx + 13 <= len(data):
                _, _, player_id, raw_chal = struct.unpack("<IHHI", data[idx + 1 : idx + 13])
                server_challenge = raw_chal ^ 0xFD9
                print(f"[*] Accepted! PlayerID={player_id}, Challenge=0x{server_challenge:08X}")
                send_raw(build_ack_packet(1), "Pure ACK (Msg 1)")
                break

    inc_pkt = b"\x1E" + socket.inet_aton(host) + struct.pack("<H", port)
    send_raw(build_frame(inc_pkt, msg_num, ordered=False), "ID_NEW_INCOMING_CONNECTION")
    msg_num += 1

    join_rpc = build_client_join_rpc(nickname, server_challenge, rpc_id=25)
    send_raw(build_frame(join_rpc, msg_num, ordered=False), "RPC_ClientJoin")
    msg_num += 1

    order_idx += 1

    print("\n[*] Entering of reading server responses... (Ctrl+C for exit)...")
    while True:
        try:
            data, _ = sock.recvfrom(2048)
            print(f"[<-] {len(data)} байт: {data.hex(' ')}")

            # Normal packet (first bit has_acks == 0), retrieve msg_num and send ACK
            if len(data) >= 3 and (data[0] & 0x80) == 0:
                b0, b1, b2 = data[0], data[1], data[2]
                srv_msg_num = ((b0 & 0x7F) << 1) | (b1 >> 7) | (((b1 & 0x7F) << 1 | (b2 >> 7)) << 8)
                send_raw(build_ack_packet(srv_msg_num), f"ACK (Srv Msg {srv_msg_num})")

            # ID_INTERNAL_PING (0x06 + 4 bytes of time), respond with ID_CONNECTED_PONG (0x09)
            if b"\x06" in data:
                idx = data.index(b"\x06")
                if idx + 5 <= len(data):
                    ping_time = data[idx + 1 : idx + 5]
                    pong_time = struct.pack("<I", int(time.time() * 1000) & 0xFFFFFFFF)
                    pong_pkt = b"\x09" + ping_time + pong_time
                    send_raw(build_frame(pong_pkt, msg_num, ordered=False), "ID_CONNECTED_PONG")
                    msg_num += 1
        except socket.timeout:
            print("[.] Waiting for packets...")

if __name__ == "__main__":
    run_interactive_bot()