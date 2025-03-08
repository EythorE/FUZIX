#include "control_ports.def"

.include "macros.S"
    .section .data
    .globl scancode_buffer

# 12 nibbles stored in the lower nibble of the bytes (the more significant nibble is $0)
scancode_buffer: .space 12 

    .section .text
    .globl initKeyboard, ReadKeyboard

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
