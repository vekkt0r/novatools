all:

QUIET=@

build/dummy_fw.hex:
	@echo "Creating dummy hex file with supposed BSL password..."
	$(QUIET)dd if=/dev/zero of=build/dummy_fw.bin bs=32 count=2047 status=none
	$(QUIET)echo -n 'ffffffffffff9483ffff9aa0ffffffffffffffffffffffffffff3a98ffffa69c' | xxd -r -p >> build/dummy_fw.bin
	$(QUIET)msp430-objcopy -I binary -O ihex build/dummy_fw.bin $@

build/orig_fw.bin: build/dummy_fw.hex
	@echo "Reading Novatouch firmware to $@..."
	$(QUIET)python -m msp430.bsl5.hid --upload=0x8000-0xffff -f bin \
	-x 0x2504 --password $< -o $@

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
build/main.elf: build/main.o build/enter_bsl.o
	@echo "Create main.elf..."
	$(QUIET)msp430-gcc -O0 -mmcu=msp430f5510 \
		-Wl,--section-start=.text=0x8000 \
		-Wl,--section-start=.vectors=0xffe0 \
		-Wl,--entry=0x9ca6 \
		-nostdlib \
		$^ -o $@

.PHONY: flash
flash: build/main.elf
	$(QUIET)python -m msp430.bsl5.hid -e -r $<

clean:
	rm build/*
