# MegaDrive OS — Design Plan

## The Problem

FUZIX is a multi-user Unix clone with 30+ platform ports, deep legacy code, and
abstractions for hardware we don't have (banked memory, floppy disks, RS-232).
The Mega Drive port bolts onto this. The result: a forking bug nobody can find
because the interactions between the 68000 platform code and the generic kernel
are too numerous and too subtle. The codebase is not ours to understand — it's
someone else's decades of work.

We don't need multi-user. We don't need login. We don't need file ownership or
permissions. We don't need 30 platform ports. We need a small, single-user OS
for the 68000 that can run GNU tools and is simple enough that one person can
read the entire kernel source in an afternoon.

## Goals

1. **Readable** — The entire kernel fits in your head. Every line has a reason.
2. **Single-user** — No UIDs, no permissions, no login. Like DOS, but with a
   proper syscall interface.
3. **POSIX-enough** — Enough POSIX syscalls that newlib works and GNU tools
   (gcc, as, ld, make, gdb) can be ported without heroics.
4. **No MMU required** — Designed from the start for flat memory, no virtual
   address translation.
5. **Portable to Mega Drive** — The Mega Drive is the final target, but we
   develop on something simpler first.
6. **Small** — Measured in thousands of lines, not tens of thousands.

## Non-Goals

- Multi-user, file permissions, setuid
- Virtual memory, demand paging, swap
- Network stack (maybe someday, not now)
- POSIX compliance certification
- Supporting any CPU other than 68000 (initially)

## Architecture Overview

```
┌─────────────────────────────────────┐
│  User Programs (sh, gcc, make ...)  │
│  Linked with newlib (C library)     │
├─────────────────────────────────────┤
│  TRAP #0 — Syscall Interface        │
├─────────────────────────────────────┤
│  Kernel                             │
│  ┌───────────┬──────────┬────────┐  │
│  │ Process   │ Filesys  │ Device │  │
│  │ Manager   │ (minifs) │ Table  │  │
│  └───────────┴──────────┴────────┘  │
├─────────────────────────────────────┤
│  Platform Abstraction Layer (PAL)   │
│  (console, timer, disk, memory)     │
├─────────────────────────────────────┤
│  Hardware / Emulator                │
└─────────────────────────────────────┘
```

## Phase 1: The Workbench (Emulated 68000 SBC)

### Why not develop directly on the Mega Drive?

The Mega Drive has a VDP (video display processor), no UART, and requires
blastem with Xvfb to test. Every debug cycle involves screenshots. This is
miserable for kernel development.

Instead, we build a trivial 68000 single-board computer in software:

```
Memory Map (Workbench SBC):
  0x000000 - 0x0FFFFF   1MB RAM (ROM at reset, then RAM)
  0xF00000 - 0xF00003   UART (data register + status register)
  0xF10000 - 0xF10003   Timer (count register + control register)
```

**Implementation:** Use **Musashi** (MIT license, C, battle-tested in MAME) as
the CPU core. Wrap it in ~200 lines of C that provides:
- 1MB RAM
- A memory-mapped UART that reads/writes to the host terminal (stdin/stdout)
- A periodic timer interrupt (100 Hz) via `SIGALRM` or similar
- A block device backed by a host file (for the filesystem)

This gives us `./emu68k kernel.bin` — runs in any terminal, no X11, no
framebuffer, instant startup, `printf`-debugging works, GDB host-side debugging
works.

### Why Musashi?

- MIT license, single-file C, no dependencies
- Supports 68000 specifically (not just ColdFire)
- Callback-based: we provide `read_byte`/`write_byte`, it does the rest
- Used in MAME for decades — rock solid
- QEMU's m68k targets 68040/ColdFire, not plain 68000

## Phase 2: The Kernel

### Syscall Interface

Enter kernel via `TRAP #0` with syscall number in `d0`, arguments in `d1-d4`.
Return value in `d0` (negative = errno). This is the standard m68k convention.

**Minimum syscall set for a working system with newlib:**

```
Process:    _exit, exec, waitpid, getpid, brk/sbrk, times
Files:      open, close, read, write, lseek, stat, fstat, unlink,
            rename, mkdir, rmdir, chdir, getcwd
File desc:  dup, dup2, pipe, fcntl (minimal), ioctl (minimal)
Directory:  opendir, readdir, closedir (or getdents)
Signals:    kill, signal/sigaction (basic)
```

That's roughly 30 syscalls. FUZIX implements ~70. Linux has 400+.

**No fork().** This is the critical decision. `fork()` on a no-MMU system is the
source of FUZIX's bug and uClinux's complexity. Instead:

- **`vfork()`** — Child shares parent's memory. Parent sleeps until child calls
  `exec()` or `_exit()`. This is trivial to implement: save parent's registers,
  child runs in parent's stack, on `exec()` restore parent.
- **`posix_spawn()`** — Convenience wrapper. Most shell use is
  `fork()+exec()` anyway.

GNU coreutils, GCC, and make all work with `vfork()+exec()`. This is exactly
what uClinux does and it supports a full GNU toolchain.

### Process Model

**Phase 2a — Single-tasking (week 1-2):**

One process at a time. `exec()` replaces current process. When it exits, the
shell resumes. Like CP/M or DOS. No context switching, no scheduler, no process
table complexity.

This is enough to run: a shell, an editor, a compiler, an assembler, a linker.
Each one at a time. This is how people actually used Unix on PDP-11s with 64KB.

```
Boot → init → shell
  shell: read command → exec(program) → program runs → exits → shell resumes
```

**Phase 2b — Multi-tasking (week 3-4):**

Add a process table (max 8-16 processes), round-robin preemptive scheduling via
timer interrupt, `vfork()+exec()`. Processes get memory from a simple allocator
(first-fit or buddy, from a flat heap).

Binary format: **Position-independent ELF** (`-fPIC -msep-data`) or **bFLT**
(ELF converted via `elf2flt`, like uClinux). PIC is simpler — no relocation
fixups at load time.

### Memory Management

No MMU means no virtual addresses. All processes see physical memory.

```
┌──────────────────┐ 0x000000
│ Interrupt Vectors │
├──────────────────┤ 0x000400
│ Kernel code+data │
├──────────────────┤ ~0x010000 (depends on kernel size)
│ Kernel heap       │ (process table, file table, inodes, buffers)
├──────────────────┤
│ Process memory    │ (allocated chunks for each process)
│ [proc 0: shell]  │
│ [proc 1: gcc]    │
│ [proc 2: as]     │
│ ...              │
├──────────────────┤
│ Free memory       │
└──────────────────┘ top of RAM
```

Allocation: simple linked-list of free blocks. `brk()`/`sbrk()` grows the
current process's data segment. When a process exits, its block returns to the
free list.

No memory protection. A buggy process can corrupt the kernel. This is acceptable
for a single-user development OS. (Same as DOS, same as classic Mac OS, same as
every 8-bit micro.)

### Filesystem

#### What GNU tools actually require from the filesystem

| Requirement | Why | Who needs it |
|-------------|-----|-------------|
| `stat()` with `st_mtime` | Rebuild decisions (is .o newer than .c?) | `make` |
| Temp files: create, write, close, reopen, unlink | Compiler pipeline (cpp→cc1→as→ld communicates via temp files) | GCC |
| Unlink-while-open (deferred delete) | GCC unlinks temp files while child still reads them; data must survive until last fd closes | GCC |
| Atomic `rename()` | Editors/compilers write to temp then rename over target to prevent half-written files | GCC, editors, `install` |
| `lseek()` on files | Random access into object files and archives | `ld`, `ar`, `objcopy` |
| Hierarchical directories with `.` and `..` | Path resolution, `cd ..`, relative paths | Everything |
| Directory listing (`opendir`/`readdir`) | `ls`, `find`, `make` pattern rules, shell globbing | Everything |

#### What we do NOT need

- **Permissions / mode bits** — single user, everything is rwx
- **Owner / group (uid/gid)** — single user
- **Symbolic links** — nice to have, not required by any core tool
- **Multiple filesystem types / mount** — one fs is enough
- **File locking** — advisory anyway, nothing enforces it
- **Sparse files, extended attributes, ACLs** — no

#### Options evaluated

**Option A: Write our own (minifs)** — RECOMMENDED
- Superblock → inode table → data blocks, classic Unix layout
- We control every line, easy to debug, educational
- ~500 lines of C for the kernel side, ~200 for host-side `mkfs`/`fsck`
- See on-disk format below

**Option B: FAT16** — REJECTED
- No `mtime` with second-level precision (FAT timestamps are 2-second granularity)
- No deferred delete (unlink-while-open) — FAT has no inode concept, directory
  entry IS the file metadata. Unlinking means removing the dir entry, which
  breaks any open fd.
- No atomic `rename()` across directories without inode indirection
- These are not obscure features — GCC and make depend on them daily.

**Option C: FUZIX filesystem format** — FALLBACK
- We have working `mkfs`, `ucp`, `fsck` from `Standalone/`
- But: it has permissions, uid/gid, and complexity we don't need
- And: tying our new OS to FUZIX's format defeats the point of starting fresh

#### minifs on-disk format

```
Block 0:        Superblock
Block 1..N:     Inode table (fixed-size inodes)
Block N+1..:    Data blocks

Block size: 1024 bytes (good balance for our RAM constraints)
```

**Superblock (1024 bytes, block 0):**
```c
struct superblock {
    uint32_t magic;          // 0x4D494E49 ("MINI")
    uint16_t block_size;     // 1024
    uint16_t nblocks;        // total blocks in filesystem
    uint16_t ninodes;        // total inodes
    uint16_t free_list;      // head of free block linked list
    uint16_t free_inodes;    // count of free inodes
    uint32_t mtime;          // last mount time
};
```

**Inode (64 bytes):**
```c
struct inode {
    uint8_t  type;           // 0=free, 1=file, 2=dir, 3=device
    uint8_t  nlink;          // hard link count (usually 1)
    uint32_t size;           // file size in bytes
    uint32_t mtime;          // modification time (seconds since epoch)
    uint16_t direct[12];     // 12 direct block pointers → 12KB
    uint16_t indirect;       // single indirect → +512 blocks → 524KB
    uint8_t  pad[14];        // reserved (future: double indirect, ctime)
};
// With 1KB blocks: max file size = 12KB + 512KB = 524KB
// That's enough for any reasonable object file or binary on this platform.
// The entire Mega Drive RAM disk is 1.5MB.
```

**Directory entry (32 bytes):**
```c
struct dirent {
    uint16_t inode;          // inode number (0 = deleted entry)
    char     name[30];       // null-terminated filename
};
// 32 entries per 1KB block. 30-char names (classic Unix was 14).
```

**Free block list:** Each free block starts with a `uint16_t` pointing to the
next free block (0 = end of list). Simple, no bitmap needed.

#### Key filesystem operations

| Operation | Implementation |
|-----------|---------------|
| `open(path)` | Walk directories resolving each component, return inode |
| `read(fd, buf, n)` | Map file offset to block via direct/indirect pointers, copy data |
| `write(fd, buf, n)` | Allocate blocks as needed from free list, update inode size and mtime |
| `unlink(path)` | Remove directory entry, decrement nlink. If nlink==0 AND no open fds, free inode+blocks. If fds still open, defer. |
| `rename(old, new)` | Add new dir entry pointing to same inode, remove old entry. Atomic because it's one inode. |
| `mkdir(path)` | Allocate inode (type=dir), create `.` and `..` entries |
| `stat(path)` | Return inode metadata (type, size, mtime) |

#### Storage on Mega Drive

- **ROM** (read-only, baked into cartridge) — boot filesystem with kernel, shell, core utils
- **SRAM at 0x200000** (read-write, battery-backed) — user filesystem for development, compiler output, etc.

### Device Model

Minimal device table. Everything is a file descriptor.

```c
struct device {
    int (*open)(int minor);
    int (*close)(int minor);
    int (*read)(int minor, void *buf, int len);
    int (*write)(int minor, void *buf, int len);
    int (*ioctl)(int minor, int cmd, void *arg);
};
```

Initial devices:
- `/dev/console` — UART on workbench, VDP+keyboard on Mega Drive
- `/dev/rd0` — ROM disk (read-only)
- `/dev/rd1` — RAM disk (read-write)

### C Library: newlib

newlib is the standard C library for bare-metal m68k-elf targets. It's already
packaged and working. The porting layer is ~15 stub functions:

```c
_read()    → syscall READ
_write()   → syscall WRITE
_open()    → syscall OPEN
_close()   → syscall CLOSE
_sbrk()    → syscall BRK
_exit()    → syscall EXIT
_execve()  → syscall EXEC
_fork()    → return -ENOSYS (use vfork)
_wait()    → syscall WAITPID
_stat()    → syscall STAT
_fstat()   → syscall FSTAT
_link()    → syscall LINK
_unlink()  → syscall UNLINK
_lseek()   → syscall LSEEK
_kill()    → syscall KILL
_getpid()  → syscall GETPID
```

This is a well-documented, well-trodden path. Hundreds of embedded projects
have done exactly this.

## Phase 3: Mega Drive Port

Once the kernel works on the workbench emulator, porting to Mega Drive means
implementing the Platform Abstraction Layer:

```c
// Platform Abstraction Layer — each platform implements these
void     pal_init(void);                    // Hardware init
void     pal_console_putc(char c);          // Write character
int      pal_console_getc(void);            // Read character (blocking)
int      pal_console_ready(void);           // Character available?
void     pal_disk_read(int dev, uint32_t block, void *buf);
void     pal_disk_write(int dev, uint32_t block, void *buf);
uint32_t pal_mem_start(void);               // Start of usable RAM
uint32_t pal_mem_end(void);                 // End of usable RAM
void     pal_timer_init(int hz);            // Start periodic interrupt
```

For the Mega Drive, we already have all of this code from the FUZIX port:
- `devvt.S` — VDP text output (console putc)
- `keyboard.c` / `keyboard_read.S` — Saturn keyboard (console getc)
- `devrd.c` — ROM disk + RAM disk
- `crt0.S` — boot code, vector table
- `megadrive.S` — interrupt handlers, hardware init

We **reuse these drivers directly**. The kernel is new; the drivers are proven.

## Phase 4: GNU Toolchain

With newlib and POSIX syscalls working, porting GNU tools follows the standard
cross-compilation recipe:

1. **Shell** — Port or write a minimal sh (or use `dash`, which is small)
2. **Coreutils** — `ls`, `cat`, `cp`, `mv`, `rm`, `mkdir` — most are trivial
   with POSIX syscalls
3. **make** — Needs `fork`/`vfork`, `exec`, `pipe`, `waitpid`. All provided.
4. **binutils** — `as`, `ld`, `objcopy` — these are portable C, just need
   newlib + POSIX
5. **gcc** — Needs more memory than we probably have (4MB Mega Drive RAM).
   Cross-compile is fine. Native compilation is a stretch goal.
6. **gdb stub** — Implement the GDB remote serial protocol in the kernel.
   ~200 lines. Connect from host GDB over UART (workbench) or blastem
   debug port (Mega Drive).

## Timeline Estimate

| Phase | What | Scope |
|-------|------|-------|
| 1 | Workbench emulator (Musashi + UART + timer + disk) | ~300 lines C |
| 2a | Single-tasking kernel (boot, console, fs, exec) | ~2000 lines C + ~200 asm |
| 2b | Multi-tasking (scheduler, vfork, process table) | ~500 lines C + ~100 asm |
| 3 | Mega Drive PAL (reuse existing drivers) | ~500 lines asm (existing) |
| 4 | Shell + basic coreutils | Port existing code |

**Total new kernel code: ~3000 lines.** Compare to FUZIX kernel: ~15,000 lines
(platform-independent) plus ~2000 lines per platform.

## What We Take From FUZIX

- **Driver code** — VDP, keyboard, RAM disk, ROM disk. Proven, working.
- **Filesystem tools** — `mkfs`, `ucp`, `fsck` from `Standalone/`. Useful even
  if we write our own filesystem format.
- **Build system knowledge** — The Makefile structure, link scripts, ROM
  layout. We know what works.
- **Boot code** — `crt0.S`, vector table, VDP init. Tested on emulator.

## What We Throw Away

- The entire FUZIX generic kernel (~15K lines)
- Multi-user support, permissions, UIDs, login
- Banking/paging memory management
- 30+ platform abstraction layers we don't need
- `fork()` — replaced with `vfork()+exec()`
- Complex inode lifecycle management (the source of our bug)
- The tty layer (we have one console, not a tty multiplexer)

## Why This Will Work

1. **It's been done before.** uClinux runs GNU tools on 68000 with no MMU
   using exactly this architecture (vfork+exec, flat memory, newlib/uClibc).
   We're just doing it smaller and cleaner.

2. **The hard parts are solved.** The Mega Drive drivers work. newlib works on
   m68k-elf. The toolchain exists. We're writing glue, not inventing anything.

3. **Scope is controlled.** 3000 lines of kernel code is auditable. When
   something breaks, you can read the entire kernel to find it. The FUZIX
   "inode freed" bug is unfindable because the kernel is too big and too
   abstract for the time we can invest.

4. **Single-tasking first.** By starting with one process at a time, we
   eliminate the entire class of bugs related to context switching, shared
   state, and concurrent inode access. We add complexity only after the
   simple version works.

## File Structure (Proposed)

```
megadrive-os/
├── emu/                    # Workbench emulator
│   ├── main.c              # Musashi wrapper (RAM + UART + timer + disk)
│   ├── Makefile
│   └── musashi/            # Musashi 68000 core (vendored, MIT)
├── kernel/
│   ├── crt0.S              # Startup, vector table
│   ├── trap.S              # Syscall entry (TRAP #0 handler)
│   ├── main.c              # Kernel init
│   ├── proc.c              # Process management (exec, exit, wait, vfork)
│   ├── fs.c                # Filesystem
│   ├── dev.c               # Device table and dispatch
│   ├── mem.c               # Memory allocator
│   ├── syscall.c           # Syscall dispatch table
│   ├── signal.c            # Basic signal handling
│   └── kernel.h            # All kernel headers (one file)
├── pal/                    # Platform Abstraction Layer
│   ├── pal.h               # PAL interface
│   ├── workbench/          # Workbench SBC platform
│   │   ├── console.c
│   │   ├── disk.c
│   │   └── platform.c
│   └── megadrive/          # Mega Drive platform (from FUZIX drivers)
│       ├── console.S        # VDP text output
│       ├── keyboard.c
│       ├── keyboard_read.S
│       ├── disk.c           # ROM/RAM disk
│       ├── vdp.S
│       └── platform.c
├── libc/                   # newlib syscall stubs
│   ├── syscalls.c          # _read, _write, _sbrk, etc.
│   ├── crt0.S              # User-mode startup
│   └── Makefile
├── apps/                   # Userspace
│   ├── init.c
│   ├── sh.c                # Minimal shell
│   └── ...
└── Makefile                # Top-level build
```

## Decision Log

| Decision | Choice | Reasoning |
|----------|--------|-----------|
| Start from scratch vs. fix FUZIX | From scratch | FUZIX is 15K+ lines of someone else's kernel. The bug is in the interaction between generic code and platform code. Cheaper to write 3K lines we understand. |
| fork() vs vfork() | vfork only | fork() on no-MMU is the root cause of our problems. vfork+exec is proven (uClinux) and sufficient for GNU tools. |
| Development platform | Musashi-based SBC emulator | Terminal I/O, instant startup, host-side debugging. Mega Drive requires Xvfb and screenshots. |
| C library | newlib | Standard m68k-elf support, well-documented porting, small footprint. |
| Filesystem | Custom simple fs (minifs) | Educational value, minimal code, exactly the features we need. Fallback to FUZIX fs format if needed. |
| Single-tasking first | Yes | Eliminates entire classes of bugs. Add multitasking after everything else works. |
| Binary format | PIC ELF or bFLT | Standard for no-MMU systems. elf2flt is maintained. |
| Process limit | 8-16 | Mega Drive has 512KB RAM for kernel + processes. Each process needs at minimum ~8KB (4KB stack + 4KB data). 16 processes × 8KB = 128KB. Reasonable. |

## Open Questions

1. **Musashi vs. Moira?** Musashi is C (easier to build), Moira is C++20 (more
   accurate). For kernel development, accuracy doesn't matter — we need
   correctness at the instruction level, not cycle-level timing. **Musashi.**

2. **Shell: write or port?** Writing a minimal shell (~500 lines) is educational
   and removes a dependency. Porting `dash` is faster but larger. Start with
   a minimal shell, port `dash` later.

3. **GDB support: when?** Implementing the GDB remote serial protocol in the
   kernel (~200 lines) would give us source-level debugging on the workbench
   emulator via the UART. Worth doing early (phase 2a) because it pays for
   itself immediately in debug productivity.

## Next Steps

1. Set up repo structure
2. Vendor Musashi, build the workbench emulator
3. Write `crt0.S` + `trap.S` + kernel `main.c` — boot to a `>` prompt
4. Implement `read`/`write`/`open`/`close` syscalls with console device
5. Implement filesystem (minifs) with ROM disk
6. Implement `exec()` — load and run a program from the filesystem
7. Write minimal shell
8. Celebrate: we have a working OS
