all:

QUIET=@

orig_fw.hex:
	@echo "Reading Novatouch firmware to $@..."
	$(QUIET)mspdebug rf2500 "hexout 0x8000 0xffff $@"

build/orig_fw.bin: orig_fw.hex
	@echo "Converting ihex fw to binary blob..."
	$(QUIET)mkdir -p build
	$(QUIET)msp430-objcopy -I ihex -O binary $< $@

build/section_isr.bin: build/orig_fw.bin
	@echo "Create isr vectors binary..."
	$(QUIET)dd if=$< of=$@ bs=1 skip=32736 count=32 status=none

build/section_data.bin: build/orig_fw.bin
	@echo "Create data section binary..."
	$(QUIET)dd if=$< of=$@ bs=1 count=10112 status=none

build/section_data_patch.bin: build/section_data.bin patch.py
	@echo "Patching data section..."
	$(QUIET)python patch.py $< $@

# IDA friendly elf file
build/main.o: build/section_data_patch.bin build/section_isr.bin
	@echo "Create main.o..."
	$(QUIET)msp430-objcopy -I binary -O elf32-msp430 -B msp430:430X \
		--rename-section .data=.text,contents,code,alloc,load,readonly \
		--change-section-address .data=0x8000 \
		--add-section .vectors=build/section_isr.bin \
		--set-section-flags .vectors=contents,alloc,load,readonly,code \
		--change-section-address .vectors=0xffe0 \
		--set-start 0x8000 build/section_data_patch.bin $@

build/enter_bsl.o: shellcode/enter_bsl.c
	@echo "Compiling shellcode..."
	$(QUIET)msp430-gcc -Os -mmcu=msp430f5510 -c $< -o $@

# The main.o is an relocatable elf which we convert to an actual elf
# for IDA to like it. Also link in our own objects
main.elf: build/main.o build/enter_bsl.o
	@echo "Create main.elf..."
	$(QUIET)msp430-gcc -O0 -mmcu=msp430f5510 \
		-Wl,--section-start=.text=0x8000 \
		-Wl,--section-start=.vectors=0xffe0 \
		-Wl,--entry=0x9ca6 \
		-nostdlib \
		$^ -o $@

.PHONY: flash
flash: main.elf
	$(QUIET)mspdebug rf2500 "prog $<"

clean:
	rm *.o *.bin main.elf
