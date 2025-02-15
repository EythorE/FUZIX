#include "control_ports.def"
#define VT_HEIGHT	28

.equ vdp_cmd_vram_write, 0x40000000
.equ vdp_cmd_vsram_write, 0x40000010    | Vertical Scroll RAM address
.equ vram_addr_plane_a, 0xC000

    .globl vscroll_amount
   .section .data

vscroll_amount:
    .word 0                              | Keep track of how much we scrolled
    

    .globl do_beep, cursor_disable, cursor_off, cursor_on
    .globl clear_across, clear_lines, scroll_up, scroll_down, plot_char
    .section .text

# void do_beep(void)
do_beep:
rts

# void cursor_disable(void)
cursor_disable:
rts

# void cursor_off(void)
cursor_off:
rts

# void cursor_on(int8_t x, int8_t y)
cursor_on:
    # 4(%sp) - x (4 bytes)
    # 8(%sp) - y (4 bytes)
rts

# void clear_across(int8_t y, int8_t x, int16_t num)
# Clear num characters across from y,x
clear_across:
    # what arguments are we even calling this with?
    # 4(%sp) - y (4 bytes)
    # 8(%sp) - x (4 bytes)
    # 12(%sp) - num (4 bytes)
    move.l #0x40000003, %d1

    # y to d0
    clr.l %d0
    move.w (vscroll_amount), %d0 | Need this to map y to vdp coordinates
    lsr.w   #3, %d0              | B // 8
    add.w 6(%sp),%d0             | y + scroll_up
    and.w #0x1F, %d0             | Modulo 32 (rows in VRAM)
    # d0 contains the y row

    rol.l #8, %d0
    rol.l #8, %d0
    rol.l #7, %d0
    add.l %d0, %d1

    move.b 11(%sp), %d0
    rol.l #8, %d0
    rol.l #8, %d0
    rol.l #1, %d0
    add.l %d0, %d1

    move.l %d1, (VDP_CONTROL)
    move.l #0,%d0

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
    # 4(%sp) - y (4 bytes)
    # 8(%sp) - num (4 bytes)

    # y to d0
    clr.l %d0
    move.w (vscroll_amount), %d0 | Need this to map y to vdp coordinates
    lsr.w   #3, %d0              | B // 8
    add.w 6(%sp),%d0             | y + scroll_up
    and.w #0x1F, %d0             | Modulo 32 (rows in VRAM)
    # d0 contains the y row

    lsl.w #7, %d0                         | Multiply y by 128 (shift left 7 bits)
    or.w #vram_addr_plane_a, %d0          | add.l #vram_addr_plane_a, %d0

    # Prepare VDP command
    move.l %d0, %d1

	lsr.l #7, %d1
	lsr.l #7, %d1                           | Get bits A15-A14 into lowest bits

	lsl.l #7, %d0
	lsl.l #7, %d0
	lsl.l #2, %d0                         | Move bits A13-A0 to bits 29-16

    and.l #0x3FFF0000, %d0                | Keep only bits 29-16
    or.l %d1, %d0                         | Combine
    or.l #vdp_cmd_vram_write, %d0         | Set bit 30, CD0=1 (write)
    move.l %d0, (VDP_CONTROL)

    # Clear the line by writing zeros
    # this could be optimized, skipping the 24 bytes or doing dma
    move.w #0,%d0
    moveq #64, %d1        | 40 characters per line (64 in vram)
    mulu.w 10(%sp), %d1   | Iterator from down to 0
    bra   _clrl_loop       | Jump to counter check first
clrl_loop:
    move.w %d0, (VDP_DATA) | 0 is the empty tile
_clrl_loop:
    dbra.w    %d1, clrl_loop  | Decrement and branch if not -1
    rts




# void scroll_up(void)
# Normal scroll, the bottom line does not need to be cleared.
scroll_up:
    move.w (vscroll_amount), %d0
    add.w #8, %d0                         | Scroll single line (8 pixels)
    move.w %d0, (vscroll_amount)

    # Write Plane A's V-scroll value to vertical scroll memory (VSRAM)
	#   Plane A's vertical page scroll value is at VSRAM $0000,Plane B's is at $0002.
    move.l #vdp_cmd_vsram_write, VDP_CONTROL
    move.w %d0, (VDP_DATA)
    rts


# void scroll_down(void)
# Reverse scroll, the top line does not need to be cleared.
scroll_down:
    move.w (vscroll_amount), %d0
    sub.w #8, %d0                         | Scroll single line (8 pixels)
    move.w %d0, (vscroll_amount)
    move.l #vdp_cmd_vsram_write, VDP_CONTROL
    move.w %d0, (VDP_DATA)
    rts




# void plot_char(int8_t y, int8_t x, uint16_t c)
# Currently c is in the range 0-255
plot_char:
    # y to d0
    clr.l %d0
    move.w (vscroll_amount), %d0 | map y to vdp coordinates
    lsr.w   #3, %d0              | B // 8
    add.w 6(%sp),%d0             | y + scroll_up
    and.w #0x1F, %d0             | Modulo 32 (rows in VRAM)
    # d0 contains the y row

    move.l #0x40000003, %d1
    rol.l #8, %d0
    rol.l #8, %d0
    rol.l #7, %d0
    add.l %d0, %d1

    move.b 11(%sp), %d0 | x
    rol.l #8, %d0
    rol.l #8, %d0
    rol.l #1, %d0
    add.l %d0, %d1

    move.l %d1, (VDP_CONTROL)
    clr.l %d0
    move.b 15(%sp), %d0   | The ascii we want to print
    cmp.b #0x0A, %d0                      | Carriage return
    beq _skipPrintChar
    cmp.b #127, %d0                       | Is it higher than the highest printable character?
    bgt _skipPrintChar
    sub.b #32, %d0
    bmi _skipPrintChar                    | Less than space

    move.w %d0, (VDP_DATA)
_skipPrintChar:
    rts