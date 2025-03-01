#include "../control_ports.def"
     .equ vdp_cmd_vram_write, 0x40000000

#==============================================================
# Code
#==============================================================
    .section .text
    .globl fontInit

.set loop_counter, (96*8)-1  | number of bytes (96 glyphs, 8 bytes each) - 1 for dbra

fontInit:
	move.l 	#loop_counter, %d2 ;
	lea font, %a1
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
	bra rolin
rolin:
	rol.l   #3, %d1     | have to move the bit 3 places left 1000 then rol a new bit in 0001 0001
	roxl.b	#1, %d0
	roxl.l	#1, %d1
	dbra    %d3, rolin

	# add 1 to each nibble for the backroud to be non transparent
	add.l #0x11111111,%d1

	move.l	%d1, (VDP_DATA)	| write long to VDP
	dbra	%d2, nextFont		| loop until done
	rts


    .section .rodata
#==============================================================
# Data
#==============================================================

font:
	.incbin "data/PetMe.FNT"