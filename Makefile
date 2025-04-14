ASM=nasm
A_OPTS=-f elf64
ASSEMBLE=$(ASM) $(A_OPTS)
LINK=ld

all: up

debug: A_OPTS+=-g -F dwarf -dDEBUG
debug: up

.PHONY: test
test:


up: src.o parsedir.o
	$(LINK) $^ -o $@
	@rm -f *.o


src.o: src.asm
	$(ASSEMBLE) $< -o $@

parsedir.o: parsedir.asm
	$(ASSEMBLE) $< -o $@
