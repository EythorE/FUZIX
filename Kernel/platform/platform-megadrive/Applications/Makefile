USERCPU=68000
FUZIX_ROOT=../../../..
export USERCPU FUZIX_ROOT
include $(FUZIX_ROOT)/Target/rules.$(USERCPU)

all: imshow images

imshow: imshow.o imshow_routines.o
	$(LINKER) $(CRT0) $^ -o $@ $(LINKER_OPT) $(LINKER_TAIL)

images:
	(cd image_convert; $(MAKE))

clean:
	rm -rf *.o imshow
	(cd image_convert; $(MAKE) clean)

