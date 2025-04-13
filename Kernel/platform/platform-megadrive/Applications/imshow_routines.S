#include "../control_ports.def"

    .equ vdp_cmd_cram_write, 0xC0000000
    .equ vdp_cmd_vram_write, 0x40000000

    .equ vram_addr_planeA_write, 0x40000003  | cd0 = 1 (write), A=0xC000 (A15=1 A14=1 A13=0 A12=0) plane a
    .equ vram_addr_planeB_write, 0x60000003  | cd0 = 1 (write), A=0xE000 (A15=1 A14=1 A13=1 A12=0) plane b
    .equ vram_addr_sprite_write, 0x70000003  | cd0 = 1 (write), A=0xF000 (A15=1 A14=1 A13=1 A12=1)


    .globl _imshow
    .section .text

# single arg: buffer to data
_imshow:
    move.l 4(%sp),%a0 | this is the pointer to the image, this is extremly iffy
    jsr writePallete
    jsr imgInit

    #       15|   14,13 |    12 |    11 |       10-0
    # Priority | Palette | VFlip | HFlip | Tile Index
    #low_priority foreground is shadowed
    #move.w #0x8101, %d0 | priority,  plt 0, first tile + 256 characters
    move.w #0x8001, %d0 | priority,  plt 0, first tile
    move.l #vram_addr_planeA_write, %a1
    bsr imgShow

    move.w #0x2101, %d0 | plt 1, tile 0x101
    move.l #vram_addr_planeB_write, %a1
    bsr imgShow
    
    move.l #vram_addr_sprite_write, (VDP_CONTROL)
    move.b #0x00, %d0
    move.b #0xFF, %d4 | FF if continuing after this
    move.w #0b0100001000000001,%d2 | attr(plt 3),gfx 512=0x200
    bsr tileImgShow
    # returns with %d0 as the current sprite
    move.b #0x00, %d4
    move.w #0b0110001100000001,%d2 | attr(plt 4),gfx 768=0x300
    bsr tileImgShow
    rts


# Reccomended to do this by creating tile table in memory and DMA-ing it to VDP
# %d0.b should be the current sprite
# the attrs,gfx should be in d2.w
# %d4.b set to 0xFF if adding more sprites else 0x0 if this is the end of the sprite table
# returns with %d0 as the last sprite idx, next sprite should point to 0 or %d4+1
# send VDP address to VDP control before calling this
tileImgShow:

    move.w #5*8+128,%d1  | y
    swap %d1
    move.w #0b0000111100000000,%d1 | size,next
    addq.b #1,%d0 | current sprite index is in %d0
    move.b %d0,%d1
    
    # this is set before calling the routine
    # move.w #0b0010000100000001,%d2 | attr(plt 1),gfx 256=0x100
    swap %d2
    move.w #12*8+128,%d2 | x

    move.l #3, %d0 | 4 rows of tiles -1 dbra
    bra addFirstTile

addLastTile:
    # last tile in row
    # when we are done with the loop we have to set next to 0
    # so we skip this in the last iteration
    move.l %d1, (VDP_DATA)  | write long to VDP
    move.l %d2, (VDP_DATA)  | write long to VDP

    # first tile in row
    add.l #0x00200001, %d1 | y+=32, next tile (next+=1)
    add.l #0x00100000, %d2 | next gfx, gfx += 0x10
    move.w #12*8+128,%d2 | inital x

addFirstTile:
    # add the first sprite to the vdp, the inital first is special
    move.l %d1, (VDP_DATA)  | write long to VDP
    move.l %d2, (VDP_DATA)  | write long to VDP

    add.b #1, %d1 | next sprite
    add.l #0x00100020,%d2 | next gfx, gfx += 0x10, x += 32 
    move.l %d1, (VDP_DATA)
    move.l %d2, (VDP_DATA)
    
    add.b #1, %d1
    add.l #0x00100020,%d2
    move.l %d1, (VDP_DATA)
    move.l %d2, (VDP_DATA)

    #last sprite in row
    add.b #1, %d1 | point to next sprite
    add.l #0x00100020,%d2 | next gfx, gfx += 0x10, x += 32 

    dbra.w %d0, addLastTile

# last tile in spritetable
    and.b %d4, %d1 | next sprite is 0 (last sprite) or next sprite d4= 0b1111 else ( d4=0000 )
    move.l %d1, (VDP_DATA)
    move.l %d2, (VDP_DATA)
    move.b %d1, %d0
    rts



# addr_plane_write in %d5
# first tile in %d0

imgShow:
    # cursor_x (start)
    move.l #12,%d1
    # cursor_y
    move.l #5,%d2

    # nrows -1
    move.l #15, %d3
nextRow:
    move.l %a1,%d5 | addr_plane address
    # move cursor_y to d4
    move.l %d2, %d4
    swap %d4
    rol.l #7, %d4
    add.l %d4, %d5

    # move cursor_x to d4
    move.b %d1, %d4
    swap %d4
    rol.l #1, %d4
    add.l %d4, %d5
    move.l %d5, (VDP_CONTROL)


    # ncols -1
    move.l #15, %d6
imshow_lp:
        move.w %d0, (VDP_DATA)
        addq #1, %d0 | next tile
        dbra %d6, imshow_lp

    addq #1, %d2 | increment y
    dbra %d3, nextRow
    rts


.set loop_counter, 2048*4-1  | 4 planes, number of bytes / 4 (long writes) - 1 for dbra (row is 1 long, tile is 8 rows)

imgInit:
	# Start writes to address zero 
	move.l #0x40200000, VDP_CONTROL  | set_vram_write 0x4 (vram_addr_tiles)
	move.l 	#loop_counter, %d0
_lp_imgInit:
	move.l	(%a0)+, (VDP_DATA)	| write long to VDP
	dbra    %d0, _lp_imgInit
	rts


#==============================================================
# PALETTE
#==============================================================
# Each colour is in binary format 0000 BBB0 GGG0 RRR0
# The bottom bit is discarded, can only use even values
# (0,2,4,6,8,A,C,E). So 0x0000 is black, 0x0EEE is white
# 0x000E is red, 0x00E0 is green, and 0x0E00 is blue.
#==============================================================
writePallete:
    move.l #vdp_cmd_cram_write, VDP_CONTROL  | set_cram_write $0000
    move.w #64-1, %d0     | 8 words in palette, 4 palettes (8*4 -1 for DBRA loop)
_lp:
    move.w (%a0)+, VDP_DATA
    dbra %d0, _lp
    rts

