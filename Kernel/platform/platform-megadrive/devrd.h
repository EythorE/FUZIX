#ifndef __DEVRD_DOT_H__
#define __DEVRD_DOT_H__

/* minor device numbers */
#define RD_MINOR_ROM     0
#define RD_MINOR_RAM     1
#define NUM_DEV_RD       1

/* public interface */
int rd_open(uint_fast8_t minor, uint16_t flags);
int rd_read(uint_fast8_t minor, uint_fast8_t rawflag, uint_fast8_t flag);
int rd_write(uint_fast8_t minor, uint_fast8_t rawflag, uint_fast8_t flag);

#endif /* __DEVRD_DOT_H__ */
