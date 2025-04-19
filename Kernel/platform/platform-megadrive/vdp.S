#include "control_ports.def"

.equ vdp_cmd_vram_write, 0x40000000
.equ vdp_cmd_vsram_a_write, 0x40000010    | Vertical Scroll plane a
.equ vdp_cmd_vsram_b_write, 0x40020010    | Vertical Scroll plane b
.equ vdp_cmd_cram_write, 0xC0000000

#==============================================================
# Initialization routines
#==============================================================
    .section .text
    .globl VDP_WriteTMSS
    .globl VDP_writePallete
    .globl VDP_LoadRegisters
    .globl VDP_ClearVRAM
    .globl fontInit
    .globl VDP_reinit
    .globl VDP_clear



VDP_clear:
    movem.l %d0/%d1/%a0/%a1, -(%sp)
    bsr VDP_clearPallete
    bsr VDP_ClearVRAM
    bsr VDP_LoadRegisters
    move.l #vdp_cmd_vsram_a_write,(VDP_CONTROL)
    move.w #0,(VDP_DATA)
    move.l #vdp_cmd_vsram_b_write,(VDP_CONTROL)
    move.w #0,(VDP_DATA)
    movem.l (%sp)+, %d0/%d1/%a0/%a1
    rts


VDP_reinit:
    movem.l %d0/%d1/%a0/%a1, -(%sp)
    bsr VDP_clearPallete
    bsr VDP_ClearVRAM
    bsr VDP_LoadRegisters
    bsr VDP_writePallete
    move.l #vdp_cmd_vsram_a_write,(VDP_CONTROL)
    move.w #0,(VDP_DATA)
    move.l #vdp_cmd_vsram_b_write,(VDP_CONTROL)
    move.w #0,(VDP_DATA)
    move.w #0,(scroll_amount)
    jsr dbg_clear
    bsr fontInit
    movem.l (%sp)+, %d0/%d1/%a0/%a1
    rts

#==============================================================
# Initialize TMSS (Trademark Security System)
#==============================================================
# The TMSS (Trademark Security System) locks up the VDP if we don't
# write the string 'SEGA' to a special address. This was to discourage
# unlicensed developers, since doing this displays the "LICENSED BY SEGA
# ENTERPRISES LTD" message to screen (on Mega Drive models 1 and higher).
#
# First, we need to check if we're running on a model 1+, then write
# 'SEGA' to hardware address $A14000.
.equ sega, 0x53454741 | "SEGA"
VDP_WriteTMSS:
    move.b HARDWARE_VER_ADDRESS,%d0
    andi.b #0x0F,%d0
    beq SkipTMSS
    move.l #sega,TMSS_ADDRESS
SkipTMSS:
    move.w VDP_CONTROL,%d0
    rts


#==============================================================
# Clear VRAM
#==============================================================
.set size_long, 4
.set loop_counter, (0x00010000 / size_long) - 1  |  64kb in longs (-1 for DBRA loop)
VDP_ClearVRAM:
	# Setup the VDP to write to VRAM address $0000 (start of VRAM)
    move.l #vdp_cmd_vram_write, (VDP_CONTROL) | set_vram_write $0000
    move.w #loop_counter, %d0
ClrVramLp:                    | Start of loop
    move.l #0x0, (VDP_DATA)   | Write a 0x0000 (word size) to VRAM
    dbra %d0, ClrVramLp       | Decrement d0 and loop until finished (when d0 reaches -1)
    rts


#==============================================================
# Write the palette to CRAM (colour memory)
#==============================================================
# send a command to the vdp with the address we want to write to
# then loop through the pallet and write it to the cram
VDP_writePallete:
    move.l #vdp_cmd_cram_write, VDP_CONTROL  | set_cram_write $0000
    lea Palette, %a0
    move.w #31, %d0     | 8 words in palette (8*2 -1 for DBRA loop)
PalLp:
    move.l (%a0)+, VDP_DATA
    dbra %d0, PalLp
    rts


VDP_clearPallete:
    move.l #vdp_cmd_cram_write, VDP_CONTROL  | set_cram_write $0000
    lea Palette, %a0
    move.l #31, %d0     | 8 words in palette 4 palletes (8*4//2 words -1 for DBRA loop)
    move.l #0, %d1
ClPalLp:
    move.l %d1, VDP_DATA
    dbra %d0, ClPalLp
    rts


#==============================================================
# Load VDP register initial values
#==============================================================
# To initialize the VDP, we write all of its initial register values from
# the VDPRegisters table to the VDP_CONTROL port
#
# To write a register, we write a word to the control port.
# The top bit must be set to 1 (so $8000), bits 8-12 specify the register
# number to write to, and the bottom byte is the value to set.
#
# In binary:
#   10$ XXXX YYYY YYYY
#   X = register number
#   Y = value to write
VDP_LoadRegisters:
    lea VDPRegisters, %a0     | Load address of register table into a0
    move.w #0x18-1, %d0       | 24 registers to write (-1 for loop counter)
    move.w #0x8000, %d1       | 'Set register 0' command to d1
CopyRegLp:
    move.b (%a0)+, %d1        | Move register value from table to lower byte of d1 (and post-increment the table address for next time)
    move.w %d1, (VDP_CONTROL)    | Write command and value to VDP control port
    addi.w #0x0100, %d1        | Increment register #
    dbra %d0, (CopyRegLp)        |  Decrement d0, bra if d0 is still >= 0
    rts


#==============================================================
# Write font glyphs to VRAM
#==============================================================
#ifdef CONFIG_FONT8X8SMALL
#define FONTDATAMAX 768
#else
#define FONTDATAMAX 2048
#endif
.equ loop_counter, FONTDATAMAX-1  | number of bytes - 1 for dbra
fontInit:
	move.l 	#loop_counter, %d2 ;
	lea fontdata_8x8, %a1
	# Start writes to address zero 
	move.l #vdp_cmd_vram_write, VDP_CONTROL  | set_vram_write 0x0 (vram_addr_tiles)
nextFont:
	move.b	(%a1)+, %d0  | load the first byte of the font
	clr.l %d1           | we will have to convert bits to bytes (%xxxxxxx to $xxxxxxxx)

	# rol the first bit into d1, through the extend bit
	roxl.b	#1, %d0
	roxl.L	#1, %d1

	# have to move the lsbit 3 places left 1000, then rol a new bit in 0001 0001
	move.l  #6, %d3     | do that 7 time (-1 for dbra)
rolin:
	rol.l   #3, %d1     | have to move the bit 3 places left 1000 then rol a new bit in 0001 0001
	roxl.b	#1, %d0
	roxl.l	#1, %d1
	dbra    %d3, rolin

	# add 1 to each nibble for the backround to be non transparent
	add.l #0x11111111,%d1

	move.l	%d1, (VDP_DATA)	| write long to VDP
	dbra	%d2, nextFont		| loop until done

    # add an additional cursor tile | this was for shadow/highlight cursor, it was suboptimal!
#    move.w #7, %d0
#    move.l #0xEEEEEEEE,%d1
#_lp_cursor_tile:
#	move.l	%d1, (VDP_DATA)	| write long to VDP
#	dbra	%d0, _lp_cursor_tile | loop until done
    rts




#==============================================================
# DATA
#==============================================================
    .section .rodata
    .globl VDPRegisters
    .globl Palette

#==============================================================
# INITIAL VDP REGISTER VALUES
#==============================================================
# 24 register values to be copied to the VDP during initialization.
# These specify things like initial width/height of the planes,
# addresses within VRAM to find scroll/sprite data, the
# background palette/color index, whether or not the display
# is on, and clears initial values for things like DMA.
#==============================================================
# Set VDP mode to enable display
#==============================================================
#7 6 5 | 4 3 2 1 0 | lower_byte 
#1 0 0 | [RS4-RS0] | [d7-d0 data]
# $01 - Mode Register 2 data = %01000100(0x44) unblank display
# VRAM	DE	IE0	M1	M2	M5	0	0
# 0 - VRAM allows use of an additional 64 KB of external VRAM. [2]
# 1 - DE decides if the display is enabled (1) or disabled (0).
# 0 - IE0 enables the vertical blank interrupt, or VBI. This is a Level 6 interrupt to the M68k.
# 0 - M1 allows DMA to be performed when set, while it disables any sort of DMA when it is not set. This bit also masks CD5 in the VDP control word if cleared.
# 0 - M2 sets the vertical display mode/resolution. When set to 1, 30 cell (240 pixel) mode is enabled, which is exclusive to PAL. When set to 0, 28 cell (224 pixel) mode is enabled, which is always the case on NTSC. Enabling 30 cell mode on an NTSC Mega Drive will cause the image to roll upwards and be unstable, as well as causing vertical interrupts to happen at 30 Hz, and no vertical sync pulse to be output on the video connector.
# 1 - M5 selects between Master System (Mode 4) and Mega Drive (Mode 5) video modes. Should always be set to 1 when programming Mega Drive software.
# move.w	#$8144, (VDP_CONTROL)
VDPRegisters:
    .byte 0x14  | $00:  H interrupt on, palettes on
    .byte 0x74  | $01:  V interrupt on, display on, DMA on, Genesis mode on
    .byte 0x30  | $02:  Pattern table for Scroll Plane A at VRAM $C000 (bits 3-5 = bits 13-15)
    .byte 0x00  | $03:  Pattern table for Window Plane at VRAM $0000 (disabled) (bits 1-5 = bits 11-15)
    .byte 0x07  | $04:  Pattern table for Scroll Plane B at VRAM $E000 (bits 0-2 = bits 11-15)
    .byte 0x78  | $05:  Sprite table at VRAM $F000 (bits 0-6 = bits 9-15)
    .byte 0x00  | $06:  Unused
    .byte 0x00  | $07:  Background colour: bits 0-3 = colour, bits 4-5 = palette
    .byte 0x00  | $08:  Unused
    .byte 0x00  | $09:  Unused
    .byte 0x08  | $0A: Frequency of Horiz. interrupt in Rasters (number of lines travelled by the beam)
    .byte 0x00  | $0B: External interrupts off, V scroll fullscreen, H scroll fullscreen
    .byte 0x81  | $0C: Shadows and highlights 81/89 off/on, interlace off, H40 mode (320 x 224 screen res)
    .byte 0x3F  | $0D: Horiz. scroll table at VRAM $FC00 (bits 0-5)
    .byte 0x00  | $0E: Unused
    .byte 0x02  | $0F: Autoincrement 2 bytes
    .byte 0x01  | $10: Scroll plane size: 64x32 tiles
    .byte 0x00  | $11: Window Plane X pos 0 left (pos in bits 0-4, left/right in bit 7)
    .byte 0x00  | $12: Window Plane Y pos 0 up (pos in bits 0-4, up/down in bit 7)
    .byte 0xFF  | $13: DMA length lo byte
    .byte 0xFF  | $14: DMA length hi byte
    .byte 0x00  | $15: DMA source address lo byte
    .byte 0x00  | $16: DMA source address mid byte
    .byte 0x80  | $17: DMA source address hi byte, memory-to-VRAM mode (bits 6-7)

#==============================================================
# PALETTE
#==============================================================
# A single colour palette (16 colours) we'll be using to draw text.
# Colour #0 is always transparent, no matter what colour value
# you specify.
# We only use white (colour 2) and transparent (colour 0),
# the rest are just examples.
#==============================================================
# Each colour is in binary format 0000 BBB0 GGG0 RRR0
# The bottom bit is discarded, can only use even values
# (0,2,4,6,8,A,C,E).
# 0x0000: black, 0x0EEE: white, 0x0E0E: pink
# 0x000E: red, 0x00E0: green 0x0E00: blue
#==============================================================
Palette:
    .word 0x0000  | Colour 0 = Transparent (gray) / global background
    .word 0x0000  | Colour 2 = Black
    .word 0x0CCC  | Colour 1 = White
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000

    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000

Palette1:
    .word 0x0000  | Colour 0 = Transparent
    .word 0x0CCC  | dgb background
    .word 0x022C  | dbg foreground
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000

    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000  | no shadow and highlight
    .word 0x0000

Palette2:
    .word 0x0000  | Colour 0 = Transparent
    .word 0x0AAA  | cursor background
    .word 0x0222  | cursor foreground
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000

    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000  | no shadow and highlight
    .word 0x0000

Palette3:
    .word 0x0000  | Colour 0 = Transparent
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000

    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000  | highlight pixel beneath
    .word 0x0000  | shadow pixel beneath


