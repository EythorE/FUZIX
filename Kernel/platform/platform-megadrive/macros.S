#==============================================================
# VRAM WRITE MACROS
#==============================================================
# Some utility macros to help generate addresses and commands for
# writing data to video memory, since they're tricky (and
# error prone) to calculate manually.
# The resulting command and address is written to the VDP's
# control port, ready to accept data in the data port.
#==============================================================
#    
## Set the VRAM (video RAM) address to write to next
#    macro set_vram_write
#        move.l #(vdp_cmd_vram_write)|((\1)&$3FFF)<<16|(\1)>>14,vdp_control
#    endm
## Set the CRAM (colour RAM) address to write to next
#    macro set_cram_write
#        move.l #(vdp_cmd_cram_write)|((\1)&$3FFF)<<16|(\1)>>14,vdp_control
#    endm
## Set the VSRAM (vertical scroll RAM) address to write to next
#    macro set_vsram_write
#        move.l #(vdp_cmd_vsram_write)|((\1)&$3FFF)<<16|(\1)>>14,vdp_control
#    endm

#==============================================================
# Z80 MACROS
#==============================================================
# We can't access Z80 RAM while it's running, but we can request
# its bus (which will pause the Z80). Note that depending what
# the Z80 is doing, it may take a bit until the bus is free.
# So once you write $100 to Z80BusReq, you need to keep
# reading back from it until it also returns $100
# (at which point the Z80 has let go of the bus).
#==============================================================
# We are not using the z80
.equ Z80Ram, 0xA00000  | Where Z80 RAM starts
.equ Z80BusReq, 0xA11100  | Z80 bus request line
.equ Z80Reset, 0xA11200  | Z80 reset line

    .macro PauseZ80
        move.w  #0x100, (Z80BusReq)
    .endm
    .macro WaitZ80
        btst    #0, (Z80BusReq)
        bne.s   wait_z80
    .endm
    .macro FastPauseZ80
        move.w  #0x100, (Z80BusReq)
    .endm
    .macro ResumeZ80
        move.w  #0, (Z80BusReq)
    .endm
