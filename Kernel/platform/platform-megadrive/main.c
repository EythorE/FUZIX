
#include <kernel.h>
#include <timer.h>
#include <kdata.h>
#include <printf.h>

extern char readKey();  // External assembly routine
extern void printString(char *str);  // External assembly routine
// void _start() {
//     char buffer[2] = {0, 0};  // Buffer to store the character and null terminator
//     printString("Input: ");
//     while (1) {
//         buffer[0] = readKey();  // Read a character using the external function
//         printString(buffer);    // Print the character
//     }
// }

uint16_t swap_dev = 0xFFFF;

void do_beep(void)
{
}

/*
 *	MMU initialize
 */

void map_init(void)
{
}

uaddr_t ramtop;
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

void pagemap_init(void)
{
	// uint8_t r;
	/* Linker provided end of kernel */
	/* TODO: create a discard area at the end of the image and start
	   there */
	extern uint8_t _end;

	kprintf("Motorola 680%s%d processor detected.\n",
		sysinfo.cpu[1]?"":"0",sysinfo.cpu[1]);

    uint32_t e = (uint32_t)&_end;

    uint32_t ram_end = 0xFFFFFF;
    /* Add available RAM block */
    kmemaddblk((void *)e, ram_end - e);
    
    kprintf("RAM: %dKB (%lx-%lx)\n", (ram_end - e)/1024, e, ram_end);

}

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

