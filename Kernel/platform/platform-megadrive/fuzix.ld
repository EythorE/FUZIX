OUTPUT_ARCH(m68k)

MEMORY
{
    rom (rx) : ORIGIN = 0x000000, LENGTH = 0x200000  /* 2MB Cartridge ROM */
    rom_disk : ORIGIN = 0x200000, LENGTH = 0x100000  /* 1MB Cartridge ROM disk */
    ram (rw) : ORIGIN = 0x300000, LENGTH = 0x100000  /* 1MB Cartridge RAM */
    udata (rw) : ORIGIN = 0xFF0000, LENGTH = 0x10000 /* 64KB RAM */
}

PROVIDE(_rom_start = ORIGIN(rom));
PROVIDE(_rom_end = ORIGIN(rom) + LENGTH(rom));
PROVIDE(_rd_start = ORIGIN(rom_disk));
PROVIDE(_rd_end = ORIGIN(rom_disk) + LENGTH(rom_disk));
PROVIDE(_ram_start = ORIGIN(ram));
PROVIDE(_ram_end = ORIGIN(ram) + LENGTH(ram));

SECTIONS
{
    .rom_header :    
    { 
        _rom_header_start = .;
        *(.rom_header)
        _rom_header_end = .;
    } > rom

    .text : ALIGN(2) 
    { 
        _text_start = .;
        *(.text .text.*)
        _text_end = .;
    } > rom

    .rodata : ALIGN(2) 
    { 
        _rodata_start = .;
        *(.rodata .rodata.*)
        _rodata_end = .;
    } > rom

    _data_load = LOADADDR(.data);
    .data : ALIGN(2) 
    {
        _data_start = .;
        *(.data .data.*)
        _data_end = .;
    } > ram AT> rom

    .bss (NOLOAD) : ALIGN(2)
    {
        _bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        _bss_end = .;
    } > ram

    .debug_info 0 : { *(.debug_info) }
    .debug_abbrev 0 : { *(.debug_abbrev) }
    .debug_line 0 : { *(.debug_line) }
}
