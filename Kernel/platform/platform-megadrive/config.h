// #define DEBUG
// #define DEBUG_MEMORY
// #define DEBUG_SLEEP
// #define DEBUG_SYSCALL

/* Enable to make ^Z dump the inode table for debug */
#undef CONFIG_IDUMP
/* Enable to make ^A drop back into the monitor */
#undef CONFIG_MONITOR
/* Profil syscall support (not yet complete) */
#undef CONFIG_PROFIL



#define BOOTDEVICE 1            /* 0 is the rom disk, 1 is the ram disk */

/* ROM ramdisk definitions */
#define BLKSHIFT 9                 /* 512 byte blocks */
#define DEV_RD_ROM_PAGES 3968      /* size of the ROM disk (/dev/rd0) in 512B pages */
#define DEV_RD_RAM_PAGES 3072      /* size of the RAM disk (/dev/rd1) in 512B pages */

#define DEV_RD_ROM_START ((uint32_t)0x010000)
#define DEV_RD_RAM_START ((uint32_t)0x200000)
#define DEV_RD_ROM_SIZE  ((uint32_t)DEV_RD_ROM_PAGES << BLKSHIFT)
#define DEV_RD_RAM_SIZE  ((uint32_t)DEV_RD_RAM_PAGES << BLKSHIFT)


#define CONFIG_VT
#define VT_WIDTH	40
#define VT_HEIGHT	28
#define VT_RIGHT	39
#define VT_BOTTOM	27

#define CONFIG_FONT8X8

/* Basic TTY defines needed by kernel */
#define NUM_DEV_TTY 1     /* Minimum needed */
#define TTYDEV   513      /* Default TTY device */
#define BOOT_TTY 513      /* Set this to default device for stdio, stderr */


/* Size for a slightly bigger setup than the little 8bit boxes */
#define PTABSIZE	32
#define OFTSIZE		30
#define ITABSIZE	50
#define UFTSIZE		16


/* Basic device defines needed by kernel */
#define NBUFS       16        /* Increase from 4 to 20 */
#define NMOUNTS     2        /* Increase from 2 to 4 */


#define CONFIG_FLAT
#define CONFIG_32BIT
#define CONFIG_LEVEL_2
#undef CONFIG_MULTI
#define UDATA_SIZE	1024

/* no swap */
#undef CONFIG_SPLIT_UDATA
#undef UDATA_BLKS
#undef MAX_SWAPS


// When CONFIG_SPLIT_ID is defined, the memory manager separates code (text) and data into different memory blocks. This creates a memory layout where:
// block 0: Code R/O
// block 1: Data
// block 3+: memallocs()
// Kernel/mm/flat.c
/* On a system where we can split code from data the code
    ends up shared across fork and we occupy two memory blocks
    independently allocated. On a system where we can't we
    allocate a single block for everything and the database is
    just offset */
// i.e. when forking code is not copied when CONFIG_SPLIT_ID is defined.
// when we dont split instruction data, we do run into bus errors, potentially
// word mis-aligned instruction
// Split Instruction/Data:
#define CONFIG_SPLIT_ID
#undef CONFIG_SPLIT_ID

#define CONFIG_PARENT_FIRST /* required; see dofork in Kernel/lib/68000flat.S */



/* We need a tidier way to do this from the loader */
#define CMDLINE	NULL	  /* Location of root dev name */

/* no banking */
#define CONFIG_BANKS 	0

#define CONFIG_SYSCLK	7670000    /* 7.67MHz */

/*
 * How fast does the clock tick (if present), or how many times a second do
 * we simulate if not. For a machine without video 10 is a good number. If
 * you have video you probably want whatever vertical sync/blank interrupt
 * rate the machine has. For many systems it's whatever the hardware gives
 * you.
 *
 * Note that this needs to be divisible by 10 and at least 10. If your clock
 * is a bit slower you may need to fudge things somewhat so that the kernel
 * gets 10 timer interrupt calls per second.
 */
#define TICKSPERSEC 50	 /* PAL = 50, NTSC = 60 */

#define plt_copyright()
