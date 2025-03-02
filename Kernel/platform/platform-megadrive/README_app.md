Applications are built using the makefile rules in Target/rules.68000
The linker is set to Library/link/ld68k which is a small shell script that wraps the linker
'''
"$CROSS_COMPILE"ld $ARGS -o "$TARGET.bin"
$FUZIX_ROOT/Standalone/elf2aout -s "$STACK" -o "$TARGET" "$TARGET.bin"
'''
The program is linked with Library/elf2flt.ld as a linker script

Applications are linked with headers:
CRT0 = Library/libs/crt0_68000.o
CRT0NS = Library/libs/crt0nostdio_68000.o
