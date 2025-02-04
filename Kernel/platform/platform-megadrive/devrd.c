/*
 * memory backed block device driver
 *
 *     /dev/rd0      (block device)      RAM disk
 *     /dev/rd1      (block device)      ROM disk
 *
 * 2017-01-03 William R Sowerbutts, based on RAM disk code by Sergey Kiselev
 */

#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include "devrd.h"

static const uint32_t dev_limit[NUM_DEV_RD] = {
    DEV_RD_ROM_START+DEV_RD_ROM_SIZE, /* /dev/rd0: ROM */
    // DEV_RD_RAM_START+DEV_RD_RAM_SIZE, /* /dev/rd1: RAM */
};

static const uint32_t dev_start[NUM_DEV_RD] = {
    DEV_RD_ROM_START, /* /dev/rd0: ROM */
    // DEV_RD_RAM_START, /* /dev/rd1: RAM */
};


extern uint32_t rd_cpy(void *dst, void *src, uint32_t count);

/* implements both rd_read and rd_write */
static int rd_transfer(bool is_read, uint_fast8_t minor, uint_fast8_t rawflag)
{
    uint32_t src_addr, dst_addr;

    uint32_t blk_addr = dev_start[minor] + ((uint32_t)udata.u_block << BLKSHIFT);
    
    /* Check if access would exceed device limits */
    if (blk_addr >= dev_limit[minor]) {
        udata.u_error = EIO;
        return -1;
    }
    
    /* Set up source and destination based on read/write direction */
    if (is_read) {
        src_addr = blk_addr;
        dst_addr = (uint32_t)udata.u_dptr;
    } else {
        src_addr = (uint32_t)udata.u_dptr;
        dst_addr = blk_addr;
        /* Don't allow writes to ROM device */
        if (minor == RD_MINOR_ROM) {
            udata.u_error = EROFS;
            return -1;
        }
    }
    
    /* Calculate transfer size in bytes */
    uint32_t count = udata.u_nblock << BLKSHIFT;
    
    /* Do the copy */
    rd_cpy((void *)dst_addr, (void *)src_addr, count);
    
    return count;
}


int rd_read(uint_fast8_t minor, uint_fast8_t rawflag, uint_fast8_t flag)
{
    flag;
    return rd_transfer(true, minor, rawflag);
}


int rd_write(uint_fast8_t minor, uint_fast8_t rawflag, uint_fast8_t flag)
{
    flag;
    return rd_transfer(false, minor, rawflag);
}


int rd_open(uint_fast8_t minor, uint16_t flags)
{
    flags; /* unused */

    switch(minor){
#if DEV_RD_RAM_PAGES > 0
        case RD_MINOR_RAM:
#endif
#if DEV_RD_ROM_PAGES > 0
        case RD_MINOR_ROM:
#endif
#if (DEV_RD_ROM_PAGES+DEV_RD_RAM_PAGES) > 0
            return 0;
#endif
        default:
            udata.u_error = ENXIO;
            return -1;
    }
}
