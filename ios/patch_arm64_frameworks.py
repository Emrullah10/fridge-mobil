#!/usr/bin/env python3
import glob
import os
import struct
import subprocess
import tempfile

def patch_macho_bytes(data):
    if len(data) < 32:
        return False
    magic = struct.unpack('<I', data[:4])[0]
    # 0xfeedfacf is MH_MAGIC_64 (little-endian 64-bit Mach-O)
    if magic != 0xfeedfacf:
        return False
    magic, cputype, cpusubtype, filetype, ncmds, sizeofcmds, flags, reserved = struct.unpack('<IIIIIIII', data[:32])
    offset = 32
    patched = False
    for _ in range(ncmds):
        if offset + 8 > len(data):
            break
        cmd, cmdsize = struct.unpack('<II', data[offset:offset+8])
        # LC_BUILD_VERSION (0x32)
        if cmd == 0x32:
            if offset + 24 <= len(data):
                cmd, cmdsize, platform, minos, sdk, ntools = struct.unpack('<IIIIII', data[offset:offset+24])
                # If platform is PLATFORM_IOS (1 or 2), change to PLATFORM_IOSSIMULATOR (7)
                if platform in (1, 2):
                    struct.pack_into('<I', data, offset+8, 7)
                    patched = True
        offset += cmdsize
    return patched

def patch_archive_in_place(archive_bytes):
    # Archive starts with '!<arch>\n' (8 bytes)
    if not archive_bytes.startswith(b'!<arch>\n'):
        # Standalone object file
        data = bytearray(archive_bytes)
        if patch_macho_bytes(data):
            return bytes(data), 1
        return bytes(data), 0

    data = bytearray(archive_bytes)
    offset = 8
    count = 0
    while offset < len(data):
        # Each member has a 60-byte header
        header = data[offset:offset+60]
        if len(header) < 60:
            break
        name = header[:16].decode('latin1', errors='ignore').strip()
        try:
            size = int(header[48:58].strip())
        except ValueError:
            break

        name_len = 0
        if name.startswith('#1/'):
            try:
                name_len = int(name[3:])
            except ValueError:
                name_len = 0

        content_start = offset + 60 + name_len
        content_size = size - name_len
        if content_start + content_size <= len(data):
            member_content = data[content_start:content_start+content_size]
            if patch_macho_bytes(member_content):
                data[content_start:content_start+content_size] = member_content
                count += 1

        # ar members are 2-byte aligned
        offset += 60 + size + (size % 2)

    return bytes(data), count

def patch_framework_binary(binary_path):
    if not os.path.exists(binary_path):
        return

    # Check if universal binary containing arm64
    res = subprocess.run(['lipo', '-info', binary_path], capture_output=True, text=True)
    if 'arm64' not in res.stdout:
        return

    with tempfile.TemporaryDirectory() as tmpdir:
        arm64_a = os.path.join(tmpdir, 'arm64.a')
        # Extract arm64 slice
        subprocess.run(['lipo', '-thin', 'arm64', binary_path, '-output', arm64_a], check=True)

        with open(arm64_a, 'rb') as f:
            content = f.read()

        patched_bytes, count = patch_archive_in_place(content)
        if count == 0:
            return

        print(f'Patching {count} object(s) in {os.path.basename(binary_path)}')
        with open(arm64_a, 'wb') as f:
            f.write(patched_bytes)

        if content.startswith(b'!<arch>\n'):
            subprocess.run(['ranlib', arm64_a], check=True)

        # Check if original was universal (has x86_64 as well)
        if 'x86_64' in res.stdout:
            x86_64_a = os.path.join(tmpdir, 'x86_64.a')
            subprocess.run(['lipo', '-thin', 'x86_64', binary_path, '-output', x86_64_a], check=True)
            subprocess.run(['lipo', '-create', arm64_a, x86_64_a, '-output', binary_path], check=True)
        else:
            subprocess.run(['cp', arm64_a, binary_path], check=True)

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    pods_dir = os.path.join(script_dir, 'Pods')
    for root, dirs, files in os.walk(pods_dir):
        for d in dirs:
            if d.endswith('.framework'):
                framework_name = d[:-len('.framework')]
                binary_path = os.path.join(root, d, framework_name)
                if os.path.exists(binary_path) and not os.path.islink(binary_path):
                    patch_framework_binary(binary_path)

if __name__ == '__main__':
    main()
