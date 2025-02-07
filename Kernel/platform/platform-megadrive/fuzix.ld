OUTPUT_ARCH(m68k)

SEARCH_DIR(.)

MEMORY
{
    rom (rx) : ORIGIN = 0x000000, LENGTH = 0x200000  /* 4MB Cartridge ROM/RAM */
    rom_disk : ORIGIN = 0x200000, LENGTH = 0x100000
    ram (rw) : ORIGIN = 0xFF0000, LENGTH = 0x010000  /* 64KB RAM */
}

/*
 * System in ROM, data/bss in RAM
 */
SECTIONS
{
  . = 0x000000;
  _rom_start = .;
  .rom_header :
  {
    *(.rom_header)
    __rom_header_end = .;
  } > rom
  .text : ALIGN(0x4)
  {
    *(.text .text.*)
    *(.rodata .rodata.*)

    . = ALIGN(0x4);
    __INIT_SECTION__ = . ;
    LONG (0x4e560000)   /* linkw %fp,#0 */
    *(.init)
    SHORT (0x4e5e)      /* unlk %fp */
    SHORT (0x4e75)      /* rts */

    . = ALIGN(0x4);
    __FINI_SECTION__ = . ;
    LONG (0x4e560000)   /* linkw %fp,#0 */
    *(.fini)
    SHORT (0x4e5e)      /* unlk %fp */
    SHORT (0x4e75)      /* rts */

    . = ALIGN(0x4);
    _etext = .;
    *(.lit)
  } > rom
  _rom_end = .;
  
  .data :
  {
    _data = .;
    *(.got.plt) *(.got)
    *(.shdata)
    *(.data .data.*)
    _edata = .;
  } > ram AT >rom

  .bss :
  {
    _ram_start = .;
    . = ALIGN(0x4);
    __bss_start = . ;
    *(.shbss)
    *(.bss .bss.*)
    *(COMMON)
    _end =  ALIGN (0x8);
    __end = _end;
  } > ram

}
