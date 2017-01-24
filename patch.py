#
# Script for patching Novatouch TKL firmware. Will switch the caps
# lock key to ctrl and change places of backspace and \.
#
import md5
import argparse

# These variables will be put into the modified firmware
# Modify as you like

# USB HID identifier strings
usb_hid_strings = [
    'CM Storm',
    'Coolermaster Novatouch TKL',
    '0',
    'HID Interface',
    'Keyboard',
    'Multi-media',
]

# This table is the first lookup table where key id is translated to
# scancode. These scancodes are used as index to the second table.
scancode_table1 = [0x03, 0x3C, 0x00, 0x2E, 0x20, 0x12, 0x00, 0x00,
                   0x02, 0x86, 0x00, 0x00, 0x1F, 0x11, 0x00, 0x00,
                   0x01, 0x3A, 0x00, 0x2C, 0x1E, 0x10, 0x00, 0x00,
                   0x04, 0x00, 0x00, 0x2F, 0x21, 0x13, 0x00, 0x00,
                   0x70, 0x6E, 0x74, 0x73, 0x71, 0x72, 0x00, 0x00,
                   0x05, 0x00, 0x00, 0x30, 0x22, 0x14, 0x00, 0x00,
                   0x07, 0x3D, 0x00, 0x32, 0x24, 0x16, 0x00, 0x00,
                   0x06, 0x00, 0x00, 0x31, 0x23, 0x15, 0x00, 0x00,
                   0x0A, 0x00, 0x77, 0x35, 0x27, 0x19, 0x00, 0x00,
                   0x09, 0x00, 0x76, 0x34, 0x26, 0x18, 0x00, 0x00,
                   0x08, 0x00, 0x75, 0x33, 0x25, 0x17, 0x00, 0x00,
                   0x0B, 0x3E, 0x78, 0x36, 0x28, 0x1A, 0x00, 0x00,
                   0x4B, 0x4F, 0x7C, 0x53, 0x00, 0x4C, 0x55, 0x50,
                   0x0C, 0x89, 0x79, 0x37, 0x29, 0x1B, 0x53, 0x54,
                   0x0F, 0x40, 0x7B, 0x59, 0x00, 0x1D, 0x7E, 0x7D,
                   0x0D, 0x8B, 0x7A, 0x39, 0x2B, 0x1C, 0x56, 0x51]

# Before sending the scancode to host over usb the scancode from the
# first table is used as index in a second table. Could as well remap
# keys on this level but to really simulate the actual key it's better
# to do it in scancode_table1. Only change this if you want to add new
# scancodes.
scancode_table2 = [0x00, 0x35, 0x1E, 0x1F, 0x20, 0x21, 0x22, 0x23,
                   0x24, 0x25, 0x26, 0x27, 0x2D, 0x2E, 0x00, 0x2A,
                   0x2B, 0x14, 0x1A, 0x08, 0x15, 0x17, 0x1C, 0x18,
                   0x0C, 0x12, 0x13, 0x2F, 0x30, 0x31, 0x39, 0x04,
                   0x16, 0x07, 0x09, 0x0A, 0x0B, 0x0D, 0x0E, 0x0F,
                   0x33, 0x34, 0x00, 0x28, 0x02, 0x00, 0x1D, 0x1B,
                   0x06, 0x19, 0x05, 0x11, 0x10, 0x36, 0x37, 0x38,
                   0x00, 0x20, 0x01, 0x00, 0x04, 0x2C, 0x40, 0x00,
                   0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                   0x00, 0x00, 0x00, 0x49, 0x4C, 0x00, 0x00, 0x50,
                   0x4A, 0x4D, 0x00, 0x52, 0x51, 0x4B, 0x4E, 0x00,
                   0x00, 0x4F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x29, 0x00,
                   0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F, 0x40, 0x41,
                   0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x00,
                   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0x00,
                   0x00, 0x80, 0x00, 0x00]

# See README for full id => key mapping
key_id_ctrl = 17
key_id_caps = 20
key_id_backspace = 112
key_id_backslash = 117

# Hex offsets to scancode tables in the raw original fw. These tables
# will be overwritten by our modified tables above
string_table_offset = 0x22c8
string_table_max = 0x235e
scancode_table1_offset = 0x258a
scancode_table2_offset = 0x23e6

orig_fw_md5 = '67d2c8f71f273e30a0c69aa36e8bf609'

def write_scancode_table(table, f, offset):
    '''Write scancode table at specific offset in a file'''
    f.seek(offset)
    f.write(''.join(map(chr, table)))

def write_usb_string(f, s):
    '''Write string to file as utf16le. Each string is prepended with
       length and type'''
    encoded = s.encode('utf-16le')
    if f.tell() + len(encoded) + 2 > string_table_max:
        print 'USB string table is too big, will overwrite important stuffs in fw'
        return
    f.write(chr(len(encoded)+2))
    f.write('\x03') # Not sure what this is, encoding type?
    f.write(encoded)

def original_fw_valid(path):
    with open(path, 'r') as orig:
        m = md5.new()
        m.update(orig.read())
        return m.hexdigest() == orig_fw_md5

def write_handle_fn_key_handler_hooks():
    '''Add C hooks for doing stuff when fn + key(s) is pressed'''

    # bytecode for asm 'calla 0xa780; nop' (on_fn_key_down)
    dest.seek(0x83a)
    dest.write('b01380a70343'.decode('hex'))

    # calla #0xa8f0 (on_fn_key_up, INCREDIHACK: offest depends on size
    # of on_fn_key_down since this is linked after)
    dest.seek(0xa98)
    dest.write('b01302a8'.decode('hex'))

if __name__ == '__main__':
    # Remap caps to ctrl
    scancode_table1[key_id_caps] = scancode_table1[key_id_ctrl]

    # Switch down backspace to \ and \ to backspace
    scancode_table1[key_id_backspace], scancode_table1[key_id_backslash] = \
        scancode_table1[key_id_backslash], scancode_table1[key_id_backspace]

    parser = argparse.ArgumentParser(
        description='Patch utility for Novatouch TKL firmware')
    parser.add_argument('original', help='Original firmware')
    parser.add_argument('output', help='Destination file')
    args = parser.parse_args()

    if not original_fw_valid(args.original):
        print 'Wrong checksum of original firmware. Check that ' \
            'you are using the correct file'
        exit(-1)

    with open(args.original, 'r') as orig:
        with open(args.output, 'w') as dest:
            # Copy the full original to destination file
            dest.write(orig.read())

            # Write scancode tables
            write_scancode_table(scancode_table1, dest, scancode_table1_offset)
            write_scancode_table(scancode_table2, dest, scancode_table2_offset)

            # Write USB identifier strings
            dest.seek(string_table_offset)
            for text in usb_hid_strings:
                write_usb_string(dest, text)

            write_handle_fn_key_handler_hooks()
