#include <kernel.h>

extern void dbg_printf(char s[], ...);

void dbg_udata() {
    dbg_printf("udata_insys: %b\n", udata.u_insys);
    dbg_printf("udata_name: %s\n", udata.u_name);
    dbg_printf("udata_database: %l\n", udata.u_database);
};
