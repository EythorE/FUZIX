
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
		.globl plt_timer_interrupt

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


plt_timer_interrupt:
    move.w  sr,d0            ; Get status register into d0
    and.w   #DI_MASK,d0      ; Mask off all but interrupt bits
    bne     .skip            ; If any interrupt bits set, skip timer
    jsr     timer_interrupt  ; Call timer if interrupts enabled
.skip:
    rts 


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

interrupt:
	pea test_message
	jsr kprintf
	addq.l #4,sp
	    ; C will save and restore a2+/d2+
	    movem.l a0-a1/a5/d0-d1,-(sp)
	    move.l udata_shadow,a5	; set up the register global
	    move.b #1,U_DATA__U_ININTERRUPT(a5)
	    jsr plt_interrupt
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
	    movem.l (sp)+,a0-a1/a5/d0-d1
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
	    movem.l (sp)+,a0-a1/a5/d0-d1
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


; outchar: Wait for UART TX idle, then print the char in d0

outchar:
outcharw:
	; TODO
	rts
;