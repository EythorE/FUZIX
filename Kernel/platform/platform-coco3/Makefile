
CSRCS = ttydw.c dwtime.c devsys.c
CSRCS += devices.c main.c libc.c devlpr.c mbr.c
CSRCS_OPTIONAL = devsdc.c devrtsd.c

CSRCS_O0 = devtty.c

CDSRCS = ../../dev/tinydisk_discard.c
CDSRCS_OPTIONAL = ../../dev/tinyide_discard.c ../../dev/tinysd_discard.c

DSRCS = ../../dev/devdw.c ../../dev/tinydisk.c
DSRCS_OPTIONAL = ../../dev/tinyide.c ../../dev/tinysd.c

NSRCS = ../../dev/net/net_native.c

ASRCS = coco3.s crt0.s
ASRCS += tricks.s commonmem.s usermem_gime.s ../../dev/drivewire/drivewire.s videoll.s
ASRCS_OPTIONAL = ide.s sd.s rtsd.s sdc.s

VSRCS_O0 = video.c

COBJS = $(CSRCS:.c=$(BINEXT))
COBJS_OPTIONAL = $(CSRCS_OPTIONAL:.c=$(BINEXT))
COBJS_O0 = $(CSRCS_O0:.c=$(BINEXT))
AOBJS = $(ASRCS:.s=$(BINEXT))
AOBJS_OPTIONAL = $(ASRCS_OPTIONAL:.s=$(BINEXT))
DOBJS = $(patsubst ../../dev/%.c,%$(BINEXT), $(DSRCS))
DOBJS_OPTIONAL = $(patsubst ../../dev/%.c,%$(BINEXT), $(DSRCS_OPTIONAL))
NOBJS = $(patsubst ../../dev/net/%.c,%$(BINEXT), $(NSRCS))
CDOBJS = $(patsubst ../../dev/%.c,%$(BINEXT), $(CDSRCS))
CDOBJS_OPTIONAL = $(patsubst ../../dev/%.c,%$(BINEXT), $(CDSRCS_OPTIONAL))
VOBJS_O0 = $(VSRCS_O0:.c=$(BINEXT))

OBJS  = $(COBJS) $(COBJS_O0) $(AOBJS) $(DOBJS) $(CDOBJS) $(NOBJS) $(VOBJS_O0)
OBJS_OPTIONAL = $(COBJS_OPTIONAL) $(AOBJS_OPTIONAL) $(DOBJS_OPTIONAL) $(CDOBJS_OPTIONAL)

CROSS_CCOPTS += -I../../dev/

HIGH = -mcode-section=.text3

# Set 'SUBTARGET' to one of: emu, real, fpga, nano. 

ifndef SUBTARGET
SUBTARGET = emu
endif

ifeq ($(SUBTARGET),real)
COCO_IDE = 1
COCO_SDC = 1
endif

ifeq ($(SUBTARGET),emu)
COCO_IDE = 1
COCO_BECKER = 1
endif

ifeq ($(SUBTARGET),fpga)
COCO_SDFPGA = 1
COCO_BECKER = 1
endif

ifeq ($(SUBTARGET),nano)
COCO_SDNANO = 1
endif

ifdef COCO_SDC
DRIVERS += devsdc.o sdc.o
CROSS_CC += -DCONFIG_COCOSDC
endif

ifdef COCO_IDE
DRIVERS += tinyide.o tinyide_discard.o ide.o
CROSS_CC += -DCONFIG_COCOIDE
endif

ifdef COCO_SDFPGA
DRIVERS += tinysd.o tinysd_discard.o sd.o
CROSS_CC += -DCONFIG_COCOSDFPGA
endif

ifdef COCO_SDNANO
DRIVERS += devrtsd.o rtsd.o
CROSS_CC += -DCONFIG_COCOSDNANO
endif

ifdef COCO_BECKER
ASOPTS = --defsym BECKER=1
else
ASOPTS = --defsym BECKER=0 
endif

.PHONY: all
all:

$(COBJS) $(COBJS_OPTIONAL): %$(BINEXT): %.c
	$(QUIET_CC)$(CROSS_CC) $(CROSS_CCOPTS) -o $@ $<

$(COBJS_O0): %$(BINEXT): %.c
	$(QUIET_CC)$(CROSS_CC) $(CROSS_CCOPTS) -O0 -o $@ $<

$(CDOBJS) $(CDOBJS_OPTIONAL): %$(BINEXT): ../../dev/%.c
	$(QUIET_CC)$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -o $@ $<

$(DOBJS) $(DOBJS_OPTIONAL): %$(BINEXT): ../../dev/%.c
	$(QUIET_CC)$(CROSS_CC) $(CROSS_CCOPTS) $(HIGH) -o $@ $<

$(NOBJS): %$(BINEXT): ../../dev/net/%.c
	$(QUIET_CC)$(CROSS_CC) $(CROSS_CCOPTS) -O0 -o $@ $<

$(AOBJS) $(AOBJS_OPTIONAL): %$(BINEXT): %.s
	$(QUIET_AS)$(CROSS_AS) $(ASOPTS) $< -o $@

$(VOBJS_O0): %$(BINEXT): %.c
	$(QUIET_CC)$(CROSS_CC) $(CROSS_CC_VIDEO) $(CROSS_CCOPTS) -O0 -o $@ $<

# Note: compile flags for some of these are overridden during the top-level
# build in rules.mk (otherwise we'd have to rebuild them locally here).

../../fuzix.bin: $(OBJS) $(DRIVERS)
	$(QUIET_LD)$(CROSS_LD) -o $@ -Map=../../fuzix.map --script=fuzix.link --oformat=decb \
	crt0.o commonmem.o \
	coco3.o ../../start.o ../../version.o ../../cpu-6809/lowlevel-6809.o \
	tricks.o main.o ../../timer.o ../../kdata.o devices.o \
	../../dev/drivewire/drivewire.o devdw.o ttydw.o tinydisk.o tinydisk_discard.o devlpr.o \
	../../devio.o ../../filesys.o ../../process.o ../../inode.o ../../syscall_fs.o \
	../../syscall_proc.o ../../syscall_other.o ../../mm.o ../../bank16k.o ../../swap.o \
	../../tty.o ../../devsys.o ../../usermem.o ../../syscall_fs2.o ../../syscall_exec16.o \
	../../syscall_fs3.o ../../syscall_exec.o ../../blk512.o ../../memalloc_none.o \
	../../cpu-6809/usermem_std-6809.o devtty.o libc.o ../../vt.o usermem_gime.o video.o \
	videoll.o dwtime.o devsys.o mbr.o ../../network.o \
	../../syscall_net.o net_native.o $(DRIVERS)

fuzix.dsk: ../../fuzix.bin boot.bin AUTOEXEC.BAS
# make DECB disk w/ new kernel
	rm -f $@
	decb dskini $@
	decb copy -2 -b ../../fuzix.bin $@,FUZIX.BIN
	decb copy -2 -b boot.bin $@,BOOT.BIN
	decb copy -l -0 -a AUTOEXEC.BAS $@,AUTOEXEC.BAS

.PHONY: image
image: fuzix.dsk

boot.bin: boot/boot.s
	lwasm -lboot.list -oboot.bin boot/boot.s

.PHONY: clean
clean:
	rm -f $(OBJS) $(OBJS_OPTIONAL) fuzix.dsk boot.bin boot.list core *~
	rm -f fuzix.tmp

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

.PHONY: diskimage
diskimage:
	# Make a blank disk image with partition
	dd if=$(FUZIX_ROOT)/Standalone/filesystem-src/parttab.40M of=$(IMAGES)/disk.img bs=40017920 conv=sync
	# Add the file system
	dd if=$(IMAGES)/filesys.img of=$(IMAGES)/disk.img bs=512 seek=2048 conv=notrunc
	# Add the floppy image (assumes the usual binary hdbdos image and offset)
	$(FUZIX_ROOT)/Kernel/tools/diskpad <fuzix.dsk >fuzix.tmp
	dd if=fuzix.tmp of=$(IMAGES)/disk.img bs=512 seek=339420 conv=notrunc
	# Make an emulator image of it
	cat $(FUZIX_ROOT)/Standalone/filesystem-src/idehdr.40M $(IMAGES)/disk.img > $(IMAGES)/emu-ide.img

include ../../quiet.mk
