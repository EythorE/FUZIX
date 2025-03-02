#include "../control_ports.def"

.equ vdp_cmd_vram_write, 0x40000000
.equ vdp_cmd_cram_write, 0xC0000000

#==============================================================
# Initialization routines
#==============================================================
    .section .text
    .globl VDP_WriteTMSS
    .globl VDP_writePallete
    .globl VDP_LoadRegisters
    .globl VDP_ClearVRAM

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
    move.l sega,TMSS_ADDRESS
SkipTMSS:
    move.w VDP_CONTROL,%d0
    rts


#==============================================================
# Clear VRAM
#==============================================================
.set size_word, 2
.set loop_counter, (0x00010000 / size_word) - 1  |  64kb in words (-1 for DBRA loop)
VDP_ClearVRAM:
	# Setup the VDP to write to VRAM address $0000 (start of VRAM)
    move.l #vdp_cmd_vram_write, (VDP_CONTROL) | set_vram_write $0000
    move.w #loop_counter, %d0
ClrVramLp:                    | Start of loop
    move.w #0x0, (VDP_DATA)   | Write a 0x0000 (word size) to VRAM
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
    move.w (%a0)+, VDP_DATA
    dbra %d0, PalLp
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
    .byte 0x81  | $0C: Shadows and highlights off, interlace off, H40 mode (320 x 224 screen res)
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
# (0,2,4,6,8,A,C,E). So 0x0000 is black, 0x0EEE is white
# 0x000E is red, 0x00E0 is green, and 0x0E00 is blue.
#==============================================================
Palette:
    .word 0x0000  | Colour 0 = Transparent
    .word 0x0000  | Colour 2 = Black
    .word 0x0EEE  | Colour 1 = White
    .word 0x000E  | Colour 3 = Red
    .word 0x00E0  | Colour 4 = Blue
    .word 0x0E00  | Colour 5 = Green
    .word 0x0E0E  | Colour 6 = Pink
    .word 0x0000  | Leave the rest black...
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000

Palette1:
    .word 0x00E0  | Colour 4 = Blue
    .word 0x0EEE  | Colour 1 = White
    .word 0x000E  | Colour 3 = Red
    .word 0x0000  | Colour 2 = Black
    .word 0x0000  | Colour 0 = Transparent
    .word 0x0E00  | Colour 5 = Green
    .word 0x0E0E  | Colour 6 = Pink
    .word 0x0000  | Leave the rest black...
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000
    .word 0x0000
