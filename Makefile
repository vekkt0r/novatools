REQUIREMENTS = dd echo msp430-objcopy msp430-gcc mspdebug

include Makefile.common

build/orig_fw.hex:
	@echo "Reading Novatouch firmware to $@..."
	$(QUIET)mspdebug rf2500 "hexout 0x8000 0xffff $@"

build/orig_fw.bin: build/orig_fw.hex
	@echo "Converting ihex fw to binary blob..."
	$(QUIET)mkdir -p build
	$(QUIET)msp430-objcopy -I ihex -O binary $< $@

.PHONY: flash
flash: build/main.elf
	$(QUIET)mspdebug rf2500 "prog $<"
