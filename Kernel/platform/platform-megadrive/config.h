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


// /* ROM ramdisk definitions */
#define BLKSHIFT 9                 /* 512 byte blocks */
#define DEV_RD_ROM_PAGES 3968     /* size of the ROM disk (/dev/rd0) in 512B pages */
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


/* Size for a slightly bigger setup than the little 8bit boxes */
#define PTABSIZE	32
#define OFTSIZE		30
#define ITABSIZE	50
#define UFTSIZE		16

// #define TICKSPERSEC 300   /* Ticks per second */
// #define PROGBASE    0x0000  /* also data base */
// #define PROGLOAD    0x0100  /* also data base */
// #define PROGTOP     0xC000  /* Top of program, below C000 for simplicity
//                                to get going */


/* Basic TTY defines needed by kernel */
#define NUM_DEV_TTY 1      /* Minimum needed */
#define TTYDEV   513      /* Default TTY device */

/* Basic device defines needed by kernel */
#define NBUFS    4        /* Number of buffers */
#define NMOUNTS  2        /* Number of mounts */
#define BOOT_TTY 513        /* Set this to default device for stdio, stderr */

#define CONFIG_SPLIT_UDATA	/* Adjacent addresses but different bank! */
#define UDATA_SIZE	1024
#define UDATA_BLKS	2
#define MAX_SWAPS   0	    	/* We will size if from the partition */

#define BOOTDEVICE 1            /* 1 is the rom disk, 2 is the ram disk */

/* We need a tidier way to do this from the loader */
#define CMDLINE	NULL	  /* Location of root dev name */


#define CONFIG_SYSCLK	7670000    /* 7.67MHz */


#undef CONFIG_MULTI
#undef CONFIG_SPLIT_ID
#undef CONFIG_SPLIT_UDATA

/* This is important for some reason*/
#define CONFIG_SPLIT_ID
#define CONFIG_PARENT_FIRST

/* Not meaningful but we currently chunk to 512 bytes */
#define CONFIG_BANKS 	(65536/512)


#define CONFIG_FLAT
#define CONFIG_32BIT
#define CONFIG_LEVEL_2



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
