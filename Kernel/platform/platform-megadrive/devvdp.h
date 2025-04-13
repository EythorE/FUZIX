#ifndef __DEVVDP_DOT_H__
#define __DEVVDP_DOT_H__

#define VDPCLEAR    1
#define VDPRESET    2

extern void VDP_clear();
extern void VDP_reinit();
int vdp_read(uint_fast8_t minor, uint_fast8_t rawflag, uint_fast8_t flag);
int vdp_write(uint_fast8_t minor, uint_fast8_t rawflag, uint_fast8_t flag);
int vdp_ioctl(uint_fast8_t minor, uarg_t request, char *data);

#endif /* __DEVVDP_DOT_H__ */
