#include "../control_ports.def"

# SetXramAddrReg: macro reg, cmd
#     and.l   #$FFFF, reg
#     lsl.l   #2, reg
#     lsr.w   #2, reg
#     swap    reg
#     or.l    #cmd, reg
#     move.l  reg, (VdpCtrl)
#     endm
    # wierd bit layout;
    # 31	30	29	28	27	26	25	24		23	22	21	20	19	18	17	16
    # CD1	CD0	A13	A12	A11	A10	A09	A08		A07	A06	A05	A04	A03	A02	A01	A00
    # 15	14	13	12	11	10	9	8		7	6	5	4	3	2	1	0
    # 0 	0	0	0	0	0	0	0		CD5	CD4	CD3	CD2	0	0	A15	A14
    # move.l #0x40000003, %d5   | cd0 = 1 (write), A=0xC000 (A15=1 A14=1 A13=0 A12=0) plane a
.equ vdp_cmd_vram_write, 0x40000000
# .equ vdp_cmd_vsram_write, 0x40000010    | Vertical Scroll plane a
.equ vdp_cmd_vsram_write, 0x40020010    | Vertical Scroll plane b

# .equ vram_addr_plane, 0xC000 | plane a
.equ vram_addr_plane, 0xE000 | plane b

# .equ vram_addr_plane_write, 0x40000003  | cd0 = 1 (write), A=0xC000 (A15=1 A14=1 A13=0 A12=0) plane a
.equ vram_addr_plane_write, 0x60000003  | cd0 = 1 (write), A=0xE000 (A15=1 A14=1 A13=1 A12=0) plane b


.equ debug_window_size, 20 | rows

    .section .data
cursor_x:
    .byte 0
cursor_y:
    .byte 0
scrolling:
    .byte 0                              | Are we scrolling? 1 if yes!
    .even
vscroll_amount:
    .word 0                              | Keep track of how much we scrolled


    .section .text
    .globl printString, printStringA0, printChar, printLong, printWord, printByte, clearLine, outchar, newline
    .globl outchar,dbg_registers,dbg_memory

#==============================================================
# Print zero-terminated string at %a0
# Trashes %d0, %a0
#==============================================================
printString:
    move.l 4(%sp), %a0                   | Load the string address from the stack
# Print zero-terminated string at %a0
# trashes %d0, %d1
printStringA0:
    move.b (%a0)+, %d0
    cmp.b #0, %d0
    beq _zt
    jsr printChar
    bra printStringA0
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
    jsr     .LprintHex      | Output hex digit.
    move.b  %d1, %d0        | Restore A.
.LprintHex:
    and.b   #0x0F, %d0      | Mask LSD for hex print.
    or.b    #0x30, %d0      | Add "0".
    cmp.b   #0x39, %d0      | Digit?
    ble     printChar       | Yes, output it.
    add.b   #0x07, %d0      | Add offset for letter.
    # bra printChar
# fuzix kernel method
# void plot_char(int8_t y, int8_t x, uint16_t c) # Currently c is in the range 0-255
# plot_char:
#     move.b 7(%sp), (cursor_y)
#     move.b 11(%sp), (cursor_x)
#     clr.l %d0
#     move.b 15(%sp), %d0
#     and.l #0xFF, %d0

outchar:
printChar:
    movem.l %d0/%d1/%d2/%d4/%d5, -(%sp)
    and.l #0xFF, %d0
    cmp.b #0x0A, %d0                      | Carriage return
    beq _newline
    cmp.b #127, %d0                       | Is it higher than the highest printable character?
    bgt _skipPrintChar
    sub.b #32, %d0
    bmi _skipPrintChar                    | Less than space
_printCharNoCheck:
    move.l #vram_addr_plane_write, %d5   | cd0 = 1 (write), A=0xE000 (A15=1 A14=1 A13=1 A12=0) plane b

    move.l #0, %d4
    move.b (cursor_y), %d4
    swap %d4
    rol.l #7, %d4
    add.l %d4, %d5

    move.b (cursor_x), %d4
    swap %d4
    rol.l #1, %d4
    add.l %d4, %d5
    #       15|   14,13 |    12 |    11 |       10-0
    # Priority | Palette | VFlip | HFlip | Tile Index
    add.w #0xA000,%d0
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

    cmp.b #debug_window_size, (cursor_y)                | Should we start scrolling?
    blt _skipPrintChar                   | No
    move.b #1, (scrolling)

_scrollPage:
    # clear 1st line since we are not using the full screen for this plane
    move.b (cursor_y),%d5
    move.b %d5,%d0
    sub.b #debug_window_size,%d0
    and.b #0x1F,%d0              | Modulo 32 (rows in VRAM)
    move.b %d0,(cursor_y)
    jsr clearLine
    move.b %d5,(cursor_y)


    move.w (vscroll_amount), %d5
    add.w #8, %d5                         | Scroll single line (8 pixels)
    move.w %d5, (vscroll_amount)

    # Write Plane's V-scroll value to vertical scroll memory (VSRAM)
	#   Plane's vertical page scroll value is at VSRAM $0000,Plane B's is at $0002.
    move.l #vdp_cmd_vsram_write, VDP_CONTROL
    move.w %d5, (VDP_DATA)
_skipPrintChar:
    movem.l (%sp)+, %d0/%d1/%d2/%d4/%d5
    rts


newline:
    movem.l %d0/%d1/%d2/%d4/%d5, -(%sp)
    bra _newline


#==============================================================
# Clear the current line | bit long and old
#==============================================================
# clearLine:
#     move.b #0, (cursor_x)
#     movem.l %d1/%d2/%d3, -(%sp)
#     clr.l %d1
#     move.b cursor_y, %d1
#     lsl.w #7, %d1                         | Multiply y by 128 (shift left 7 bits)
#     or.w #vram_addr_plane, %d1            | add.l #vram_addr_plane, %d1

#     # Prepare VDP command
#     move.l %d1, %d2

# 	lsr.l #7, %d2
# 	lsr.l #7, %d2                           | Get bits A15-A14 into lowest bits

# 	lsl.l #7, %d1
# 	lsl.l #7, %d1
# 	lsl.l #2, %d1                        | Move bits A13-A0 to bits 29-16

#     and.l #0x3FFF0000, %d1                | Keep only bits 29-16
#     or.l %d2, %d1                         | Combine
#     or.l #vdp_cmd_vram_write, %d1         | Set bit 30, CD0=1 (write)
#     move.l %d1, (VDP_CONTROL)

#     # Clear the line by writing zeros
#     moveq #19, %d1                        | Iterator from 19 down to -1
# _clearChar:
#     move.l #0, (VDP_DATA)                 | 0 is the empty tile
#     dbra %d1, _clearChar
#     movem.l (%sp)+, %d1/%d2/%d3
#     rts


clearLine:
    movem.l %d0/%d1/%d4/%d5, -(%sp)
    move.l #0, %d0
    move.b %d0,(cursor_x) | set cursor to start of line
    
    move.l #vram_addr_plane_write, %d5   | cd0 = 1 (write), A=0xE000 (A15=1 A14=1 A13=1 A12=0) plane b

    move.l #0, %d4
    move.b (cursor_y), %d4
    swap %d4
    rol.l #7, %d4
    add.l %d4, %d5
    move.l %d5, (VDP_CONTROL)

    # Clear the line by writing zeros
    moveq #19, %d1                        | Iterator from 19 down to -1
_clearChar:
    move.l %d0, (VDP_DATA)                 | 0 is the empty tile (using pallette A, low priority, transparent)
    dbra %d1, _clearChar
    movem.l (%sp)+, %d0/%d1/%d4/%d5
    rts


# https://www.chibiakumas.com/68000/
dbg_registers:
    movem.l %d0-%d7/%a0-%a7,-(%sp) | we are outputting these
    move.l %sp,%a0
    
    move.w #'0',%d5         | Start with register 0
    
showNextReg:
    move.w #'D',%d0         | Show D register
    bsr printChar
    move.w %d5,%d0
    bsr printChar
    move.w #':',%d0
    bsr printChar
    move.l (%a0),%d0
    bsr printLong
    
    move.w #' ',%d0
    bsr printChar
    bsr printChar
    bsr printChar
    
    add #8*4,%a0
    
    move.w #'A',%d0         | Show A register
    bsr printChar
    move.w %d5,%d0
    bsr printChar
    move.w #':',%d0
    bsr printChar
    move.l (%a0),%d0
    bsr printLong
    
    sub #8*4,%a0
    add #4,%a0
    
    bsr newline
    
    add #1,%d5
    cmp #'8',%d5
    bne showNextReg         | Show D/A + 1
    
    add #8*4,%a0
    move.w #'P',%d0         | Show PC
    bsr printChar
    move.w #'C',%d0
    bsr printChar
    move.w #':',%d0
    bsr printChar
    move.l (%a0),%d0
    bsr printLong
    bsr newline    

    movem.l (%sp)+,%d0-%d7/%a0-%a7
    rts




# Usage:
#    lea Address,%a0
#    moveq.l #6,%d0
#    jsr dbg_memory
dbg_memory:
    movem.l %d0-%d7/%a0-%a7,-(%sp)
    movea.l %a0,%a1
    move.w %d0,%d4
    bsr Monitor_MemDumpDraw
    movem.l (%sp)+,%d0-%d7/%a0-%a7
    rts
    
    
Monitor_MemDumpDraw:    
    move.l %a1,%d0
    bsr printLong 
    move.b #':',%d0
    bsr printChar
    bsr newline

MemDump_NextLine:
    move.l #7,%d3
MemDump_NextByte:
    move.b (%a1)+,%d0
    bsr printByte
    move.b #' ',%d0
    bsr printChar
    dbra %d3,MemDump_NextByte
    
    subq.l #8,%a1
    move.w #7,%d3
MemDump_NextChar:
    move.b (%a1)+,%d0
    cmp #32,%d0
    blt MemDump_BadChar
    cmp #128,%d0
    bgt MemDump_BadChar
    bra MemDump_OkChar
MemDump_BadChar:
    move.b #'.',%d0
MemDump_OkChar:
    bsr printChar
    dbra %d3,MemDump_NextChar
    bsr newline
    
    sub.b #1,%d4
    bne MemDump_NextLine
    
    rts
