
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

extern void clear_across(int8_t y, int8_t x, int16_t num);
void pagemap_init(void)
{
    /* Linker provided symbols for RAM boundaries */
    extern uint32_t _ram_start;
    extern uint32_t _ram_end;
    extern uint32_t _bss_end;

    kprintf("Motorola 680%s%d processor detected.\n",
        sysinfo.cpu[1]?"":"0", sysinfo.cpu[1]);

    uint32_t free_ram_start = (uint32_t)&_bss_end;
    uint32_t ram_end = (uint32_t)&_ram_end;

    kmemaddblk((void *)free_ram_start, ram_end - free_ram_start);
    kprintf("RAM: %dKB (%lx-%lx)\n", (ram_end - free_ram_start)/1024, free_ram_start, ram_end);
}

// see mm/flat.c
/* Udata and kernel stacks */
/* We need an initial kernel stack and udata so the slot for init is
   set up at compile time */
u_block udata_block[PTABSIZE];

/* This will belong in the core 68K code once finalized */

void install_vdso(void)
{
	extern uint8_t vdso[];
	/* Should be uput etc */
	memcpy((void *)udata.u_codebase, &vdso, 0x20);
}

uint8_t plt_udata_set(ptptr p)
{
	p->p_udata = &udata_block[p - ptab].u_d;
	return 0;
}

