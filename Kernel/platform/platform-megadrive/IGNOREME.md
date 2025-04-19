# TODO2
- [] Check if we can get termcap and or curses to work.
- [] Rewisit ram issues.
- [] How to best configure the rom/ram disk, configuration for cartridge?
- [] Create library to communicate with the vdp 'vdpcmd set background #0x0RGB' make it FORTH

# using ucp
	echo "cd root" > ucp.cmd
	echo "get Applications/tapp tapp" >> ucp.cmd
	echo "chmod 777 tapp" >> ucp.cmd
	$(FUZIX_ROOT)/Standalone/ucp -X $(FUZIX_ROOT)/Images/megadrive/filesystem2.sram < ucp.cmd

# Application notes
To build levee-vt52; we need to add -Wno-implicit-int -Wno-return-type to the gcc flags.
I unwisely modified Makefile.common directly.
In levee.h set LINES to VT_HEIGHT [28], and COLS to VT_WIDTH [40].
There is no way configure it easily, cols is hard coded.

# Notes
Creating vdp device:
- implement open, write, ioctl
- add device to device table in devices.c (packed to 8 for some reason)
- mknod in the file system (character device major 8 minor 0 -> 8*256 = 2048)
  in filesystem.pkg `n /dev/vdp 20660 2048` (permission = 660)
- I really should clean up register usage in some assembly routines

when we write to /dev/vdp, we get in kernel driver:
minor - indicates the minor number from 0-255 of the device being accessed.
flag - holds the persistent subset of flags passed on open. Notably this
includes O_NDELAY indicating that an error should be returned if the I/O
cannot be completed reasonably quickly.
rawflag - indicates the mode of access:
For character devicesthe raw flag will always be 1 (character I/O). 
(For block devices it may be 0 (Block I/O) or 2 (Swap)).

The data is contained in the udata structure:
udata.u_base - pointer to the data
udata.u_count - the number of bytes

The ioctl interface provides a generic interface for out of band control or
requests that do not fit a read/write mechanism. Some ioctls are generic
whilst others may be defined by a particular device or class of device.

    int ioctl(uint_fast8_t minor, uarg_t request, char *data);
a generic prototype is in Library/include/syscalls.h that can be included in user space apps

if the terminal ends up broken, not echoing characters for examply try:
stty sane

~~executables seem to work if I put them in rc, so there must be something wrong in platform (i/o) interrupt code?~~

~~It seems syscalls from userspace are not handled correctly!~~

~~We're getting panic("share") when running touch file.
touch does not hit panic("share") anymore,
ps causes floating point exception.~~

~~Running fsck messes up the system, most apps and utilities crash.~~
~~crt0.o is added to the file system in ./Library/libs/fuzix-libs.pkg, I thought it was just a bootloader?~~

	; C will save and restore a2+/d2+,
	; we can make sure to do the same in our asm routines,
    ; then we can movem.l a0-a1/a5/d0-d1,-(sp)

# C abi that seems to match gcc
https://m680x0.github.io/doc/abi.html
An integral return value is put in %d0, whereas a pointer return value is put in %a0.
When it comes to returning an aggregate-type object, the object should be stored in memory and its address will be put in %a1.
arguments are put on the stack in 4 byte bounderies.

# TODO
- [x] imshow app and a vdp device driver, image convert python script
- [x] Cursor sprite, also tried using shadow/highlight for cursor but it didnt look good.
- [] Fix interrupt handling in megadrive.S.
- [] Interrupt handling in Kernel/cpu-68000/lowlevel-68000.S:784 seems it needs fixing. 
- [x] make filesystem writeable
- [x] check implement a rom disk to load the kernel from; whatever that means
- [x] Check if backspace can be implemented; return ascii for backspace to tty
- [x] Switch to fuzix based VT; I have a feeling that the old code was significantly less complex and faster.
- [x] Fuzix has an 8x8 font
- [x] ...and some keyboard handling
- [x] implement outchar for Kernel/cpu-68000/lowlevel-68000.S debug routines
- [] add a suitable monitor which we can fall back to for debugging (plt_monitor)

## non-working apps
- ~~mount: causes Bus error~~
    this now causes I/O error, but seems to work
- ~~touch~~
- ~~fsck~~
- v7-games

# It's writeable
Blastem requires that the writeable portion of the cartridge address space is specified in the rom header (as sram in our use-case).
It does not like having the rom overlap the sram addresses. Therefore, to write to that space outside of blastem, we need to create the .sram file.
This took me ages to figure out; the .sram file is stored in 16-bit little-endian (byte-swapped) compared to the 68k. To fix that I naively just removed the -X flag to build-filesystem-ng which makes it into a little-endian filesystem. Obviously (in retrospect) this has no effect on the binaries put into the filesystem. So, while the kernel is able to read the filesystem all of the files are jumbled up.
The solution is to pass a regular big-endian blob through dd with swab (byte-swap) to create the .sram.


# It boots!!!
Needed to add few important things to the config:
Maybe this: who knows:
/* This is important for some reason*/
#define CONFIG_SPLIT_ID
#define CONFIG_PARENT_FIRST

Then fsck was messed up, so that needed to be removed from etc-files/rc

The blastem emulator seems to only supports writing to the cartridge address space if we set it as sram in the rom header.
I think it is only supported for the top 2MB.
We implement a rom disk in the bottom 2MB and ram disk in the top 2MB.


# Interrupts
Fuzix uses the mask defined in kernel.def to enable or disable interupts.  
Normally on the mega drive we use:
sr:
T | 0 | S | 0 | 0 | IPM2 | IPM1| IPM0 | 0 | 0 | 0 | X | N | Z | V | C

```
move    #$2700,sr    ; Disable interrupts.
move    #$2300,sr    ; Enable interrupts.
```
However, for Fuzix we are using
```
0x2700 = Supervisor mode, all interrupts
0x0000 = User mode, all interrupts
```

> In the case of the Genesis, IRQ2 is assigned to the external interrupt, IRQ4 is assigned to the horizontal blank interrupt, and IRQ6 is assigned to the vertical blank interrupt. Setting the IPL bits to 3 basically just has external interrupt requests ignored, since it falls in range of IRQ1-3. You would wanna set the IPL bits to 0 or 1 if you wanna use external interrupts.
<https://forums.sonicretro.org/index.php?threads/enabling-and-disabling-interrupts-the-why.42650/>


# syscalls
maybe something is off in mm?
../../lib/68000flat.S
../../flat.o 
../../usermem.c


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

