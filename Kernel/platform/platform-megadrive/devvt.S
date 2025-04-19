#include "control_ports.def"
#define VT_HEIGHT	28

.equ vdp_cmd_vram_write, 0x40000000
.equ vram_addr_plane_write, 0x40000003  | cd0 = 1 (write), A=0xC000 (A15=1 A14=1 A13=0 A12=0)
.equ vram_addr_plane_read, 0x00000003  | cd0 = 1 (write), A=0xC000 (A15=1 A14=1 A13=0 A12=0)
#.equ vram_addr_planeA_write, 0x40000003  | cd0 = 1 (write), A=0xC000 (A15=1 A14=1 A13=0 A12=0) plane a
#.equ vram_addr_planeB_write, 0x60000003  | cd0 = 1 (write), A=0xE000 (A15=1 A14=1 A13=1 A12=0) plane b
.equ vdp_cmd_vsram_write, 0x40000010    | Vertical Scroll plane a
#.equ vdp_cmd_vsram_write, 0x40020010    | Vertical Scroll plane b
.equ vram_addr_sprite_write, 0x70000003  | cd0 = 1 (write), A=0xF000 (A15=1 A14=1 A13=1 A12=1)

    .globl scroll_amount
   .section .data
scroll_amount:
    .word 0                              | Keep track of how much we scrolled
    .align(2)

    .globl do_beep, cursor_disable, cursor_off, cursor_on
    .globl clear_across, clear_lines, scroll_up, scroll_down, plot_char
    .section .text

# void do_beep(void)
do_beep:
rts

/* Needed for hardware cursors */
# void cursor_disable(void)
cursor_disable:
rts

# void cursor_off(void)
cursor_off:
#    # The cursor flashes if we are doing this and we really dont want to wait for blank
#    move.l #vram_addr_sprite_write, (VDP_CONTROL)
#    # move the sprite out of screen
#    move.w #0, (VDP_DATA)
    rts


read_cursor_char:
    # get the character under the cursor from vdp
    # args: y: d0, x: d1
    # returns sprite num in d4
    movem.l %d2-%d3,-(%sp)
    clr.l %d2
    move.w (scroll_amount), %d2 | map y to vdp coordinates
    lsr.w   #3, %d2              | B // 8
    add.w %d0, %d2             | y + scroll_up
    and.w #0x1F, %d2             | Modulo 32 (rows in VRAM)
    # d2 contains the y row

    move.l #vram_addr_plane_read, %d3
    swap %d2
    rol.l #7, %d2
    add.l %d2, %d3

    move.b %d1, %d2 | x
    swap %d2
    rol.l #1, %d2
    add.l %d2, %d3

    move.l %d3, (VDP_CONTROL)
    move.w (VDP_DATA), %d4
    movem.l (%sp)+, %d2-%d3
    rts
    

cursor_sprite:
    move.l #vram_addr_sprite_write, (VDP_CONTROL)
    # y in d0
    # x in d1
    lsl.w   #3, %d0              | y*8, each character is 8 pixels
    lsl.w   #3, %d1              | x*8

    # start of visible area is at 128x128
    add.l #128, %d0
    add.l #128, %d1

    swap %d0 | lower word should be 0 size,next 

    swap %d1
    move.w #0b0100000000000000,%d1 | priority, attr(plt 2),gfx 221=0xDD=0b11011101
    move.b %d4, %d1
    swap %d1

    move.l %d0, (VDP_DATA)
    move.l %d1, (VDP_DATA)
    rts


# void cursor_on(int8_t y, int8_t x)
cursor_on:
    # 4(%sp) - y (4 bytes)
    # 8(%sp) - x (4 bytes)
    movem.l %d0-%d1, -(%sp)
    move.l 12(%sp),%d0
    move.l 16(%sp),%d1
    bsr read_cursor_char
    # d4 contains sprite
    bsr cursor_sprite
    movem.l (%sp)+, %d0-%d1
    rts


# void clear_across(int8_t y, int8_t x, int16_t num)
# Clear num characters across from y,x
clear_across:
    # what arguments are we even calling this with?
    # 4(%sp) - y (4 bytes)
    # 8(%sp) - x (4 bytes)
    # 12(%sp) - num (4 bytes)
    move.l #vram_addr_plane_write, %d1

    # y to d0
    clr.l %d0
    move.w (scroll_amount), %d0 | Need this to map y to vdp coordinates
    lsr.w   #3, %d0              | B // 8
    add.w 6(%sp),%d0             | y + scroll_up
    and.w #0x1F, %d0             | Modulo 32 (rows in VRAM)
    # d0 contains the y row

    swap %d0
    rol.l #7, %d0
    add.l %d0, %d1

    move.b 11(%sp), %d0
    swap %d0
    rol.l #1, %d0
    add.l %d0, %d1

    move.l %d1, (VDP_CONTROL)
    clr.l %d0
    #move.l #0x80008000,%d0 | high priority

    move.l 12(%sp), %d1   | Iterator from down to 0
    bra   _clr_loop       | Jump to counter check first
clr_loop:
    move.w %d0, (VDP_DATA) | 0 is the empty tile
_clr_loop:
    dbra.w    %d1, clr_loop  | Decrement and branch if not -1
    rts



# void clear_lines(int8_t y, int8_t num)
# Clear num lines starting at line y
clear_lines:
    movem.l %d0-%d5, -(%sp)
    # 4(%sp) - y (4 bytes)
    # 8(%sp) - num (4 bytes)
    move.w (scroll_amount), %d1
    move.w 30(%sp), %d2 |y 6 (+24 bytes pushed to the stack)
    move.w 34(%sp), %d3 |n 10 (+24)
    move.l #vram_addr_plane_write,%d4
    clr.l %d5
    #move.l #0x80008000,%d5 | high priority

    bra   _clrline_loop | loop until %d2 < 0
# We just clear a line N times
clrline_loop:
    # y to d0
    clr.l %d0
    move.w %d1, %d0 | scroll -> %d0, Need this to map y to vdp coordinates
    lsr.w   #3, %d0              | B // 8
    add.w %d2,%d0             | y + scroll_up
    and.w #0x1F, %d0             | Modulo 32 (rows in VRAM)
    # d0 contains the y row

    lsl.w #7, %d0                         | Multiply y by 128 (bytes per tile 2px per byte 8x8 tiles)
    # these are the lower 14 bytes of the vram address a15 and a14 are 11 (0xC000)
    # it should be in a31-a16
    swap %d0
    or.l %d4,%d0 | vram_addr_plane_write -> d0
    move.l %d0, (VDP_CONTROL)

    # Clear the line by writing zeros
    moveq #19, %d0                        | Iterator from 19 down to -1
_clearAChar:
    move.l %d5, (VDP_DATA)                 | 0 is the empty tile (using pallette A, low priority, transparent)
    dbra %d0, _clearAChar

    addq.w #1,%d2 | increment y
_clrline_loop:
    dbra.w    %d3, clrline_loop  | Decrement and branch if not -1

    movem.l (%sp)+, %d0-%d5
    rts



# void scroll_up(void)
# Normal scroll, the bottom line does not need to be cleared.
scroll_up:
    move.w (scroll_amount), %d0
    add.w #8, %d0                         | Scroll single line (8 pixels)
    move.w %d0, (scroll_amount)

    # Write Plane A's V-scroll value to vertical scroll memory (VSRAM)
	#   Plane A's vertical page scroll value is at VSRAM $0000,Plane B's is at $0002.
    move.l #vdp_cmd_vsram_write, VDP_CONTROL
    move.w %d0, (VDP_DATA)
    rts


# void scroll_down(void)
# Reverse scroll, the top line does not need to be cleared.
scroll_down:
    move.w (scroll_amount), %d0
    sub.w #8, %d0                         | Scroll single line (8 pixels)
    move.w %d0, (scroll_amount)
    move.l #vdp_cmd_vsram_write, VDP_CONTROL
    move.w %d0, (VDP_DATA)
    rts




# void plot_char(int8_t y, int8_t x, uint16_t c)
# Currently c is in the range 0-255
plot_char:
    # y to d0
    clr.l %d0
    move.w (scroll_amount), %d0 | map y to vdp coordinates
    lsr.w   #3, %d0              | B // 8
    add.w 6(%sp),%d0             | y + scroll_up
    and.w #0x1F, %d0             | Modulo 32 (rows in VRAM)
    # d0 contains the y row

    move.l #vram_addr_plane_write, %d1
    swap %d0
    rol.l #7, %d0
    add.l %d0, %d1

    move.b 11(%sp), %d0 | x
    swap %d0
    rol.l #1, %d0
    add.l %d0, %d1

    move.l %d1, (VDP_CONTROL)
    move.w 14(%sp), %d0   | The ascii we want to print
    # cmp.b #0x0A, %d0                      | Carriage return
    # beq _skipPrintChar
    # cmp.b #127, %d0                       | Is it higher than the highest printable character?
    # bgt _skipPrintChar
    # sub.b #32, %d0 | larger font now
    # bmi _skipPrintChar                    | Less than space

    #add.w #0x8000,%d0 | high priority

    move.w %d0, (VDP_DATA)
_skipPrintChar:
    clr.l %d0
    move.l %d0,%d1

    rts
