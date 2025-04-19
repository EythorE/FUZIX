ASRCS = crt0.S megadrive.S devvt.S keyboard_read.S dbg_output.S vdp.S
AOBJS = $(ASRCS:.S=.o)

CSRCS = devtty.c devices.c libc.c main.c devrd.c dbg.c keyboard.c devvdp.c
COBJS = $(CSRCS:.c=$(BINEXT))

# DSRCS = ../../dev/devrd.c
# DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))

LSRCS = ../../lib/68000exception.c ../../lib/68000usercopy.c ../../lib/68000relocate.c
LOBJS = $(patsubst ../../lib/%.c,%.o, $(LSRCS))

CPUOBJS = ../../cpu-68000/usermem_std-68000.o ../../cpu-68000/lowlevel-68000.o
KOBJS =	../../vt.o ../../start.o ../../version.o \
	../../timer.o ../../kdata.o \
	../../devio.o ../../filesys.o ../../process.o ../../inode.o ../../syscall_fs.o \
	../../syscall_proc.o ../../syscall_other.o ../../mm.o ../../flat.o \
	../../blk512.o ../../tty.o ../../devsys.o ../../usermem.o ../../syscall_fs2.o \
	../../syscall_fs3.o ../../syscall_exec32.o ../../syscall_exec.o \
	../../malloc.o \
	../../level2.o ../../syscall_level2.o ../../select.o

OBJS  = $(AOBJS) $(COBJS) $(DOBJS) $(LOBJS) 68000flat.o font8x8.o $(CPUOBJS) $(KOBJS)

CROSS_CCOPTS += -I../../dev/

all: $(OBJS)


$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) $< -o $@

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $< -o $@

$(DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $< -o $@

$(LOBJS): %.o: ../../lib/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $< -o $@


font8x8.o: ../../font/font8x8.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $< -o $@

68000flat.o: ../../lib/68000flat.S
	$(CROSS_AS) $(ASOPTS) $< -o $@


IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

clean:
	#levee patch
	-(patch --reverse -r - -f -p1 -d $(FUZIX_ROOT) < Applications/levee.patch)
	rm -f $(FUZIX_ROOT)/Applications/levee/*.orig

	# annoyingly not cleaned up
	rm -rf $(FUZIX_ROOT)/Library/libs/crt0_68000.s
	rm -rf $(FUZIX_ROOT)/Library/libs/crt0nostdio_68000.s
	rm -rf $(FUZIX_ROOT)/Library/libs/setjmp_68000.s
	rm -rf $(FUZIX_ROOT)/Standalone/filesystem-src/etc-files/issue
	rm -rf $(FUZIX_ROOT)/Applications/V7/cmd/sh/fshbuild_*
	rm -rf $(IMAGES)

	rm -f bios/*.o *.o fuzix.elf loader.elf loader.map loader.bin core *~ 
	rm -f fuzix.rom
	(cd Applications; $(MAKE) clean)

image: fuzix.ld $(OBJS)
	$(CROSS_LD) -M -o fuzix.elf -T fuzix.ld $(OBJS)  > ../../fuzix.map
	$(CROSS_COMPILE)objcopy fuzix.elf -O binary ../../fuzix.bin


# 4096*512b blocks = 2MB
diskimage:
	-(patch --forward -r - -f -p1 -d $(FUZIX_ROOT) < Applications/levee.patch)
	(cd $(FUZIX_ROOT)/Applications/levee; $(MAKE) -f Makefile.$(USERCPU) levee-vt52)

	(cd Applications; $(MAKE))

	cp ../../fuzix.bin $(IMAGES)/fuzix.rom
	# romdisk, baked into the ROM
	(cd $(FUZIX_ROOT)/Standalone/filesystem-src; ./build-filesystem-ng -X -f $(IMAGES)/filesystem.img -g 64 3968 -p platform-megadrive)
	dd if=$(IMAGES)/filesystem.img of=$(IMAGES)/fuzix.rom bs=64K seek=1 conv=notrunc
	

	# ramdisk, savefile
	(cd $(FUZIX_ROOT)/Standalone/filesystem-src; ./build-filesystem-ng -X -f $(IMAGES)/filesystem2.img -g 64 3072 -p platform-megadrive-disk2)

	# Blastem does not like to have data in the rom binary in the address space of sram
	rm -f $(IMAGES)/filesystem2.sram
	# .sram is saved in 16-bit little-endian format (byte-swapped)!!
	dd if=$(IMAGES)/filesystem2.img of=$(IMAGES)/filesystem2.sram bs=1536K conv=notrunc,swab
	cp $(IMAGES)/filesystem2.sram /home/$(USER)/.local/share/blastem/fuzix/save.sram
