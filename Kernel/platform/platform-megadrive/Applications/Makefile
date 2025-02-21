# There is an rule in Applications/Makefile to make oneof apps, this makefile should be uneccecery
USERCPU=68000
FUZIX_ROOT=../../../..
export USERCPU FUZIX_ROOT
include $(FUZIX_ROOT)/Target/rules.$(USERCPU)

SRCSNS = tapp.c
SRCS  = 
SRCTC = 

OBJS = $(SRCS:.c=.o)
OBJSNS = $(SRCSNS:.c=.o)
OBJTC = $(SRCTC:.c=.o)

APPS = $(OBJS:.o=)
APPSNS = $(OBJSNS:.o=)
APPTC = $(OBJTC:.o=)

all: $(APPS) $(APPSNS) $(APPTC) $(APPOTHER) size.report

$(APPS): %: %.o
	$(LINKER) $(CRT0) $^ -o $@ $(LINKER_OPT) $(LINKER_TAIL)

$(APPSNS): %: %.o
	$(LINKER) $(CRT0NS) $^ -o $@ $(LINKER_OPT) $(LINKER_TAIL)

$(APPTC): %: %.o
	$(LINKER) $(CRT0) $^ -o $@ $(LINKER_OPT) -ltermcap$(USERCPU) $(LINKER_TAIL)

$(APPCURSES): %: %.o
	$(LINKER) $(CRT0) $^ -o $@ $(LINKER_OPT) -lcurses$(USERCPU) -ltermcap$(USERCPU) $(LINKER_TAIL)

	
size.report: $(APPS) $(APPSNS) $(APPTC)
	ls -l $^ > $@

clean:
	rm -f $(OBJS) $(OBJSNS) $(OBJTC) $(OBJCURSES)
	rm -f $(APPS) $(APPSNS) $(APPTC) $(APPCURSES)
	rm -f $(SRCS:.c=) core *~ *.asm *.lst *.sym *.map *.noi *.lk *.ihx *.tmp *.bin size.report *.o

rmbak:
	rm -f *~ core

ifneq ($(CI_TESTING),)
init.o: CFLAGS += -DAUTOLOGIN
endif
