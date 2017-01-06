REQUIREMENTS = dd echo msp430-objcopy msp430-gcc python

include Makefile.common

# Create dummy fw hex ending with the same ISR vectors as the original
# firmware. These vectors are used as password to the BSL. Password
# needs to be specified to read out existing firmware.
build/dummy_fw.hex:
	@echo "Creating dummy hex file with supposed BSL password..."
	$(QUIET)mkdir -p build
	$(QUIET)dd if=/dev/zero of=build/dummy_fw.bin bs=32 count=2047 status=none
	$(QUIET)echo -n 'ffffffffffff9483ffff9aa0ffffffffffffffffffffffffffff3a98ffffa69c' | xxd -r -p >> build/dummy_fw.bin
	$(QUIET)msp430-objcopy -I binary -O ihex build/dummy_fw.bin $@

# This step is a hit-or-miss, if the password is wrong the device will
# erase itself as a security measure. If this happens you will be
# stuck in BSL mode without firmware. Then you need to find the
# original firwmare to recover the keyboard.
build/orig_fw.bin: build/dummy_fw.hex
	@echo "Reading Novatouch firmware to $@..."
	$(QUIET)python -m msp430.bsl5.hid --upload=0x8000-0xffff -f bin \
	-x 0x2504 --password $< -o $@

.PHONY: flash
flash: build/main.elf
	$(QUIET)python -m msp430.bsl5.hid -e -r $<
