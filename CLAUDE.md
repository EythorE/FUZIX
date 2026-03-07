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

**IMPORTANT — Toolchain difference:** The port was developed with a true
bare-metal `m68k-elf-gcc` 14.2.0 (built from source per README.md instructions).
The Ubuntu `m68k-linux-gnu-gcc` 13.3.0 builds the kernel and all apps
successfully, but the resulting binaries have a **process forking bug** — the
shell panics with `inode freed.` after login. This is likely caused by subtle ABI
or relocation differences between the two compilers. See "Known Bug: inode freed
panic" below for details. To get a fully working system, build the proper
toolchain from source as described in `Kernel/platform/platform-megadrive/README.md`.

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

To skip login (auto-login as root for CI/testing):
```bash
make CI_TESTING=1 apps        # Rebuilds init with -DAUTOLOGIN
make diskimage
```

### `make diskimage` Failures

**SRAM deploy failure** (`cp` to blastem save dir): If `$USER` is empty:
```bash
mkdir -p /root/.local/share/blastem/fuzix/
cp Images/megadrive/filesystem2.sram /root/.local/share/blastem/fuzix/save.sram
```

**Image download failure** (network restricted): The `image_convert` step
downloads test images. If blocked, generate locally:
```bash
cd Kernel/platform/platform-megadrive/Applications/image_convert
python3 -m venv venv && . venv/bin/activate
pip install pillow numpy scikit-learn
# Generate a test image (any square PNG works)
python3 create_image.py your_image.png -o lena.simg
cp lena.simg baboon.simg && cp lena.simg macaw.simg
```

Or create empty dummy files:
```bash
touch lena.simg baboon.simg macaw.simg
```

### `make clean` Warning

`make -C Kernel ... clean` deletes the `Applications/` build artifacts including
`imshow`, `*.simg` files, and the Python venv. If you need to rebuild the kernel
without losing these, use the quick rebuild cycle below instead of `make clean`.

## Output Files

After a successful build:

| File | Description |
|------|-------------|
| `Images/megadrive/fuzix.rom` | 2MB ROM: kernel (64KB) + ROM filesystem (1.9MB) |
| `Images/megadrive/filesystem2.sram` | 1.5MB writable RAM disk (byte-swapped for blastem 0.6.2) |
| `Images/megadrive/filesystem.img` | ROM filesystem image (byte-reversed with `-X`) |
| `Images/megadrive/filesystem2.img` | RAM filesystem image (byte-reversed with `-X`) |
| `Kernel/platform/platform-megadrive/fuzix.elf` | ELF with debug symbols for GDB |

## Running in Blastem (Headless)

### Blastem Configuration

The blastem config is at `/etc/blastem/default.cfg` (Ubuntu package) or
`~/.config/blastem/blastem.cfg`. Required changes:

```
video {
    gl off          # Avoids GLEW initialization failure in headless/software mode
    vsync off
}

io {
    devices {
        1 gamepad6.1
        2 saturn keyboard    # Required for FUZIX keyboard input
    }
}
```

### SRAM Deployment — CRITICAL: Blastem Version Differences

The Makefile builds `filesystem2.sram` using `dd conv=swab` (byte-swap) from
`filesystem2.img`. This is correct for **blastem 0.6.2** which byte-swaps SRAM
data on load.

**Blastem 0.6.3.4 (Ubuntu 24.04 package) does NOT byte-swap SRAM on load.**

| Blastem version | Deploy command |
|----------------|----------------|
| 0.6.2 (upstream) | `cp filesystem2.sram save.sram` (use the swab'd file) |
| 0.6.3.4 (Ubuntu) | `cp filesystem2.img save.sram` (use the .img directly) |

If you get `panic: no root` with `Mounting root fs (root_dev=1, ro): failed`,
try the other deployment method. The filesystem metadata is byte-reversed (`-X`
flag) and must match what the kernel expects.

### Headless Execution with Screenshot Capture

```bash
cat > run_fuzix.sh << 'SCRIPT'
#!/bin/bash
export LIBGL_ALWAYS_SOFTWARE=1
export SDL_AUDIODRIVER=dummy

# Deploy SRAM filesystem
mkdir -p /root/.local/share/blastem/fuzix/
# For blastem 0.6.3.4 (Ubuntu): use .img directly
cp Images/megadrive/filesystem2.img /root/.local/share/blastem/fuzix/save.sram
# For blastem 0.6.2: use the byte-swapped .sram instead
# cp Images/megadrive/filesystem2.sram /root/.local/share/blastem/fuzix/save.sram

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
cp Images/megadrive/filesystem2.img /root/.local/share/blastem/fuzix/save.sram

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

### 1. Blastem 0.6.3 VDP Read Freeze (FIXED)

**Symptom:** `Read from VDP data port with invalid source, CPU is now frozen. VDP Address: C082, CD: 40`

**Cause:** Blastem 0.6.3.4 (Ubuntu package) is stricter than 0.6.2 about VRAM
reads. The `read_cursor_char` function in `devvt.S` reads from the VDP data port
after setting up a VRAM read command, but blastem 0.6.3 considers the prior VDP
state invalid.

**Applied fix:** Stubbed `read_cursor_char` in `devvt.S` to return 0:

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

### 2. Boot Device Selection (FIXED)

`config.h` has `BOOTDEVICE` commented out by default, which causes the kernel to
prompt `bootdev:` at startup. Since keyboard input requires the Saturn keyboard
to be configured and captured, it's easier to hardcode:

```c
#define BOOTDEVICE 0    /* ROM disk — read-only, baked into ROM */
#define BOOTDEVICE 1    /* RAM disk — writable, loaded from .sram file */
```

**Currently set to 1** (RAM disk). Device 0 (ROM disk) also boots but panics on
login. Device 1 is preferred because it has `imshow`, `levee`, and is writable.

### 3. Blastem SRAM Byte-Swap Difference (DISCOVERED)

**Blastem 0.6.2** (used by developer): byte-swaps SRAM on load/save.
**Blastem 0.6.3.4** (Ubuntu package): does NOT byte-swap SRAM.

The Makefile builds filesystem2 with `-X` (byte-reversed metadata), then creates
`.sram` via `dd conv=swab`. For 0.6.2 this is correct — blastem swaps it back,
producing the `-X` format the kernel expects. For 0.6.3.4, deploy the `.img`
directly instead.

**Tested combinations:**

| `-X` flag | `dd conv=swab` | blastem 0.6.3.4 | Result |
|-----------|----------------|-----------------|--------|
| Yes | Yes | loads .sram | `panic: no root` (double-swap corrupts) |
| Yes | No | loads .img | **BOOTS OK** |
| No | No | loads .img | `panic: no root` (wrong byte order) |

### 4. `fsck` and `remount` in rc (DISABLED)

The `rc` init script originally ran `fsck -a /` and `remount -n / rw`. Both
cause `panic: inode freed.` on this platform. These have been commented out.
The developer's IGNOREME.md also notes: "fsck was messed up, so that needed to
be removed from rc".

### 5. Known Bug: `inode freed` Panic After Login

**Symptom:** Kernel boots, mounts root fs, starts init, shows login prompt,
auto-logs in (with CI_TESTING=1), prints "Welcome to FUZIX." then panics with
`panic: inode freed.` followed by `plt_monitor...`

**When it happens:** Every time the shell is spawned after login. Happens with:
- Both BOOTDEVICE 0 (ROM disk) and 1 (RAM disk)
- Both CONFIG_SPLIT_ID enabled and disabled
- Both manual login and CI_TESTING=1 auto-login
- Both with and without fsck/remount in rc

**Root cause (suspected):** Toolchain mismatch. The port was developed with
`m68k-elf-gcc` 14.2.0 (true bare-metal cross-compiler built from source). The
Ubuntu `m68k-linux-gnu-gcc` 13.3.0 generates code that differs in relocations or
ABI behavior, causing process forking to corrupt inode reference counts.

The panic occurs in `filesys.c:861` in `i_deref()` when `ino->c_refs == 0` —
an inode is being dereferenced that has already been freed. This suggests the
child process created by `fork()` has corrupted memory or the inode table.

**Developer notes from IGNOREME.md:**
- "There is something of about the memory mapping or the program loading"
- "only works if I include this memory space" (the 0xFF0000 block)
- "I split the memory in two while debugging; there is something wrong with
  memory management or executable relocations"
- The TODO mentions "Fix interrupt handling in megadrive.S" and issues at
  `lowlevel-68000.S:784`

**To investigate:** Run under GDB with `blastem -D`, set breakpoint on
`i_deref` and trace which process triggers it, or build the proper m68k-elf-gcc
14.2.0 toolchain.

### 6. `m68k-linux-gnu-gcc` Defines `linux`

The cross-compiler defines `linux` and `__linux__` preprocessor symbols.
`lowlevel-68000.S` has a `#ifdef linux` / `#warning` guard. This is cosmetic —
the generated code is not affected.

### 7. Filesystem Build: `/dev/rd3` Bogus Inode Warning

Every `build-filesystem-ng` run reports:
```
Directory entry /dev/rd3 points to bogus inode 141. Zap? y
Free inode count in superblock block is 291, should be 292. Fix? y
```

This is because the base filesystem package (`basefs`) creates `/dev/rd3` but
the megadrive platform package removes it. The fsck pass fixes this
automatically. This does not affect the resulting filesystem.

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
- `b i_deref` — inode dereference (for debugging the inode freed panic)
- `b dofork` — process fork (for debugging the fork/exec issue)

## Quick Rebuild Cycle

After modifying platform code:

```bash
make -C Kernel TARGET=megadrive VERSION=0 SUBVERSION=4 clean
make -C Kernel TARGET=megadrive VERSION=0 SUBVERSION=4
cp Kernel/fuzix.bin Images/megadrive/fuzix.rom
dd if=Images/megadrive/filesystem.img of=Images/megadrive/fuzix.rom bs=64K seek=1 conv=notrunc
# Then run in blastem
```

**Warning:** `make clean` deletes the `Applications/` directory contents including
`imshow`, `*.simg` files, and the Python venv. To rebuild only the kernel without
losing app artifacts:

```bash
# Clean only kernel objects, not applications
rm -f Kernel/platform/platform-megadrive/*.o Kernel/*.o Kernel/platform/platform-megadrive/fuzix.elf
make -C Kernel TARGET=megadrive VERSION=0 SUBVERSION=4
```

To rebuild the filesystem (after changing packages or adding files):

```bash
cd Standalone/filesystem-src
# ROM filesystem (disk 0):
./build-filesystem-ng -X -f ../../Images/megadrive/filesystem.img -g 64 3968 -p platform-megadrive
# RAM filesystem (disk 1):
./build-filesystem-ng -X -f ../../Images/megadrive/filesystem2.img -g 64 3072 -p platform-megadrive-disk2
```

To inspect filesystem contents:
```bash
Standalone/ucp Images/megadrive/filesystem2.img     # for -X byte-reversed images
Standalone/ucp -b Images/megadrive/filesystem2.sram  # for byte-swapped .sram files
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
├── devvdp.c             /dev/vdp character device for userspace VDP control
├── dbg_output.S         Debug overlay on VDP plane B (toggle with F12)
├── macros.S             Z80 bus control macros
├── control_ports.def    Hardware register addresses
├── rc                   Init script (fsck/remount currently disabled)
├── README.md            Original developer build instructions
├── IGNOREME.md          Developer notes, TODOs, debugging history
├── Applications/
│   ├── imshow.c         Image viewer using VDP planes + sprites
│   ├── imshow_routines.S Assembly routines for VDP image rendering
│   └── image_convert/   Python tool to convert images to .simg format
│       ├── create_image.py  Floyd-Steinberg dithering + K-means quantization
│       └── lena_test.png    Locally-generated test image (when network unavailable)
├── fuzix-platform-megadrive.pkg      ROM disk filesystem package list
└── fuzix-platform-megadrive-disk2.pkg RAM disk filesystem package list
```

## Boot Sequence (Verified)

What actually happens when FUZIX boots (confirmed via screenshots):

```
FUZIX version 0
Copyright (c) 1988-2002 by H.F.Bower, D.Braun, S.Nitschke, H.Peraza
Copyright (c) 1997-2001 by Arcady Schekochikhin, Adriano C. R. da Cunha
Copyright (c) 2013-2015 Will Sowerbutts (will@sowerbutts.com)
Copyright (c) 2014-2025 Alan Cox (alan@tchedpixels.co.uk)
Devboot
Motorola 68000 processor detected.
RAM: 229KB (0038D800-003C6C00)
RAM: 229KB (003C6C00-00400000)
RAM: 64KB (00FF0000-00FFFFFF)
512KiB total RAM, 232KiB available to processes (32 processes max)
Enabling interrupts ... ok.
Mounting root fs (root_dev=1, ro): OK   ← RAM disk mounts successfully
Starting /init
init version 0.9.1

  ^ ^
  n_n   Fuzix 0.5
 >@<        Welcome to Fuzix
  m m

login: root                              ← auto-login with CI_TESTING=1
login: unable to change owner of controlling tty
Welcome to FUZIX.

panic: inode freed.                      ← shell fork/exec fails here
plt_monitor...
```
