CSRCS = devtty.c devices.c libc.c main.c devrd.c dbg.c
COBJS = $(CSRCS:.c=$(BINEXT))

BSRC = $(wildcard bios/*.S)
BOBJS = $(patsubst bios/%.S,%.o, $(BSRC))

ASRCS = crt0.S tricks.S megadrive.S devvt.S
AOBJS = $(ASRCS:.S=.o)

# DSRCS = ../../dev/devrd.c
# DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))

LSRCS = ../../lib/68000exception.c ../../lib/68000usercopy.c ../../lib/68000relocate.c
LOBJS = $(patsubst ../../lib/%.c,%.o, $(LSRCS))

OBJS  = $(COBJS) $(AOBJS) $(BOBJS) $(DOBJS) $(LOBJS)

CROSS_CCOPTS += -I../../dev/

all: $(OBJS)

$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) $<

$(BOBJS): %.o: bios/%.S
	$(CROSS_AS) $(ASOPTS) $< -o $@
	
$(DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $< -o $@

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $<

$(DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $<

$(LOBJS): %.o: ../../lib/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $<

tricks.S: ../../lib/68000flat.S

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)
PKG2 = $(FUZIX_ROOT)/Kernel/platform/platform-megadrive/fuzix-platform-megadrive2.pkg

clean:
	rm -rf $(FUZIX_ROOT)/Library/libs/crt0_68000.s
	rm -rf $(FUZIX_ROOT)/Library/libs/crt0nostdio_68000.s
	rm -rf $(FUZIX_ROOT)/Library/libs/setjmp_68000.s
	rm -rf $(FUZIX_ROOT)/Standalone/filesystem-src/etc-files/issue
	rm -rf $(FUZIX_ROOT)/Applications/V7/cmd/sh/fshbuild_*
	rm -rf $(IMAGES)

	rm -f bios/*.o *.o fuzix.elf loader.elf loader.map loader.bin core *~ 
	rm -f fuzix.rom
	(cd Applications; $(MAKE) clean)

image: fuzix.ld $(AOBJS) $(BOBJS)  main.o devtty.o kernel.def ../../cpu-68000/lowlevel-68000.o ../../flat.o
	$(CROSS_LD) -M -o fuzix.elf -T fuzix.ld $(AOBJS) $(BOBJS) devrd.o main.o devtty.o dbg.o \
	../../vt.o ../../start.o ../../version.o ../../cpu-68000/lowlevel-68000.o \
	../../timer.o ../../kdata.o 68000exception.o devices.o \
	../../devio.o ../../filesys.o ../../process.o ../../inode.o ../../syscall_fs.o \
	../../syscall_proc.o ../../syscall_other.o ../../mm.o ../../flat.o \
	../../blk512.o ../../tty.o ../../devsys.o ../../usermem.o ../../syscall_fs2.o \
	../../syscall_fs3.o ../../syscall_exec32.o ../../syscall_exec.o \
	68000usercopy.o ../../cpu-68000/usermem_std-68000.o libc.o ../../malloc.o \
	68000relocate.o \
	../../level2.o ../../syscall_level2.o ../../select.o > ../../fuzix.map
	$(CROSS_COMPILE)objcopy fuzix.elf -O binary ../../fuzix.bin


#	$(CROSS_LD) -M -o fuzix.elf -T fuzix.ld \
#	68knano.o ../../start.o ../../version.o ../../cpu-68000/lowlevel-68000.o \
#	tricks.o main.o ../../timer.o ../../kdata.o 68000exception.o devices.o \
#	../../devio.o ../../filesys.o ../../process.o ../../inode.o ../../syscall_fs.o \
#	../../syscall_proc.o ../../syscall_other.o ../../mm.o ../../flat.o \
#	../../blk512.o ../../tty.o ../../devsys.o ../../usermem.o ../../syscall_fs2.o \
#	../../syscall_fs3.o ../../syscall_exec32.o ../../syscall_exec.o \
#	ds3234.o blkdev.o devide.o devide_discard.o mbr.o \
#	68000usercopy.o ../../cpu-68000/usermem_std-68000.o devtty.o libc.o ../../malloc.o \
#	68000relocate.o \
#	../../level2.o ../../syscall_level2.o ../../select.o > ../../fuzix.map





# 4096*512b blocks = 2MB
diskimage:
	(cd Applications; $(MAKE))
	cp ../../fuzix.bin $(IMAGES)/fuzix.rom
	(cd $(FUZIX_ROOT)/Standalone/filesystem-src; ./build-filesystem-ng -X -f $(IMAGES)/filesystem.img -g 64 3968 -p platform-megadrive)
	dd if=$(IMAGES)/filesystem.img of=$(IMAGES)/fuzix.rom bs=64K seek=1 conv=notrunc
	
	# Filesystem 2
	(cd $(FUZIX_ROOT)/Standalone/filesystem-src; ./build-filesystem-ng -X -f $(IMAGES)/filesystem2.img -g 64 3072 -p platform-megadrive-disk2)
		@echo "cd root" > ucp.cmd
	@echo "get Applications/tapp tapp" >> ucp.cmd
	@echo "chmod 777 tapp" >> ucp.cmd
	$(FUZIX_ROOT)/Standalone/ucp $(FUZIX_ROOT)/Images/megadrive/filesystem2.img < ucp.cmd
	@rm ucp.cmd
# $(FUZIX_ROOT)/Standalone/ucp $(FUZIX_ROOT)/Images/megadrive/filesystem2.img 'cd root; get Applications/tapp tapp; chmod 777 tapp'
	# Blastem does not like to have data in the rom binary in the address space of sram
	rm -f /home/eythor/.local/share/blastem/fuzix/save.sram
	# .sram is saved in 16-bit little-endian format (byte-swapped)!!
	dd if=$(IMAGES)/filesystem2.img of=/home/eythor/.local/share/blastem/fuzix/save.sram bs=1536K conv=notrunc,swab
