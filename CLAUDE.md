# FUZIX Mega Drive — Build & Test Environment

## Overview

This documents how to build the FUZIX operating system for the Sega Mega Drive
and test it in the blastem emulator, all within a headless Linux environment
(tested on Ubuntu 24.04 x86_64).

## Prerequisites

```bash
apt-get install -y \
    gcc-m68k-linux-gnu \
    binutils-m68k-linux-gnu \
    blastem \
    xvfb \
    xdotool \
    imagemagick \
    byacc \
    bison
```

## Toolchain Setup

FUZIX expects `m68k-elf-*` tools but the Ubuntu packages provide
`m68k-linux-gnu-*`. These are functionally equivalent for bare-metal code.
Create symlinks:

```bash
for tool in gcc as ld objcopy objdump ar nm ranlib strip; do
    ln -sf /usr/bin/m68k-linux-gnu-$tool /usr/local/bin/m68k-elf-$tool
done
```

**Note:** `m68k-linux-gnu-gcc` defines `__linux__` and `linux`, which triggers a
warning in `lowlevel-68000.S` line 6. This is harmless — it's a `#warning` not
an `#error`. The generated code is identical to a true `m68k-elf-gcc` build for
`-m68000 -nostdlib` targets.

## Clone & Build

```bash
git clone --branch megadrive https://github.com/EythorE/FUZIX.git
cd FUZIX
```

Build order matters. Each step depends on the previous:

```bash
make stand                    # Host-native filesystem tools (mkfs, ucp, fsck)
make ltools                   # Library build tools
make libs                     # Cross-compile C library + curses for m68k
make apps                     # Cross-compile userspace applications
make diskimage                # Build kernel + ROM + filesystems
```

If `make diskimage` fails on the final `cp` to blastem's save directory (because
`$USER` is empty), just create the directory manually:

```bash
mkdir -p /root/.local/share/blastem/fuzix/
cp Images/megadrive/filesystem2.sram /root/.local/share/blastem/fuzix/save.sram
```

### Image Downloads

The `Applications/image_convert` step tries to download test images (Lena, etc.)
from the internet. If network access is restricted, create dummy files:

```bash
cd Kernel/platform/platform-megadrive/Applications/image_convert
touch lena.simg baboon.simg macaw.simg
```

Or modify `Applications/Makefile` to skip the `images` target.

## Output Files

After a successful build:

| File | Description |
|------|-------------|
| `Images/megadrive/fuzix.rom` | 2MB ROM: kernel (64KB) + ROM filesystem (1.9MB) |
| `Images/megadrive/filesystem2.sram` | 1.5MB writable RAM disk (byte-swapped for blastem) |
| `Images/megadrive/filesystem.img` | ROM filesystem image (big-endian) |
| `Images/megadrive/filesystem2.img` | RAM filesystem image (big-endian) |
| `Kernel/platform/platform-megadrive/fuzix.elf` | ELF with debug symbols for GDB |

## Running in Blastem (Headless)

### Blastem Configuration

Edit `/usr/share/games/blastem/default.cfg`:

```
video {
    gl off          # Avoids GLEW initialization failure dialog
    vsync off
}

io {
    devices {
        1 gamepad6.1
        2 saturn keyboard    # Required for FUZIX keyboard input
    }
}
```

### Headless Execution with Screenshot Capture

```bash
cat > run_fuzix.sh << 'SCRIPT'
#!/bin/bash
export LIBGL_ALWAYS_SOFTWARE=1
export SDL_AUDIODRIVER=dummy

# Deploy SRAM filesystem
mkdir -p /root/.local/share/blastem/fuzix/
cp Images/megadrive/filesystem2.sram /root/.local/share/blastem/fuzix/save.sram

/usr/games/blastem Images/megadrive/fuzix.rom &
BPID=$!

sleep 10                                          # Wait for boot
import -window root screenshot.png                # Capture VDP output

kill $BPID 2>/dev/null; wait $BPID 2>/dev/null
SCRIPT
chmod +x run_fuzix.sh
xvfb-run -a -s "-screen 0 800x600x24" ./run_fuzix.sh
```

### Interactive Session (with keyboard input)

```bash
cat > run_interactive.sh << 'SCRIPT'
#!/bin/bash
export LIBGL_ALWAYS_SOFTWARE=1
export SDL_AUDIODRIVER=dummy
mkdir -p /root/.local/share/blastem/fuzix/
cp Images/megadrive/filesystem2.sram /root/.local/share/blastem/fuzix/save.sram

/usr/games/blastem Images/megadrive/fuzix.rom &
BPID=$!

sleep 8                                    # Wait for login prompt
xdotool key Control_R                      # Enable blastem keyboard capture
sleep 0.5
xdotool type --delay 150 "root"            # Login
xdotool key Return
sleep 4
xdotool type --delay 150 "ls /"            # Run a command
xdotool key Return
sleep 2
import -window root shell_output.png       # Capture

kill $BPID 2>/dev/null; wait $BPID 2>/dev/null
SCRIPT
xvfb-run -a -s "-screen 0 800x600x24" ./run_interactive.sh
```

## Known Issues & Fixes

### 1. Blastem 0.6.3 VDP Read Freeze

**Symptom:** `Read from VDP data port with invalid source, CPU is now frozen. VDP Address: C082, CD: 40`

**Cause:** Blastem 0.6.3.4 (Ubuntu package) is stricter than 0.6.2 about VRAM
reads. The `read_cursor_char` function in `devvt.S` reads from the VDP data port
after setting up a VRAM read command, but blastem 0.6.3 considers the prior VDP
state invalid.

**Workaround:** Stub `read_cursor_char` in `devvt.S` to return 0:

```asm
read_cursor_char:
    moveq #0, %d4
    rts
```

This disables cursor character preservation (cursor won't restore the character
underneath it) but everything else works. The proper fix is to read the VDP
status register before issuing the VRAM read command to reset the pending write
flag:

```asm
    move.w (VDP_CONTROL), %d4    | Reset write pending flag
    move.l %d3, (VDP_CONTROL)    | Set up VRAM read
    nop
    nop
    move.w (VDP_DATA), %d4       | Read VRAM data
```

This needs testing on both blastem versions.

### 2. Boot Device Selection

`config.h` has `BOOTDEVICE` commented out by default, which causes the kernel to
prompt `bootdev:` at startup. Since keyboard input requires the Saturn keyboard
to be configured and captured, it's easier to hardcode:

```c
#define BOOTDEVICE 0    /* ROM disk — read-only, baked into ROM */
#define BOOTDEVICE 1    /* RAM disk — writable, loaded from .sram file */
```

Device 0 (ROM disk) boots reliably. Device 1 (RAM disk) requires the `.sram`
file to be correctly deployed to blastem's save directory.

### 3. `m68k-linux-gnu-gcc` Defines `linux`

The cross-compiler defines `linux` and `__linux__` preprocessor symbols.
`lowlevel-68000.S` has a `#ifdef linux` / `#warning` guard. This is cosmetic —
the generated code is not affected.

## Memory Map

```
0x000000 - 0x00FFFF  Kernel code + ROM header (64KB, ROM)
0x010000 - 0x1FFFFF  ROM disk /dev/rd0 (1.9MB, ROM)
0x200000 - 0x37FFFF  RAM disk /dev/rd1 (1.5MB, cartridge SRAM)
0x380000 - 0x3FFFFF  Kernel data/BSS + heap (512KB, cartridge SRAM)
0xFF0000 - 0xFFFFFF  68000 internal RAM (64KB, used by allocator)
```

## Real Hardware Issues (Not Yet Fixed)

These are the issues preventing boot on real Mega Drive hardware (Mega Everdrive
Pro). They do NOT affect emulator testing but must be fixed for hardware:

### Missing Z80 Initialization

`crt0.S` never touches the Z80. On real hardware the Z80 starts executing
garbage and can conflict with 68K bus access. Add before `VDP_WriteTMSS`:

```asm
    move.w  #0x0100, (0xA11100)    | Request Z80 bus
    move.w  #0x0100, (0xA11200)    | Hold Z80 in reset
.Lwait_z80:
    btst    #0, (0xA11100)
    bne.s   .Lwait_z80
    move.w  #0x0000, (0xA11200)    | Release reset (bus still held)
```

### Missing SRAM Enable

Cartridge SRAM at `0x200000-0x3FFFFF` must be enabled via the mapper register.
Blastem auto-enables this based on the ROM header; real hardware does not.

For standard mapper (open-source Everdrives):
```asm
    move.b  #0x01, (0xA130F1)      | Enable SRAM read/write
```

For Mega Everdrive Pro (SSF mapper):
```asm
    move.w  #0x8000, (0xA130F0)    | Unlock mapper
```

### ROM Checksum

The ROM header checksum is hardcoded to `0x0000`. Some console revisions verify
this. Add a post-build step to calculate the correct checksum (sum of all words
from offset 0x200 to end of ROM, stored at offset 0x18E).

### PSG Not Silenced

The Programmable Sound Generator is never initialized and may produce noise on
real hardware at boot.

### I/O Ports Not Initialized

Controller port control registers (`0xA10009`, `0xA1000B`, `0xA1000D`) are never
written with `0x40`. Emulators don't care; real hardware needs this for correct
button reads.

## Debugging with GDB

```bash
m68k-elf-gdb -q --tui \
    -ex "target remote | blastem -D Images/megadrive/fuzix.rom" \
    Kernel/platform/platform-megadrive/fuzix.elf
```

Useful breakpoints:
- `b fuzix_main` — kernel main entry
- `b plt_monitor` — panic handler
- `b switchin` — process context switch
- `b e_trap12` — system call entry

## Quick Rebuild Cycle

After modifying platform code:

```bash
make -C Kernel TARGET=megadrive VERSION=0 SUBVERSION=4 clean
make -C Kernel TARGET=megadrive VERSION=0 SUBVERSION=4
cp Kernel/fuzix.bin Images/megadrive/fuzix.rom
dd if=Images/megadrive/filesystem.img of=Images/megadrive/fuzix.rom bs=64K seek=1 conv=notrunc
# Then run in blastem
```

To rebuild the filesystem (after changing packages or adding files):

```bash
cd Standalone/filesystem-src
./build-filesystem-ng -X -f ../../Images/megadrive/filesystem.img -g 64 3968 -p platform-megadrive
```

## File Layout

```
Kernel/platform/platform-megadrive/
├── crt0.S              Boot code, vector table, ROM header, data init
├── megadrive.S          Interrupt handlers, init_early, init_hardware
├── devvt.S              VDP text output, cursor, scrolling
├── vdp.S                VDP initialization (TMSS, registers, VRAM clear, palette, font)
├── keyboard.c           Saturn keyboard driver (high-level)
├── keyboard_read.S      Saturn keyboard protocol (low-level)
├── config.h             Platform config (memory sizes, VT dimensions, tick rate)
├── fuzix.ld             Linker script (ROM/RAM/SRAM memory regions)
├── main.c               Memory init, pagemap, udata blocks
├── devrd.c              ROM disk + RAM disk block device driver
├── devices.c            Device table
├── devtty.c             TTY device (keyboard → tty input)
├── dbg_output.S         Debug overlay on VDP plane B
├── macros.S             Z80 bus control macros
└── control_ports.def    Hardware register addresses
```
