OUTPUT_ARCH(m68k)

MEMORY
{
    rom (rx) : ORIGIN = 0x000000, LENGTH = 0x010000  /* 64KB Cartridge ROM */
    rom_disk : ORIGIN = 0x010000, LENGTH = 0x1F0000  /* 1.9MB Cartridge ROM disk */
    ram_disk : ORIGIN = 0x200000, LENGTH = 0x180000  /* 1.5 MB Cartridge RAM disk */
    ram (rw) : ORIGIN = 0x380000, LENGTH = 0x080000  /* 512KB Cartridge RAM */
    udata (rw) : ORIGIN = 0xFF0000, LENGTH = 0x10000 /* 64KB RAM (not used, except temporarilly for the stack)*/
}

PROVIDE(_rom_start = ORIGIN(rom));
PROVIDE(_rom_end = ORIGIN(rom) + LENGTH(rom));
PROVIDE(_rod_start = ORIGIN(rom_disk));
PROVIDE(_rod_end = ORIGIN(rom_disk) + LENGTH(rom_disk));
PROVIDE(_rad_start = ORIGIN(ram_disk));
PROVIDE(_rad_end = ORIGIN(ram_disk) + LENGTH(ram_disk));
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

    .text : ALIGN(4) 
    { 
        _text_start = .;
        *(.text .text.*)
        _text_end = .;
    } > rom

    .rodata : ALIGN(4) 
    { 
        _rodata_start = .;
        *(.rodata .rodata.*)
        _rodata_end = .;
    } > rom

    _data_load = LOADADDR(.data);
    .data : ALIGN(4) 
    {
        _data_start = .;
        *(.data .data.*)
        _data_end = .;
    } > ram AT> rom

    .bss (NOLOAD) : ALIGN(4)
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
