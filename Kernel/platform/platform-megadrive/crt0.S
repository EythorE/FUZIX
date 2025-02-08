#include "control_ports.def"
#include "../cpu-68000/kernel-68000.def"

	.globl __end
	.globl __bss_start
	.globl start
	.globl  cpu_type

.section .rom_header, "ax", @progbits
#==============================================================
# CPU VECTOR TABLE
#==============================================================
# This must be the very first thing in the ROM, since the CPU
# reads it from 0x0000 on bootup.
#==============================================================
.set udata_block_end, udata_block + UBLOCK_SIZE
 	.long   0xFFF000			| Initial stack pointer value
	.long   CPU_EntryPoint			| Start of program
	.long   e_bus_error 			| Bus error
	.long   e_addr_error 			| Address error

	.long   e_illegal				| Division by zero
	.long   e_divzero				| Illegal instruction
	.long   e_chk					| CHK CPU_Exception
	.long   e_trapv					| TRAPV CPU_Exception

	.long   e_priv					| Privilege violation
	.long   e_trace				| TRACE exception
	.long   e_unimpa				| Line-A emulator
	.long   e_unimpf				| Line-F emulator

	.long   e_unexpected				| Unused (reserved)
	.long   e_unexpected				| Unused (reserved)
	.long   e_unexpected				| Unused (reserved)
	.long   e_uninit				| Unused (reserved)

	| 16-23 unused
	.long   e_unexpected				| Unused (reserved)
	.long   e_unexpected				| Unused (reserved)
	.long   e_unexpected				| Unused (reserved)
	.long   e_unexpected				| Unused (reserved)
	.long   e_unexpected				| Unused (reserved)
	.long   e_unexpected				| Unused (reserved)
	.long   e_unexpected				| Unused (reserved)
	.long   e_unexpected				| Unused (reserved)

	| 24
	.long   e_spurious				| Spurious exception
	.long   interrupt				| IRQ level 1
	.long   e_unexpected				| IRQ level 2
	.long   e_unexpected				| IRQ level 3
	.long   INT_HInterrupt		| IRQ level 4 (horizontal retrace interrupt)
	.long   e_unexpected  			| IRQ level 5
	.long   INT_VInterrupt		| IRQ level 6 (vertical retrace interrupt)
	.long   e_unexpected				| IRQ level 7

	| 32 - TRAP #n
	.long   e_trap0				| TRAP #00 exception
	.long   e_trap1				| TRAP #01 exception
	.long   e_trap2				| TRAP #02 exception
	.long   e_trap3				| TRAP #03 exception
	.long   e_trap4				| TRAP #04 exception
	.long   e_trap5				| TRAP #05 exception
	.long   e_trap6				| TRAP #06 exception
	.long   e_trap7				| TRAP #07 exception
	.long   e_trap8				| TRAP #08 exception
	.long   e_trap9				| TRAP #09 exception
	.long   e_trap10				| TRAP #10 exception
	.long   e_trap11				| TRAP #11 exception
	.long   e_trap12				| TRAP #12 exception System call
	.long   e_trap13				| TRAP #13 exception
	.long   e_trap14				| TRAP #14 exception
	.long   e_trap15				| TRAP #15 exception

	| unused
	.long   e_unexpected				| Unused (reserved)
	.long   e_unexpected				| Unused (reserved)
	.long   e_unexpected				| Unused (reserved)
	.long   e_unexpected				| Unused (reserved)
	.long   e_unexpected				| Unused (reserved)
	.long   e_unexpected				| Unused (reserved)
	.long   e_unexpected				| Unused (reserved)
	.long   e_unexpected				| Unused (reserved)
	.long   e_unexpected				| Unused (reserved)
	.long   e_unexpected				| Unused (reserved)
	.long   e_unexpected				| Unused (reserved)
	.long   e_unexpected				| Unused (reserved)
	.long   e_unexpected				| Unused (reserved)
	.long   e_unexpected				| Unused (reserved)
	.long   e_unexpected				| Unused (reserved)
	.long   e_unexpected				| Unused (reserved)
	
#==============================================================
# SEGA MEGA DRIVE ROM HEADER
#==============================================================
# A structure that specifies some metadata about the ROM, like
# its name, author, version number, release date, region,
# and any special peripherals used.
# Note that the Mega Drive console itself doesn't read any of
# this, it's more a convenience for the programmer, but
# most emulators will read the title and region.
#==============================================================
# If your emulator doesn't show the correct ROM name, then this
# table is in the wrong place or in the wrong format.
#==============================================================
	.ascii "SEGA MEGA DRIVE "    | Console name
	.ascii "eythore         "    | Copyright holder and release date
	.ascii "WozMon          "	 | 0x120 48 bytes | Game title (domestic)
	.ascii "                "
	.ascii "                " 
	.ascii "WozMon          "	 | 0x150 48 bytes | Game title (overseas)
	.ascii "                "
	.ascii "                " 
	.ascii "GM XXXXXXXX-XX"      | Version number
	.word 0x0000                 | Checksum
	.ascii "J               "    | I/O support
	.long 0x00000000            | Start address of ROM
	.long 0x002FFFFF            | End address of ROM
	.long 0x00300000             | Start address of RAM
	.long 0x003FFFFF             | End address of RAM
	.ascii "RA"                  | SRAM enabled
	.byte 0xE0
	.byte 0x20
	.long 0x00300000             | Start address of SRAM
	.long 0x003FFFFF             | End address of SRAM
	.long 0x00000000             | 12 bytes	Modem support
	.long 0x00000000             | \
	.long 0x00000000             | \
	.ascii "                                        " | (reserved, fill with spaces)
	.ascii "  E             "    | 3 bytes	Region support 13 bytes	(reserved, fill with spaces)


    .section .text
    .globl CPU_EntryPoint, INT_VInterrupt, INT_HInterrupt, _plt_interrupt
#==============================================================
# INTERRUPT ROUTINES
#==============================================================
# The interrupt routines, as specified in the vector table in
# the rom_header.
# Note that we use RTE to return from an interrupt, not
# RTS like a subroutine.
#==============================================================

# Vertical interrupt - run once per frame
INT_VInterrupt:
    movem.l %d0-%d7/%a0-%a6,-(%sp)    | Save registers
    jsr     plt_interrupt             | Call C handler
    movem.l (%sp)+,%d0-%d7/%a0-%a6    | Restore registers
	rte

# Horizontal interrupt - run once per N scanlines (N = specified in VDP register $A)
INT_HInterrupt:
	rte

# # Exception interrupt - called if an error has occured
# CPU_Exception:
#	# Just halt the CPU if an error occurred. Later on, we may want to write
#	# an exception handler to draw the current state of the machine to screen
#	# (registers, stack, error type, etc) to help debug the problem.
#	stop   #0x2700
#	rte

#==============================================================
# Initialise the Mega Drive
#==============================================================

CPU_EntryPoint:
	#==============================================================
	# Initialise the Mega Drive
	#==============================================================



	# Write the TMSS signature (if a model 1+ Mega Drive)
	jsr    VDP_WriteTMSS

	# Load the initial VDP registers
	jsr    VDP_LoadRegisters

	jsr VDP_ClearVRAM
	
	#==============================================================
	# Initialise status register and set interrupt level.
	# This begins firing vertical and horizontal interrupts.
	#==============================================================
	move.w #0x2700,%sr
	# Move data from .data to .bss
	#jsr init_data

	#==============================================================
	#  Write color pallete to cram
	#==============================================================
	jsr VDP_writePallete

	#==============================================================
	# Write the font tiles to VRAM
	#==============================================================
	jsr fontInit

    jsr initKeyboard



start:
	jsr init_data


	move.l   udata_block_end,%sp
		bsr init_early
		bsr init_hardware
		bsr fuzix_main
		or #0x0700,%sr
stop:		bra stop

cpu_type:
        moveq #0,%d0 | 68000
        move.b %d0,cpu_has_trapvec
        rts

#==============================================================
# DATA INITIALIZATION ROUTINE
#==============================================================
# Initializes the data section by copying from ROM to RAM and
# clears the BSS section. Must be called before accessing any
# variables.
#
# Copies data from _data_load in ROM to _data_start in RAM,
# copying until _data_end.
# Then clears BSS section from _bss_start to _bss_end
#
# Trashes: %a0, %a1, %d0
#==============================================================
init_data:
        move.l  #_data_load, %a0         | Source address in ROM
        move.l  #_data_start, %a1        | Destination address in RAM
        move.l  #_data_end, %d0
        sub.l   #_data_start, %d0        | Calculate size
        beq.s   .Ldata_done              | Skip if no data to copy

.Lcopy_loop:
        move.b  (%a0)+, (%a1)+          | Copy byte and increment pointers
        subq.l  #1, %d0                 | Decrement counter
        bne.s   .Lcopy_loop             | Continue if not done

.Ldata_done:
        # Clear BSS
        move.l  #_bss_start, %a0        | Start of BSS
        move.l  #_bss_end, %d0          
        sub.l   #_bss_start, %d0        | Calculate BSS size
        beq.s   .Lbss_done              | Skip if no BSS to clear

.Lclear_loop:
        clr.b   (%a0)+                  | Clear byte and increment pointer
        subq.l  #1, %d0                 | Decrement counter
        bne.s   .Lclear_loop

.Lbss_done:
        rts