maybe something is off in mm?


apps are entered through doexec in lowlevel-68000.S, the program is loaded correctly and the kernel is rte-ing to the correct place in user program.

plt_relocate in 68000relocate.c is getting the same addresses as _ececve in syscall_exec32.c is reporting.
We need to figure out a way to print udata for a program right before we jump to it.
We know the addresses.
I guess it's being relocated correctly.
So most likely the udata is correct. but it may have stray or incorrect data in it.
I guess the kernel is jumping (rte-ing) to the correct address.
We need to figure out:
Is the udata initialized correctly for programs that are failing.
Is the memory copied correctly to the data and code sections.

Note: it is hard to understand what is being compiled into the kernel, what is being compiled into user apps. And looking at the file structure; understanding what code and header files are for the kernel, init system and user apps.

Try and understand how the program loading works

udata
udata_shadow
defined in ??

udata_shadow contains

The boot runs okey. Few programs work when using the mega drives internal ram.
When the extra ram is not used the third program I run fails.

There is something of about the memory mapping or the program loading.


switchin is used to change running program, 

return from exception is used to enter dynamically loaded user programs.
-- this may be false -- it seems this rte is always going to the same address!!
In Kernel/lib/68000flat.S forkreturn is used to rte to the user program.
It contains on the stack 2 bytes for the status register then 4 bytes for the return address before calling rte.

http://wpage.unina.it/rcanonic/didattica/ce1/docs/68000.pdf
RTE - Return from Exception
Description: The status register and program counter are pulled from the stack.
The previous values of the SR and PC are lost. The RTE is used to
terminate an exception handler. Note that the behavior of the
RTE instruction depends on the nature of both the exception and
processor type. The 68010 and later models push more information on the stack following an exception than the 68000. The
processor determines how much to remove from the stack.

I need to figure out what no_preempt is doing in the megadrive interrupt.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
I suspect that it is returning to the correct address.
It always returns to the same address in userspace no matter the program (guessing config_multi is off in the config) It's Not!.

We can verify that the content in memory at the rte address is the same as the compiled binary. Need to find the start of the .data in the fuzix executable.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



sh calls _fork (Kernel/syscall_proc.c);
this calls dofork in Kernel/lib/68000flat.S, this copies the process udata to the childs udata (hardcoded to 1024 bytes),
and calls makeproc(regptr ptptr p, u_data *u) in Kernel/process.c with a0 as the child udata:
	move.l P_TAB__P_UDATA_OFFSET(a0),-(sp)
	move.l a0,-(sp)
    jsr makeproc
It then carries on copying some things on to the stack of the child process udata, sets its stack pointer accordingly, removes the syscall bit and returns with child process pid as a return value (in d0 (and in a2)) to _fork in syscall_proc.c.

This all looks reasonable and there is no hint of why it should not work for some addresses and while working with high ram (0xFF0000-0xFFFFFF).

the processes are not using close to the top half of the memblocks.

where do the udata structures live?
Kernel/platform/platform-megadrive/main.c:
// see mm/flat.c
/* Udata and kernel stacks */
/* We need an initial kernel stack and udata so the slot for init is
   set up at compile time */
u_block udata_block[PTABSIZE];

udata_shadow: is allocated in Kernel/cpu-68000/lowlevel-68000.S.
During switchin in 68000flat.S it is set to the udata (a5),
also during int pagemap_alloc(ptptr p) (Kernel/mm/flat.c) it is set:
#if defined udata
		udata_shadow = p->p_udata;
#endif




