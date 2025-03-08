#include <kernel.h>
#include <timer.h>
#include <kdata.h>
#include <printf.h>


void map_init(void)
{
}

// uaddr_t ramtop;
uint8_t need_resched;

uint8_t plt_param(char *p)
{
	return 0;
}

void plt_discard(void)
{
}

void memzero(void *p, usize_t len)
{
	memset(p, 0, len);
}

extern void dbg_printf(char s[], ...);

void pagemap_init(void)
{
    /* Linker provided symbols for RAM boundaries */
	/* TODO: create a discard area at the end of the image and start
	   there */
    // extern uint32_t _ram_start;
    extern uint32_t _bss_end;
    extern uint32_t _ram_end;

    kprintf("Motorola 680%s%d processor detected.\n",
        sysinfo.cpu[1]?"":"0", sysinfo.cpu[1]);

    // uint32_t free_ram_start = (uint32_t)(&_bss_end + 511) & ~511;
    // uint32_t ram_end = (uint32_t)&_ram_end;
    // uint32_t free_ram = ram_end - free_ram_start;
    // kmemaddblk((void *)free_ram_start, free_ram);
    // kprintf("RAM: %dKB (%lx-%lx)\n", free_ram/1024, free_ram_start, ram_end);

    // I split the memory in two while debugging; there is something
    // wrong with memory management or executable relocations.
    // There seems to be a problem where the 2nd to third app
    // loaded in userspace does not load properly.

    uint32_t free_ram_start = (uint32_t)(&_bss_end + 511) & ~511;
    uint32_t ram_end = (uint32_t)&_ram_end;
    uint32_t free_ram = ram_end - free_ram_start;
    uint32_t ram_half = (free_ram / 2) & ~511;

    uint32_t block_2 = free_ram_start+ram_half;
    kmemaddblk((void *)free_ram_start, block_2 - free_ram_start);
    kprintf("RAM: %dKB (%lx-%lx)\n", (block_2 - free_ram_start)/1024, free_ram_start, block_2);

    // I can skip this or the one above but not the small space below
    kmemaddblk((void *)block_2, ram_end - block_2);
    kprintf("RAM: %dKB (%lx-%lx)\n", (ram_end - block_2)/1024, block_2, ram_end);

    // only works if I include this memory space???
    kmemaddblk((void *)0xFF0000, 0x10000);
    kprintf("RAM: %dKB (%lx-%lx)\n", 0x10000/1024, 0xFF0000, 0xFFFFFF);
}

// see mm/flat.c
/* Udata and kernel stacks */
/* We need an initial kernel stack and udata so the slot for init is
   set up at compile time */
u_block udata_block[PTABSIZE];

extern void dbg_udata();
/* This will belong in the core 68K code once finalized */
// This installs some header info into executables when they are initialized
void install_vdso(void)
{
	extern uint8_t vdso[];
	/* Should be uput etc */
	memcpy((void *)udata.u_codebase, &vdso, 0x20);
	dbg_udata();

}

uint8_t plt_udata_set(ptptr p)
{
	p->p_udata = &udata_block[p - ptab].u_d;
	return 0;
}

