/*
 *	Set these top setings according to your board if different
 */

// /* ROM ramdisk definitions */
// extern char __rom_header_end[];

// /* ROM ramdisk definitions */
// #define DEV_RD_ROM_START   ((unsigned long)&__rom_header_end)
// #define DEV_RD_ROM_SIZE    0x4000  /* Size of ROM ramdisk (16KB example) */

// /* RAM ramdisk definitions */
// #define DEV_RD_RAM_START   0x4000  /* Starting address of RAM ramdisk */
// #define DEV_RD_RAM_SIZE    0x4000  /* Size of RAM ramdisk (16KB example) */

/* Basic TTY defines needed by kernel */
#define NUM_DEV_TTY 1      /* Minimum needed */
#define TTYDEV   513      /* Default TTY device */

/* Basic device defines needed by kernel */
#define NBUFS    1        /* Number of buffers */
#define NMOUNTS  1        /* Number of mounts */
#define BOOT_TTY 513        /* Set this to default device for stdio, stderr */

// /* Support a 40 column console for now */
// #define CONFIG_VT
// #define VT_RIGHT 39
// #define VT_BOTTOM 24



/* We need a tidier way to do this from the loader */
#define CMDLINE	NULL	  /* Location of root dev name */


#define CONFIG_SYSCLK	7670000    /* 7.67MHz */

/* Enable to make ^Z dump the inode table for debug */
#undef CONFIG_IDUMP
/* Enable to make ^A drop back into the monitor */
#undef CONFIG_MONITOR
/* Profil syscall support (not yet complete) */
#undef CONFIG_PROFIL

/* Remove all banking related config */
#undef CONFIG_MULTI
#define CONFIG_BANKS    0        /* No bank switching */
#undef CONFIG_SPLIT_ID
#undef CONFIG_SPLIT_UDATA

/* Keep flat memory model */
#define CONFIG_FLAT
#define CONFIG_32BIT
#define CONFIG_LEVEL_2

/* Simple memory layout */
#define UDATA_SIZE  1024
#define UDATA_BLKS  2



#define TICKSPERSEC 10   /* Ticks per second */


#define plt_copyright()