
#include "../../cpu-68000/kernel-68000.def"
#include "kernel.def"

		.globl plt_reboot
		.globl init_early
		.globl init_hardware
		.globl program_vectors
		.globl interrupt
		.globl plt_idle
		.globl outchar
		.globl plt_monitor
		.globl INT_VInterrupt
		.globl INT_HInterrupt

	.section .rodata
monitor_message: .asciz "\nplt_monitor..."
test_message: .asciz "\nwe had an interupt...\n"
	.even

	.section .text
.mri 1
plt_monitor:
	pea monitor_message
	jsr kprintf
	addq.l #4,sp
	move.w #$2700,sr
	jmp start
loop:
	bra loop


plt_reboot:
	    or #$2700,sr
	    jmp start

init_early:
		lea.l udata_block,a5	; udata ptr
	   	move.l a5,udata_shadow	; shadow copy for entry/exit
        rts

plt_idle:
	    stop #($2000+EI_MASK)
	    rts

init_hardware:
	    move.w #512,ramsize
	    move.w #256,procmem
        rts


    
#==============================================================
# INTERRUPT ROUTINES
#==============================================================
# The interrupt routines, as specified in the vector table in
# the rom_header.
#==============================================================

# Horizontal interrupt - run once per N scanlines (N = specified in VDP register $A)
INT_HInterrupt:
	rte

# Vertical interrupt - run once per frame Pal 50hz, NTSC 60hz
INT_VInterrupt:
	; C will save and restore a2+/d2+,
	; we can make sure to do the same, then we can movem.l a0-a1/a5/d0-d1,-(sp)
    movem.l %d0-%d7/%a0-%a6,-(%sp)

	; Read keyboard
	jsr readKey ; trashes %d1,%d4,%d5 %a0,%a1,%a4
	tst.b %d0
	beq no_key
	; Push args for tty_inproc(1, k)
	and.l #$FF,%d0
    move.l %d0,-(sp)              ; Push k
    moveq #1,%d0
    move.l %d0,-(sp)              ; Push 1
    jsr tty_inproc
    addq.l #8,sp
no_key:

    ; jsr     timer_interrupt
    ;movem.l (%sp)+,%d0-%d7/%a0-%a6
	;rte



;interrupt: I need to understand what is going on here;
;
	; C will save and restore a2+/d2+
	; movem.l a0-a1/a5/d0-d1,-(sp)
	move.l udata_shadow,a5	; set up the register global
	move.b #1,U_DATA__U_ININTERRUPT(a5)
	jsr timer_interrupt
	clr.b U_DATA__U_ININTERRUPT(a5)

	tst.b U_DATA__U_INSYS(a5)
	bne no_preempt
	tst.b need_resched
	beq no_preempt
	;
	;	Vanish into the scheduler. Some other task will pop back out
	;   and eventually we'll re-appear here and continue.
	;
	;   FIXME: check IRQ masking
	;
	move.l U_DATA__U_PTAB(a5),a0
	; We might be in STOPPED state in which case do not go back
	; to ready !
	cmp.b #P_RUNNING,P_TAB__P_STATUS_OFFSET(a0)
	bne no_ready
	move.b #P_READY,P_TAB__P_STATUS_OFFSET(a0)
	ori.b #PFL_BATCH,P_TAB__P_FLAGS_OFFSET(a0)
no_ready:
	bsr switchout

no_preempt:
	tst.b U_DATA__U_CURSIG(a5)
	beq no_signal
	;   FIXME: this is ugly
	; movem.l (sp)+,a0-a1/a5/d0-d1
	movem.l (%sp)+,%d0-%d7/%a0-%a6
	move.w sr,-(sp)
	move.w #0,-(sp)
	movem.l a0-a6/d0-d7,-(sp)
	move.l (sp),-(sp)
	bsr exception
	addq #4,sp
	movem.l (sp)+,a0-a6/d0-d7
	addq #4,sp
	rte
no_signal:
	;movem.l (sp)+,a0-a1/a5/d0-d1
	movem.l (%sp)+,%d0-%d7/%a0-%a6
	rte

;
;	Nothing to do in 68000 - all set up once at link time
;
program_vectors:
	rts
;
;	We do no banking so we need to do nothing here.
;
map_process_always:
map_process:
map_kernel:
map_restore:
map_save:
	rts


; outchar: Print the char in d0
outchar:
outcharw:
	; TODO
	rts
;