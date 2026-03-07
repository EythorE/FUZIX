# FUZIX Mega Drive Port — Technical Analysis

## What This Is

This is a port of FUZIX (a lightweight POSIX-ish Unix clone descended from UZI
and V7 Unix) to the Sega Mega Drive / Genesis. It runs a real multi-process
operating system with a filesystem, shell, and userspace programs on a game
console from 1988, using the Motorola 68000 CPU at 7.67 MHz with 64KB of onboard
RAM and additional cartridge SRAM.

The port is approximately 2,300 lines of platform-specific code (1,600 lines of
68000 assembly, 700 lines of C) sitting on top of ~17,000 lines of generic FUZIX
kernel code. It boots to a login prompt, runs a shell, and can execute programs
including a vi clone (levee), games, and a custom image viewer that renders
dithered images through the VDP.


## Architecture Overview

### Boot Sequence

The 68000 reads its initial stack pointer and program counter from address 0x0 on
power-on. The ROM header at offset 0x0 in `crt0.S` provides these, along with
the full 256-entry exception vector table mapping hardware interrupts, traps, and
bus errors to handler functions.

Boot proceeds through `CPU_EntryPoint` in this order:

1. **TMSS handshake** (`VDP_WriteTMSS`): Writes "SEGA" to 0xA14000 on model 1+
   consoles to unlock the VDP. Without this, the VDP stays locked and nothing
   appears on screen.

2. **VDP initialization** (`VDP_LoadRegisters`, `VDP_ClearVRAM`): Writes 24
   register values to configure display mode (H40 = 320px wide, V28 = 224px
   tall), enable DMA, set nametable addresses, sprite table location, and
   auto-increment. Clears all 64KB of VRAM to prevent garbage on screen.

3. **Interrupts disabled** (`move.w #0x2700,sr`): Mask all interrupts during
   setup.

4. **Palette and font loaded** (`VDP_writePallete`, `fontInit`): Writes 4
   palettes (16 colors each) to CRAM. The font loader is particularly clever — it
   converts FUZIX's 1-bit-per-pixel 8x8 font into the VDP's 4-bit-per-pixel tile
   format on the fly using `roxl` (rotate through extend) to expand each bit into
   a nibble, then adds `0x11111111` to make the background color non-transparent
   (palette index 1 instead of 0).

5. **Keyboard initialized** (`keyboard_init`): Configures I/O port 2 for Saturn
   keyboard protocol by writing 0x60 to the control and data registers.

6. **Data section copied** (`init_data`): Copies initialized data from ROM
   (stored after the `.rodata` section) to RAM at 0x380000, then clears BSS. This
   is necessary because the 68000's writable RAM is in the cartridge SRAM region,
   not in ROM.

7. **Kernel entry**: Sets the stack pointer to the top of the first udata block,
   calls `init_early` (sets up the udata shadow pointer), `init_hardware`
   (declares 512KB RAM, 232KB available to processes, initializes the VT
   subsystem), then `fuzix_main` which is the generic kernel entry point.

### What's Missing From the Boot (and Why It Breaks Real Hardware)

The boot sequence is missing several steps that emulators handle automatically
but real hardware requires.

**Z80 initialization:** The Z80 co-processor shares the bus with the 68000 and
starts executing random code from its uninitialized RAM on power-on. Every
commercial Mega Drive game requests the Z80 bus, holds the Z80 in reset, and
either loads a sound driver or leaves it halted. Without this, the Z80 can
arbitrarily stall the 68000 by holding the bus during cartridge ROM/SRAM access,
causing seemingly random crashes and data corruption. Blastem initializes the Z80
to a safe state automatically.

**SRAM enable:** The cartridge address space 0x200000–0x3FFFFF is dual-mapped —
it can be either the upper 2MB of ROM or battery-backed SRAM, controlled by the
mapper register at 0xA130F1. On real hardware, SRAM is disabled by default and
ROM occupies this range. Writing 0x01 to 0xA130F1 enables SRAM for read/write.
Blastem reads the ROM header's SRAM declaration and auto-enables it. Since the
kernel's entire data section, BSS, heap, and the RAM disk all live in this SRAM
region, failing to enable it means `init_data` writes go nowhere and the kernel
runs with uninitialized data.

**I/O port initialization:** Controller port control registers need 0x40 written
to them for correct button state reads on real hardware.

**PSG silencing:** The SN76489 sound chip is uninitialized and may produce noise.

**ROM checksum:** Hardcoded to 0x0000. Some console revisions verify this.


### Memory Map

The linker script (`fuzix.ld`) defines four memory regions:

```
rom      0x000000 – 0x00FFFF   64KB    Kernel code, ROM header, rodata
rom_disk 0x010000 – 0x1FFFFF   1.9MB   Read-only filesystem (/dev/rd0)
rom_disk 0x200000 – 0x37FFFF   1.5MB   Read-write filesystem (/dev/rd1)
ram      0x380000 – 0x3FFFFF   512KB   Kernel .data, .bss, heap
```

Plus the 68000's internal 64KB RAM at 0xFF0000–0xFFFFFF, which is registered as
a third memory block in `pagemap_init`. The developer notes indicate this block
is mysteriously required for stability — the comment "only works if I include
this memory space???" suggests the flat memory allocator may have a bug or
assumption about needing a high-address block.

The initial stack pointer is set to 0xFFE000 (in the internal RAM), but this is
quickly replaced with the udata block stack during `start`.

### Process Model

FUZIX on the Mega Drive uses the "flat" memory model (`CONFIG_FLAT`). There is no
MMU, no memory protection, and no virtual addressing. All processes share a
single flat address space.

The memory allocator in `mm/flat.c` manages a pool using `kmalloc`/`kfree`. Each
process can use up to 14 memory blocks (`MAX_BLOCKS`). When `fork()` is called,
the parent's memory is physically copied to new allocations for the child (there
is no copy-on-write). `CONFIG_PARENT_FIRST` is set, meaning the parent runs
first after fork and the child's stack frame is constructed manually in
`dofork` (`68000flat.S`).

Each process has a 1024-byte `udata` block (`UBLOCK_SIZE`) containing the kernel
stack, syscall state, signal vectors, and process metadata. These are statically
allocated as `u_block udata_block[PTABSIZE]` (32 entries) in `main.c`.

A global `udata_shadow` pointer (in `lowlevel-68000.S`) points to the currently
running process's udata. Register A5 is used as the udata pointer throughout the
kernel. On context switch (`switchin` in `68000flat.S`), A5 and `udata_shadow`
are updated to point to the new process's udata, and the stack pointer is
restored from the saved state.


### System Calls

Userspace programs invoke system calls via `TRAP #12`. The vector table in
`crt0.S` maps TRAP 12 to `e_trap12` in `lowlevel-68000.S`.

The syscall convention is:
- D0: syscall number
- D1: arg1, A0: arg2, A1: arg3, A2: arg4
- Return: D0 = return value, D1 = errno (if error)

`e_trap12` saves minimal state (just A5), sets up the udata fields
(`u_callno`, `u_insys`, `u_argn`), saves the user stack pointer, enables
interrupts, calls `unix_syscall` (generic C handler), then checks for pending
signals before returning via `RTE`.

### Interrupt Handling

The VDP generates two interrupts:

**Vertical interrupt (IRQ6)** at `INT_VInterrupt` in `megadrive.S` — fires once
per frame (50Hz PAL, 60Hz NTSC). This is the system's heartbeat. It:
1. Saves volatile registers (A0-A1, A5, D0-D1)
2. Loads the udata shadow into A5
3. Sets `u_ininterrupt` flag
4. Calls `timer_interrupt` (generic kernel timer tick) and `tty_interrupt`
   (polls the Saturn keyboard)
5. Checks `need_resched` for preemptive scheduling — if a reschedule is needed
   and the process wasn't in a syscall, it marks the current process as
   `P_READY` and calls `switchout`
6. Checks for pending signals and dispatches them via `exception()`
7. Restores registers and returns via `RTE`

**Horizontal interrupt (IRQ4)** at `INT_HInterrupt` — currently just `RTE`
(no-op). Could be used for raster effects.

The preemption check (`no_preempt` path) ensures the kernel is never preempted
mid-syscall — only userspace code gets preempted. This is correct for a
non-reentrant kernel.


### Video Display

FUZIX uses the VDP's Plane A for the text console. The VDP is configured in H40
mode (40 cells × 28 cells = 320×224 pixels). Each cell is an 8×8 tile, giving a
40×28 character terminal.

**Tile mapping:** The font's 256 characters are stored as tiles starting at VRAM
address 0x0000. Each character maps directly to a tile index. Plane A's nametable
is at VRAM 0xC000. Writing a tile index to the nametable displays that character.

**Scrolling:** When the screen needs to scroll, `scroll_up` in `devvt.S` doesn't
copy VRAM — instead it adjusts the VDP's vertical scroll register (VSRAM) and
clears the newly exposed row. This is much faster than copying 40×28 tiles. The
`scroll_amount` variable tracks the current scroll offset, and all Y coordinate
calculations mask with 0x1F (mod 32) to wrap around the nametable.

**Cursor:** Uses a hardware sprite (Sprite 0) positioned over the current
character. `cursor_on` reads the character under the cursor position via
`read_cursor_char` (a VRAM read), then positions the sprite. `cursor_off` hides
the sprite by moving it offscreen.

**Debug overlay:** A separate debug plane (Plane B) can be toggled with F12. It
uses palette 1 (different colors) and has its own cursor/scroll tracking. The
`dbg_printf` function supports format specifiers `%c`, `%b` (byte hex), `%w`
(word hex), `%l` (long hex), and `%s` (string). This is invaluable for debugging
on real hardware where you can't attach GDB.

**VDP device (`/dev/vdp`):** A character device at major 8 that allows userspace
programs to directly control the VDP. Currently supports `VDPCLEAR` and
`VDPRESET` ioctls. The `imshow` application uses this plus direct assembly
routines (`imshow_routines.S`) to render images using all four palettes and
multiple planes with sprite overlays — this is how the Lena dithering works.


### Keyboard Input

The keyboard driver implements the Saturn keyboard protocol, which is a
bit-banged serial protocol on I/O port 2.

**Low-level** (`keyboard_read.S`): The `ReadKeyboard` function pauses the Z80
(to prevent bus conflicts), then performs a handshake with the keyboard by
toggling the TH line (bit 5 of the data port) and reading back nibbles. A
complete packet is 12 nibbles containing device type, make/break status, and
scancode. Timing loops (`dbf` with a counter of 127) provide timeouts for
non-responsive hardware.

**High-level** (`keyboard.c`): Maintains modifier state (shift, ctrl, alt, caps
lock) and translates Saturn scancodes to ASCII using a 512-byte lookup table (256
unshifted + 256 shifted). Special keys (F1-F12, arrows, etc.) are mapped to
FUZIX keycode constants. `CTRL+letter` generates the corresponding control
character.

**Polling model:** The keyboard is polled on every vertical interrupt (50/60 Hz)
via `tty_interrupt` → `keyboard_read()`. If a key is detected, it's fed into the
TTY subsystem via `tty_inproc(1, c)`. F12 is intercepted to toggle the debug
overlay.


### Block Devices

Two block devices using a unified driver (`devrd.c`):

- `/dev/rd0` (minor 0): ROM disk at 0x010000, 1.9MB, read-only. This is the root
  filesystem, baked into the ROM image during `make diskimage`. Contains the base
  system: `/bin`, `/etc`, `/dev`, shell, core utilities.

- `/dev/rd1` (minor 1): RAM disk at 0x200000, 1.5MB, read-write. Stored in
  cartridge SRAM. Contains additional programs, images, and writable space.
  Persists across power cycles (battery-backed on real carts). For blastem, the
  SRAM file is byte-swapped (the `.sram` file uses 16-bit little-endian byte
  order vs the 68000's big-endian).

Block I/O uses `copy_blocks` from `lowlevel-68000.S` — an unrolled `movem.l`
loop that copies 512 bytes at a time using all data and address registers (48
bytes per `movem.l` pair, 10.6 pairs per block). This is as fast as the 68000 can
move data.


### Filesystem

Two filesystem images are built by `build-filesystem-ng`:

1. **ROM filesystem** (`filesystem.img`): Built from `fuzix-platform-megadrive.pkg`.
   Includes the base FUZIX filesystem (`basefs`), minimal utilities
   (`util-mini`), V7 commands, the Bourne shell, and V7 games. Byte order is
   reversed (`-X` flag) because the FUZIX filesystem format expects the opposite
   endianness from the 68000 for historical reasons.

2. **RAM filesystem** (`filesystem2.img`): Built from
   `fuzix-platform-megadrive-disk2.pkg`. Includes the full utility set, levee (vi
   clone), the `imshow` image viewer, and test images. This is additionally
   byte-swapped via `dd conv=swab` to create the `.sram` file because blastem
   stores SRAM in 16-bit little-endian format.

The `rc` init script runs `fsck -a /` on boot and remounts the root filesystem
read-write.


### Context Switching (68000flat.S)

This is the most intricate part of the platform code.

**`plt_switchout`:** Saves the current process state — pushes the user stack
pointer and callee-saved registers (A2-A4, A6, D2-D7) onto the kernel stack, then
stores the stack pointer in `u_sp`. Calls `getproc` to find the next runnable
process, then calls `switchin`.

**`switchin`:** Receives a process table pointer, loads its udata into A5,
verifies `u_ptab` matches (panic on mismatch), updates `udata_shadow`, restores
the saved stack pointer, marks the process as `P_RUNNING`, calls
`pagemap_switch`, restores registers, restores the user stack pointer, and
returns. If the process was interrupted (not in a syscall), interrupts are
re-enabled based on `EI_MASK`.

**`dofork`:** The most complex function. It:
1. Copies the parent's entire 1024-byte udata to the child
2. Calls `makeproc` to set up the child's process table entry
3. Manually constructs a return frame at the top of the child's kernel stack
   that mirrors the parent's trap frame (status register + PC, plus vector word
   on 68010+)
4. Pushes a return address pointing to `forkreturn`
5. Pushes a fake `switchout` register save frame
6. Stores the constructed stack pointer in the child's `u_sp`
7. Returns to the parent with the child's PID

When the child is eventually scheduled, `switchin` restores the constructed
frame, which pops into `forkreturn`, which clears all registers (to prevent
kernel data leakage), restores A5, and does an `RTE` to the same userspace
address the parent was at.


## Known Bugs and Issues

### The 0xFF0000 Mystery

The developer notes in `main.c` say the system "only works if I include this
memory space" (the 68000's internal 64KB RAM). The `pagemap_init` function
registers three memory blocks: two halves of cartridge SRAM at 0x380000 and one
at 0xFF0000. The comment "I split the memory in two while debugging; there is
something wrong with memory management or executable relocations" suggests a
deeper issue.

This could be caused by the flat memory allocator needing memory in a specific
address range for process loading — the `doexec` path uses `RTE` to jump to
userspace, and the return address needs to be in an executable region. Or there
may be alignment issues with the 512-byte block allocator when all memory is
contiguous. Needs investigation with GDB breakpoints on `kmalloc` and
`pagemap_alloc`.

### CONFIG_SPLIT_ID

The config file has `CONFIG_SPLIT_ID` both defined and immediately undefined:
```c
#define CONFIG_SPLIT_ID
#undef CONFIG_SPLIT_ID
```
When enabled, the memory manager separates code and data into different blocks.
The comment says "when we dont split instruction data, we do run into bus errors,
potentially word mis-aligned instruction." But it's currently disabled. This
might be related to the 0xFF0000 mystery — enabling split I/D might fix the
memory issue but introduce alignment problems elsewhere.

### VDP Read Compatibility

The `read_cursor_char` function does a VRAM read that blastem 0.6.3 rejects as
invalid. The VDP data port requires that the access mode (set via the control
port) matches the operation. If the prior VDP command was a write, reading the
data port is invalid. The fix is to read the VDP status register (which resets
the command word latch) before issuing the VRAM read command.

### Byte-Width SRAM Access

The `copy_blocks` function uses `movem.l` for 32-bit bulk transfers to/from the
RAM disk at 0x200000. On real hardware with 8-bit SRAM (standard for Mega Drive
cartridges), this will fail — SRAM is typically wired to only the lower data byte
(odd addresses). The Mega Everdrive Pro has 16-bit SRAM so this may work, but the
open-source Everdrive designs use 8-bit SRAM. A byte-width copy routine would be
needed for those platforms, which would be significantly slower.

### Interrupt Edge Cases

The `INT_VInterrupt` handler's signal dispatch path has a `FIXME: this is ugly`
comment. When a signal is pending, it pops the saved registers, pushes a new
exception frame with all registers for `exception()`, then does an `RTE` back to
the modified signal handler. This works but the stack manipulation is fragile and
may break if the kernel is built with different optimization flags.


## What Needs To Be Done

### Priority 1: Boot on Real Hardware

These are required to boot on a real Mega Drive with a Mega Everdrive Pro.

**Add Z80 initialization to `crt0.S`.** ~15 lines of assembly at the start of
`CPU_EntryPoint`. Request the Z80 bus, hold it in reset, wait for bus grant.
This alone may fix the boot issue. Estimated time: 30 minutes to implement,
1 hour to test.

**Add SRAM enable.** Write 0x01 to 0xA130F1 early in boot, or use the Mega
Everdrive Pro's SSF mapper protocol (0x8000 to 0xA130F0). This could be
behind a `#ifdef EVERDRIVE_PRO` if needed. Test by verifying that `init_data`
successfully copies data to 0x380000. Estimated time: 30 minutes + testing.

**Initialize I/O ports.** Write 0x40 to 0xA10009, 0xA1000B, and 0xA1000D.
Without this, gamepad reads return wrong data on real hardware, which shouldn't
affect boot but will affect the keyboard. Estimated time: 15 minutes.

**Silence the PSG.** Write 0x9F, 0xBF, 0xDF, 0xFF to 0xC00011 (mute all four
channels). Cosmetic but annoying without. Estimated time: 10 minutes.

### Priority 2: Fix the VDP Read

Fix `read_cursor_char` in `devvt.S` to properly set up a VRAM read command.
The correct sequence is:
1. Read VDP status register (0xC00004) to reset the command word latch
2. Write the VRAM read command to the control port
3. Wait at least 8 68000 cycles for the VDP to fill the read buffer
4. Read from the data port

This fixes compatibility with blastem 0.6.3+ and is also correct behavior
for real hardware. Estimated time: 1 hour.

### Priority 3: Investigate Memory Issues

**Debug the 0xFF0000 dependency.** Run under GDB (`blastem -D`), set breakpoints
on `kmalloc` and `pagemap_alloc`, and trace which allocations land in which
memory regions. Test with the 0xFF0000 block removed and identify which
allocation fails. This will likely reveal whether it's an address range
requirement, an alignment issue, or a pool size problem.

**Test CONFIG_SPLIT_ID.** Re-enable it and trace bus errors. If the code/data
split causes word-alignment issues, the relocator (`68000relocate.c`) may need
fixes. This config should theoretically save memory by sharing code across
forked processes.

**Investigate the halved memory blocks.** The comment says "I split the memory
in two while debugging" but the split is still in place. Try using a single
`kmemaddblk` call for the full cartridge SRAM range and see what breaks.

Estimated time: 4–8 hours for all three.

### Priority 4: ROM Checksum

Add a post-build step that calculates the correct Mega Drive ROM checksum (sum
of all 16-bit words from offset 0x200 to end of ROM) and patches it into offset
0x18E. This can be a small C program or a Python script added to the Makefile.
Some console revisions check this. Estimated time: 1–2 hours.

### Priority 5: Open-Source Everdrive Support

If targeting an open-source Everdrive with 8-bit SRAM:

**Write a byte-width block copy routine.** Replace `copy_blocks` with a version
that does byte reads/writes for the 0x200000 region. This will be 4-8x slower
than `movem.l` but necessary for compatibility.

**Handle SRAM odd-byte addressing.** Standard Mega Drive SRAM is wired to odd
addresses only. The filesystem image would need to be stored with only odd bytes
populated, and the block driver would need to handle the address translation.

**Standard mapper support.** Use 0xA130F1 writes (bit 0 = enable, bit 1 = write
protect) instead of the Everdrive Pro's SSF mapper.

Estimated time: 2–4 hours for byte-width I/O, 4–8 hours for full odd-byte
filesystem support.

### Priority 6: Quality of Life

**Add `CONFIG_MULTI` support.** Currently disabled. Enabling true multitasking
would allow background processes, but the interrupt handler's preemption path
needs testing.

**Fix `WaitZ80` macro.** The macro references a label `wait_z80` that doesn't
exist. Should use a local label. Currently unused but should be fixed.

**Add termcap/curses support.** The developer notes mention wanting this. The
VT52 terminal emulation is already in place; adding a termcap entry would let
curses-based programs (like the 2048 game) work properly.

**Create a `/dev/vdp` library.** The `imshow` application uses raw assembly to
talk to the VDP. A proper `libvdp` with C wrappers for palette setting, tile
loading, plane manipulation, and sprite control would make VDP programming
accessible from userspace C programs.


## Code Map

### Platform-Specific Assembly (1,600 lines)

| File | Lines | Purpose |
|------|-------|---------|
| `crt0.S` | 236 | Vector table, ROM header, CPU entry, data init |
| `megadrive.S` | 138 | Platform init, interrupt handlers, idle, reboot |
| `devvt.S` | 234 | VDP text console: plot_char, scroll, cursor, clear |
| `vdp.S` | 332 | VDP hardware init: TMSS, registers, VRAM, palette, font |
| `dbg_output.S` | 456 | Debug overlay on Plane B, printf-like formatting |
| `keyboard_read.S` | 96 | Saturn keyboard low-level protocol |
| `font_init.S` | 50 | 1bpp → 4bpp font conversion and VRAM upload |
| `macros.S` | 51 | Z80 bus control macros |

### Platform-Specific C (700 lines)

| File | Lines | Purpose |
|------|-------|---------|
| `main.c` | 94 | Memory pool init, udata blocks, install_vdso |
| `keyboard.c` | 252 | Scancode → ASCII translation, modifier state |
| `devrd.c` | 105 | ROM/RAM disk block device driver |
| `devtty.c` | 103 | TTY glue: kputchar, tty_putc, tty_interrupt |
| `config.h` | ~100 | Platform config constants |
| `devices.c` | 47 | Device switch table |
| `devvdp.c` | 38 | /dev/vdp character device |
| `libc.c` | 52 | memcpy, memcpy32 |
| `dbg.c` | 9 | Debug helpers |

### Key Generic Kernel Files

| File | Purpose |
|------|---------|
| `cpu-68000/lowlevel-68000.S` | Syscall entry, exception handlers, doexec, copy_blocks |
| `lib/68000flat.S` | switchout, switchin, dofork, forkreturn |
| `lib/68000exception.c` | Signal dispatch from exception frames |
| `lib/68000relocate.c` | ELF flat binary relocation for process loading |
| `mm/flat.c` | Flat memory allocator (kmalloc-based, no MMU) |
| `vt.c` | Generic VT52 terminal emulation |
| `process.c` | Process lifecycle, scheduling |
| `filesys.c` | Filesystem operations |

### Build Artifacts

| File | Purpose |
|------|---------|
| `fuzix.ld` | Linker script: ROM/RAM/SRAM regions |
| `kernel.def` | Interrupt mask constants, CONFIG_PLT_VECTORS |
| `control_ports.def` | Hardware register addresses |
| `fuzix-platform-megadrive.pkg` | ROM disk filesystem package list |
| `fuzix-platform-megadrive-disk2.pkg` | RAM disk filesystem package list |
| `rc` | Init script (fsck, remount rw) |
