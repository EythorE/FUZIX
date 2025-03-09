ctags:
```sh
ctags --exclude="Applications/*" --exclude="Kernel/platform/platform-*" --exclude="Kernel/cpu-*" \
      --languages=c,asm,make -R Kernel/
ctags -a --languages=c,asm,make -R Kernel/platform/platform-megadrive/ Kernel/cpu-68000/
```
	; C will save and restore a2+/d2+,
	; we can make sure to do the same in our asm routines,
    ; then we can movem.l a0-a1/a5/d0-d1,-(sp)


executables seem to work if I put them in rc, so there must be something wrong in platform (i/o) interrupt code?

F12 can debug the debug overlay on/off, provided by output.S

debug with blastem:
m68k-elf-gdb -q --tui -ex "target remote | blastem -D Images/megadrive/fuzix.rom"  Kernel/platform/platform-megadrive/fuzix.elf

It seems syscalls from userspace are not handled correctly!

We can use Standalone ucp to browse and manipulate a filesystem
```Standalone/ucp Images/megadrive/filesystem2.img```
Or for the byte-reversed .sram then use ucp -b

We can pass CI_TESTING=1 to make to skip the login.
make CI_TESTING=1 diskimage && blastem Images/megadrive/fuzix.rom

We're getting panic("share") when running touch file.
touch does not hit panic("share") anymore,
ps causes floating point exception.


Running fsck messes up the system, most apps and utilities crash.
crt0.o is added to the file system in ./Library/libs/fuzix-libs.pkg, I thought it was just a bootloader?


# C abi that seems to match gcc
https://m680x0.github.io/doc/abi.html
An integral return value is put in %d0, whereas a pointer return value is put in %a0.
When it comes to returning an aggregate-type object, the object should be stored in memory and its address will be put in %a1.
arguments are put on the stack in 4 byte bounderies.

# TODO
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
