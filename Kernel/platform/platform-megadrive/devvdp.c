#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <vt.h>
#include "devvdp.h"


int vdp_read(uint8_t minor, uint8_t rawflag, uint8_t flag)
{
    kprintf("eread: minor=%d, rawflag=%d, flag=%d\n", 
            minor, rawflag, flag);
    kprintf("%s\n", udata.u_base);
    udata.u_done = 0;
    return 0;
}

int vdp_write(uint8_t minor, uint8_t rawflag, uint8_t flag)
{
    kprintf("ewrite: minor=%d, rawflag=%d, flag=%d\n", 
            minor, rawflag, flag);

    kprintf("%s\n", udata.u_base);
    
    udata.u_done = udata.u_count;
    return udata.u_done;
}

int vdp_ioctl(uint_fast8_t minor, uarg_t request, char *data)
{
    if (request == VDPCLEAR) {
        VDP_clear();
    }
    if (request == VDPRESET) {
        VDP_reinit();
        kprintf("\033H"); // reset cursor to top left
    }
    return 0;
}
