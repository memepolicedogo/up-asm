#!/bin/sh
if ! command -v nasm 2>&1 >/dev/null
then
	echo "nasm is required to build"
	exit 1
fi
if ! command -v ld 2>&1 >/dev/null
then
	echo "ld is required to build"
	exit 1
fi
opts="-f elf64"
if [[ -n $1 && $1 == "debug" ]];
then
	opts="-f elf64 -g -F dwarf"
	echo "Building with options \"$opts\""
fi

# Build parsedir object
nasm $opts parsedir.asm || exit 1
# Build src object
nasm $opts src.asm -o up.o || exit 1
# Link objects
ld -o up up.o parsedir.o || exit 1
# Clean up objects
rm parsedir.o up.o 2> /dev/null
echo "Build successful"
