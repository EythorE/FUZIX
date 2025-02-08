#include "../control_ports.def"

.equ vdp_cmd_vram_write, 0x40000000
.equ vdp_cmd_vsram_write, 0x40000010    | Vertical Scroll RAM address
.equ vram_addr_plane_a, 0xC000

#==============================================================
# Variables (MEMORY MAP)
#==============================================================
# We need to store values in RAM
# There are a few ways to create a memory map,
# but the cleanest, simplest, and easiest to maintain method
# uses the assembler's "RS" keywords. RSSET begins a new table of
# offsets starting from any other offset (here we're starting at
# 0x00FF0000, the start of RAM), and allows us to add named entries
# of any size for the "variables". We can then read/write these
# variables using the offsets' labels.
#==============================================================
    .section .data
.globl cursor_x,cursor_y,scrolling,vscroll_amount
cursor_x:
    .byte 0
cursor_y:
    .byte 0
scrolling:
    .byte 0                              | Are we scrolling? 1 if yes!
    .even
vscroll_amount:
    .word 0                              | Keep track of how much we scrolled

#==============================================================
# Code Section
#==============================================================
    .text
    .globl printString, printChar, printLong, printWord, printByte, clearLine

#==============================================================
# Print zero-terminated string at %a0
# Trashes %d0, %a0
#==============================================================
printString:
    move.l 4(%sp), %a0                   | Load the string address from the stack
_printString:
    move.b (%a0)+, %d0
    cmp.b #0, %d0
    beq _zt
    jsr printChar
    bra _printString
_zt:
    rts

#==============================================================
# Print character and handle screen scroll
# Note: jsr printLong/Word/byte trashes %d1
#==============================================================
printLong:
    swap     %d0            | Swap upper and lower words
    jsr printWord
    swap %d0
printWord:
    rol.w   #8, %d0
    jsr     printByte       | Output it in hex format.
    rol.w   #8, %d0
printByte:
    move.b  %d0, %d1        | Save A for LSD.
    lsr.b   #4 ,%d0         | MSD to LSD position.
    jsr     .LprintHex        | Output hex digit.
    move.b  %d1, %d0        | Restore A.
.LprintHex:
    and.b   #0x0F, %d0      | Mask LSD for hex print.
    or.b    #0x30, %d0      | Add "0".
    cmp.b   #0x39, %d0      | Digit?
    ble     printChar        | Yes, output it.
    add.b   #0x07, %d0      | Add offset for letter.
printChar:
    movem.l %d0/%d1/%d2/%d4/%d5, -(%sp)
    and.l #0xFF, %d0
    cmp.b #0x0A, %d0                      | Carriage return
    beq _newline
    cmp.b #127, %d0                       | Is it higher than the highest printable character?
    bgt _skipPrintChar
    sub.b #32, %d0
    bmi _skipPrintChar                    | Less than space
# printCharNoCheck:
    move.l #0x40000003, %d5
    move.l #0, %d4
    move.b (cursor_y), %d4
    rol.l #8, %d4
    rol.l #8, %d4
    rol.l #7, %d4
    add.l %d4, %d5

    move.b (cursor_x), %d4
    rol.l #8, %d4
    rol.l #8, %d4
    rol.l #1, %d4
    add.l %d4, %d5

    move.l %d5, (VDP_CONTROL)
    move.w %d0, (VDP_DATA)

    addq.b #1, (cursor_x)
    move.b (cursor_x), %d0
    cmp.b #39, %d0
    ble _skipPrintChar
_newline:                                | Newline (28 lines on screen at a time)
    addq.b #1, (cursor_y)
    and.b #0x1F, (cursor_y)              | Modulo 32 (rows in VRAM)

    jsr clearLine

    cmp.b #1, (scrolling)                | Are we scrolling the page after each newline?
    beq _scrollPage

    cmp.b #28, (cursor_y)                | Should we start scrolling?
    blt _skipPrintChar                   | No
    move.b #1, (scrolling)

_scrollPage:
    move.w (vscroll_amount), %d5
    add.w #8, %d5                         | Scroll single line (8 pixels)
    move.w %d5, (vscroll_amount)

    # Write Plane A's V-scroll value to vertical scroll memory (VSRAM)
	#   Plane A's vertical page scroll value is at VSRAM $0000,Plane B's is at $0002.
    move.l #vdp_cmd_vsram_write, VDP_CONTROL
    move.w %d5, (VDP_DATA)
_skipPrintChar:
    movem.l (%sp)+, %d0/%d1/%d2/%d4/%d5
    rts

#==============================================================
# Clear the current line
#==============================================================
clearLine:
    move.b #0, (cursor_x)
    movem.l %d1/%d2/%d3, -(%sp)
    clr.l %d1
    move.b cursor_y, %d1
    lsl.w #7, %d1                         | Multiply y by 128 (shift left 7 bits)
    or.w #vram_addr_plane_a, %d1          | add.l #vram_addr_plane_a, %d1

    # Prepare VDP command
    move.l %d1, %d2

	lsr.l #7, %d2
	lsr.l #7, %d2                           | Get bits A15-A14 into lowest bits

	lsl.l #7, %d1
	lsl.l #7, %d1
	lsl.l #2, %d1                        | Move bits A13-A0 to bits 29-16

    and.l #0x3FFF0000, %d1                | Keep only bits 29-16
    or.l %d2, %d1                         | Combine
    or.l #vdp_cmd_vram_write, %d1         | Set bit 30, CD0=1 (write)
    move.l %d1, (VDP_CONTROL)

    # Clear the line by writing zeros
    moveq #19, %d1                        | Iterator from 19 down to -1
_clearChar:
    move.l #0, (VDP_DATA)                 | 0 is the empty tile
    dbra %d1, _clearChar
    movem.l (%sp)+, %d1/%d2/%d3
    rts
