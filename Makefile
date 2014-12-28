all:

QUIET=@
orig_fw.hex:
	@echo "Reading Novatouch firmware to $@..."
	$(QUIET)mspdebug rf2500 "hexout 0x8000 0xffff $@"

orig_fw.bin: orig_fw.hex
	@echo "Converting ihex fw to binary blob..."
	$(QUIET)msp430-objcopy -I ihex -O binary $< $@

section_isr.bin: orig_fw.bin
	@echo "Create isr vectors binary..."
	$(QUIET)dd if=$< of=$@ bs=1 skip=0x7fe0 count=0x20

section_data.bin: orig_fw.bin
	@echo "Create data section binary..."
	$(QUIET)dd if=$< of=$@ bs=1 count=0x2780

section_data_patch.bin: section_data.bin
	@echo "Patching firmware..."
	$(QUIET)python patch.py section_data.bin section_data_patch.bin

# IDA friendly elf file
main.o: section_data_patch.bin section_isr.bin
	$(QUIET)msp430-objcopy -I binary -O elf32-msp430 -B msp430:430X \
	--rename-section .data=.text,contents,code,alloc,load,readonly \
	--change-section-address .data=0x8000 \
	--add-section .vectors=section_isr.bin \
	--set-section-flags .vectors=contents,alloc,load,readonly,code \
	--change-section-address .vectors=0xff80 \
	--set-start 0x8000 section_data_patch.bin $@

# The main.o is an relocatable elf which we convert to an actual elf
# for IDA to like it
main.elf: main.o
	$(QUIET)msp430-gcc -O0 -mmcu=msp430f5510 \
	-Wl,--section-start=.text=0x8000 \
	-Wl,--entry=0x9ca6 \
	-nostdlib \
	$< -o $@

clean:
	rm *.o *.bin main.elf
