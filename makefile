PROG=main
TARGET=objects/$(PROG).o
ASM=$(PROG).asm

OPERS=opers
TARGET_OPERS=objects/$(OPERS).o
ASM_OPERS=$(OPERS).asm

NASMF=-f elf32 -g -F stabs
LINKERF=-m elf_i386
all: $(TARGET) $(TARGET_OPERS)
	ld $(TARGET) $(TARGET_OPERS) $(LINKERF) -o $(PROG)

$(TARGET): $(ASM)
	nasm $(NASMF) $< -o $@

$(TARGET_OPERS): $(ASM_OPERS)
	nasm $(NASMF) $< -o $@