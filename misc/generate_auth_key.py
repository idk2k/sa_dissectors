import hashlib
import struct

mem_100 = bytes.fromhex(
    "89 50 4E 47 0D 0A 1A 0A 00 00 00 0D 49 48 44 52 00 00 01 00 00 00 00 80 "
    "08 06 00 00 00 E4 B5 B7 0A 00 00 00 09 70 48 59 73 00 00 0B 13 00 00 0B "
    "13 01 00 9A 9C 18 00 00 00 04 67 41 4D 41 00 00 B1 8E 7C FB 51 93 00 00 "
    "00 20 63 48 52 4D 00 00 7A 25 00 00 80 83 00 00 F9 FF 00 00 80 E9 00 00 "
    "75 30 00 00"
)

mem_20_4d3aa0 = bytes.fromhex(
    "FF 25 34 39 4D 00 90 90 90 90 56 57 50 8B 44 24 14 8D 0C 80"
)

def generate_samp_r5_auth_key(challenge_str: str) -> str:
    sha1_digest = hashlib.sha1(challenge_str.encode("ascii")).digest()
    words = struct.unpack(">5I", sha1_digest)
    buf = bytearray(struct.pack("<5I", *words))

    xor_keys = [0x2F, 0x45, 0x6F, 0xDB]
    for block_idx, xkey in enumerate(xor_keys):
        for i in range(block_idx * 5, (block_idx + 1) * 5):
            val = buf[i]
            for j in range(100):
                val ^= mem_100[j] ^ xkey
            buf[i] = val

    w27 = struct.unpack("<5I", mem_20_4d3aa0)
    mask_20 = struct.pack("<5I", w27[0], w27[1], w27[2], w27[3], w27[4])
    for i in range(20):
        buf[i] ^= mask_20[i]

    return buf.hex().upper()

print(generate_samp_r5_auth_key("403B5FAD1D4C14D0"))
