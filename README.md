# sha1asm
sha1 in assembler

compile with `nasm -f elf64 sha1.asm -o sha1.o && ld sha1.o -o sha1`

run with `sha1 "Message"`
