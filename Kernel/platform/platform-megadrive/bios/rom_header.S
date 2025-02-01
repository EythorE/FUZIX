#include "../control_ports.def"
#include "../../cpu-68000/kernel-68000.def"
 
    .section .rom_header, "ax", @progbits

#==============================================================
# CPU VECTOR TABLE
#==============================================================
# A table of addresses that the CPU needs to know about -
# things like stack address, "main()" function address,
# vertical/horizontal interrupt addresses, etc.
#==============================================================
# For any interrupts we don't want to handle in this demo,
# we specify INT_Null (an interrupt at the bottom of the
# file that doesn't do anything).
#==============================================================
# This must be the very first thing in the ROM, since the CPU
# reads it from 0x0000 on bootup.
#==============================================================
.set udata_block_end, udata_block + UBLOCK_SIZE
	.long   udata_block_end			| Initial stack pointer value
	.long   CPU_EntryPoint		| Start of program
	.long   CPU_Exception 		| Bus error
	.long   CPU_Exception 		| Address error

	.long   CPU_Exception 		| Illegal instruction
	.long   CPU_Exception 		| Division by zero
	.long   CPU_Exception 		| CHK CPU_Exception
	.long   CPU_Exception 		| TRAPV CPU_Exception

	.long   CPU_Exception 		| Privilege violation
	.long   INT_Null				| TRACE exception
	.long   INT_Null				| Line-A emulator
	.long   INT_Null				| Line-F emulator

	.long   INT_Null				| Unused (reserved)
	.long   INT_Null				| Unused (reserved)
	.long   INT_Null				| Unused (reserved)
	.long   INT_Null				| Unused (reserved)

	| 16-23 unused
	.long   INT_Null				| Unused (reserved)
	.long   INT_Null				| Unused (reserved)
	.long   INT_Null				| Unused (reserved)
	.long   INT_Null				| Unused (reserved)
	.long   INT_Null				| Unused (reserved)
	.long   INT_Null				| Unused (reserved)
	.long   INT_Null				| Unused (reserved)
	.long   INT_Null				| Unused (reserved)

	| 24
	.long   INT_Null				| Spurious exception
	.long   INT_Null				| IRQ level 1
	.long   INT_Null				| IRQ level 2
	.long   INT_Null				| IRQ level 3
	.long   INT_HInterrupt		| IRQ level 4 (horizontal retrace interrupt)
	.long   INT_Null  			| IRQ level 5
	.long   INT_VInterrupt		| IRQ level 6 (vertical retrace interrupt)
	.long   INT_Null				| IRQ level 7

	| 32 - TRAP #n
	.long   INT_Null				| TRAP #00 exception
	.long   INT_Null				| TRAP #01 exception
	.long   INT_Null				| TRAP #02 exception
	.long   INT_Null				| TRAP #03 exception
	.long   INT_Null				| TRAP #04 exception
	.long   INT_Null				| TRAP #05 exception
	.long   INT_Null				| TRAP #06 exception
	.long   INT_Null				| TRAP #07 exception
	.long   INT_Null				| TRAP #08 exception
	.long   INT_Null				| TRAP #09 exception
	.long   INT_Null				| TRAP #10 exception
	.long   INT_Null				| TRAP #11 exception
	.long   INT_Null				| TRAP #12 exception
	.long   INT_Null				| TRAP #13 exception
	.long   INT_Null				| TRAP #14 exception
	.long   INT_Null				| TRAP #15 exception

	| unused
	.long   INT_Null				| Unused (reserved)
	.long   INT_Null				| Unused (reserved)
	.long   INT_Null				| Unused (reserved)
	.long   INT_Null				| Unused (reserved)
	.long   INT_Null				| Unused (reserved)
	.long   INT_Null				| Unused (reserved)
	.long   INT_Null				| Unused (reserved)
	.long   INT_Null				| Unused (reserved)
	.long   INT_Null				| Unused (reserved)
	.long   INT_Null				| Unused (reserved)
	.long   INT_Null				| Unused (reserved)
	.long   INT_Null				| Unused (reserved)
	.long   INT_Null				| Unused (reserved)
	.long   INT_Null				| Unused (reserved)
	.long   INT_Null				| Unused (reserved)
	.long   INT_Null				| Unused (reserved)
	
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
.set rom_end_address, _ROM_End - 1
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
	.long _ROM_Start             | Start address of ROM
	.long rom_end_address        | End address of ROM
	.long 0x00FF0000             | Start address of RAM
	.long 0x00FFFFFF             | End address of RAM
	.long 0x00000000             | SRAM enabled
	.long 0x00000000             | Unused
	.long 0x00000000             | Start address of SRAM
	.long 0x00000000             | End address of SRAM
	.long 0x00000000             | Unused
	.long 0x00000000             | Unused
	.ascii "                                        " | Notes (unused)
	.ascii "  E             "    | Country codes

#==============================================================
# Initialise the Mega Drive
#==============================================================
    .section .text
    .globl CPU_EntryPoint, CPU_Exception, INT_VInterrupt, INT_HInterrupt, INT_Null


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
	move.w #0x2300,%sr

	#==============================================================
	#  Write color pallete to cram
	#==============================================================
	jsr VDP_writePallete

	#==============================================================
	# Write the font tiles to VRAM
	#==============================================================
	jsr fontInit

    jsr initKeyboard  

    jmp _start



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
	rte

# Horizontal interrupt - run once per N scanlines (N = specified in VDP register $A)
INT_HInterrupt:
	rte

# NULL interrupt - for interrupts we don't care about
INT_Null:
	rte

# Exception interrupt - called if an error has occured
CPU_Exception:
	# Just halt the CPU if an error occurred. Later on, we may want to write
	# an exception handler to draw the current state of the machine to screen
	# (registers, stack, error type, etc) to help debug the problem.
	stop   #0x2700
	rte
