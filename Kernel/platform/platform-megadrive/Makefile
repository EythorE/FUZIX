CSRCS = devtty.c devices.c libc.c main.c devrd.c
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

all:	$(OBJS)

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

clean:
	rm -f bios/*.o *.o fuzix.elf loader.elf loader.map loader.bin core *~ 
	rm -f fuzix.rom

image: fuzix.ld $(AOBJS) $(BOBJS)  main.o devtty.o kernel.def
	$(CROSS_LD) -M -o fuzix.elf -T fuzix.ld $(AOBJS) $(BOBJS) devrd.o main.o devtty.o \
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


IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)
PKG2 = $(FUZIX_ROOT)/Kernel/platform/platform-megadrive/fuzix-platform-megadrive2.pkg

# 4096*512b blocks = 2MB
diskimage:
	cp ../../fuzix.bin $(IMAGES)/fuzix.rom
	(cd $(FUZIX_ROOT)/Standalone/filesystem-src; ./build-filesystem-ng -X -f $(IMAGES)/filesystem.img -g 64 3968 -p platform-megadrive)
	dd if=$(IMAGES)/filesystem.img of=$(IMAGES)/fuzix.rom bs=64K seek=1 conv=notrunc
	
	# Filesystem 2
	(cd $(FUZIX_ROOT)/Standalone/filesystem-src; ./build-filesystem-ng -X -f $(IMAGES)/filesystem2.img -g 64 3072 -p platform-megadrive-disk2)
	# Blastem does not like to have data in the rom binary in the address space of sram
	rm -f /home/eythor/.local/share/blastem/fuzix/save.sram
	# .sram is saved in 16-bit little-endian format (byte-swapped)!!
	dd if=$(IMAGES)/filesystem2.img of=/home/eythor/.local/share/blastem/fuzix/save.sram bs=1536K conv=notrunc,swab
