#include "../control_ports.def"

.include "macros.S"
    .section .data
    .globl shift_is_down, scancode_buffer

# 12 nibbles stored in the lower nibble of the bytes (the more significant nibble is $0)
scancode_buffer: .space 12 
shift_is_down: .space 1  | keep track of if shift is held down
ctrl_is_down: .space 1  | keep track of if ctrl is held down

    .section .text
    .globl initKeyboard, ReadKeyboard, readKey

#==============================================================
# Initialize keyboard
#==============================================================
# https://www.plutiedev.com/saturn-keyboard
# blastem 6.2 has saturn keyboard emulation,
# it should be connected to controller port 2
# press right ctrl for blastem to capture keystrokes
#
# The z80 doesn't need to be running, yet.
initKeyboard:
    FastPauseZ80
    move.b  #0x60, (IO_CTRL2)
    move.b  #0x60, (IO_DATA2)
    ResumeZ80

#==============================================================
# Read keyboard
#==============================================================
# Read a keyboard key into %d0.b, 0x00 if no character
# trashes %d1,%d4,%d5 %a0,%a1,%a4
    .even
readKey:
	jsr ReadKeyboard

	# check if succeeded
	cmp #0, %d0
	beq keyboardSuccess

	# failure; may be spurious data in top two bytes 
	clr.l %d0
	rts

keyboardSuccess:
    # nibble 7 of the scancode contains bits: make 1 1 break ($E make, $7 break)
	lea scancode_buffer, %a1 | could skip this in ReadKeyboard
	move.b 7(%a1), %d4

    # Assumes it is either or make or break scancode
    # could also just do not break, then no shift is needed
	and.b #0b1000, %d4   | extract make bit
	lsr #3, %d4          | shift it right to the 1 position
    # Now %d4 should be 1 if make, else 0

    # load scancode into %d5.b
	clr.l %d5            | %d5 is used to index (must be zero)
	move.b 8(%a1), %d5   | upper nibble of scancode
	rol.b #4, %d5
	or.b 9(%a1), %d5     | lower nibble of scancode

    # shift
	cmp.b #0x12, %d5     | left_shift
	beq set_shift
	cmp.b #0x59, %d5     | right_shift
	beq set_shift

	# ctrl
	cmp.b #0x14, %d5     | left_ctrl
	beq set_ctrl
	cmp.b #0x18, %d5     | right_ctrl
	beq set_ctrl

	bra not_ctrlkey

set_shift:
	move.b %d4, (shift_is_down)  | store it in address shift_is_down
	rts

set_ctrl:
	move.b %d4, (ctrl_is_down)  | store it in address ctrl_is_down
	rts

not_ctrlkey:
	cmp.b #0, %d4  | test if make bit is set
	bne _keyMake   | branch if make bit is set
	rts            | else return
_keyMake:
    # shifted (+$FF)
	lea scancode_ascii_table, %a4
	cmp.b #0, shift_is_down
	beq shiftUp
	add #0x0100, %a4
shiftUp:

    # the character we want is offset by the value of %d5 (ascii)
	move.b (%a4, %d5), %d0  | move the ascii to %d0
	
	# see tty.h, we and 0x1F to the character
	cmp.b #0, ctrl_is_down
	beq ctrlUp
	and.b #0x1F, %d0
ctrlUp:
	rts

# Routine for reading a keyboard packet
# Assumes it's in the second player port
#
# out %d0.w = 0 on success
#          = -1 on failure
# trashes %d1, %a0, %a1
ReadKeyboard:
	lea IO_DATA2, %a0
	lea scancode_buffer, %a1

    # Pause Z80 while we access the
    # I/O ports to avoid glitches
	FastPauseZ80

    # Initial step, also check
    # that it's indeed a keyboard
	move.b #0x20, (%a0)
	moveq #0x0F, %d0
	and.b (%a0), %d0
	cmp.b #0x01, %d0
	bne .LError

    # Now try reading every nibble
.set n_nibbles_m1, (12/2) - 1
	moveq #n_nibbles_m1, %d0
.LLoop:
    # Read a nibble
	move.b #0x00, (%a0)
	moveq #0x7F, %d1
.LWait1:
	btst #4, (%a0)
	beq.s .LDataOk1
	dbf %d1, .LWait1
	bra .LError
.LDataOk1:
	moveq #0x0F, %d1
	and.b (%a0), %d1
	move.b %d1, (%a1)+
    # Read another nibble
	move.b #0x20, (%a0)
	moveq #0x7F, %d1
.LWait2:
	btst #4, (%a0)
	bne.s .LDataOk2
	dbf %d1, .LWait2
	bra .LError
.LDataOk2:
	moveq #0x0F, %d1
	and.b (%a0), %d1
	move.b %d1, (%a1)+

    # Onto next pair
	dbf %d0, .LLoop
    
    # Let keyboard and Z80 idle
	move.b #0x60, (%a0)
	ResumeZ80
    # Return success!
	moveq #0, %d0
	rts

.LError:
    # Let keyboard and Z80 idle
	move.b #0x60, (%a0)
	ResumeZ80
    # Return failure...
	moveq #-1, %d0
	rts

#==============================================================
# Data
#==============================================================
    .section .rodata
    .globl scancode_ascii_table
scancode_ascii_table:
	.incbin "data/saturn_ascii_table.blob"
