# Build
- Change TARGET to megadrive in the top level Makefile
- build the buildtools (see below)
- run:
```shell
export PATH=~/buildtools-m68k-elf/bin:$PATH
make diskimage
blastem Images/megadrive/fuzix.rom
```
- enable the keyboard in blastem (see below)
- choose bootdev 1
- login as root


# Debug
F12 toggles the debug overlay on/off, provided by output.S

debug with blastem:
m68k-elf-gdb -q --tui -ex "target remote | blastem -D Images/megadrive/fuzix.rom"  Kernel/platform/platform-megadrive/fuzix.elf

We can pass CI_TESTING=1 to make to skip the login. make CI_TESTING=1 diskimage && blastem Images/megadrive/fuzix.rom

We can use Standalone/ucp to browse and manipulate a filesystem 
```Standalone/ucp Images/megadrive/filesystem2.img```
Or for the byte-reversed .sram then use ucp -b


## Buildtools
`export PATH=~/buildtools-m68k-elf/bin:$PATH`

### Download
```shell
mkdir -p ~/buildtools-m68k-elf/{src,build}
cd ~/buildtools-m68k-elf/src
wget https://ftp.gnu.org/gnu/binutils/binutils-2.43.tar.gz
tar -xzf binutils-2.43.tar.gz
wget https://ftp.gnu.org/gnu/gcc/gcc-14.2.0/gcc-14.2.0.tar.gz
tar -xzf gcc-14.2.0.tar.gz
sudo apt install libmpc-dev texinfo
```

### binutils
```shell
mkdir ~/buildtools-m68k-elf/build/binutils-2.43
cd ~/buildtools-m68k-elf/build/binutils-2.43
~/buildtools-m68k-elf/src/binutils-2.43/configure --target=m68k-elf --prefix=~/buildtools-m68k-elf/ --disable-nls --disable-werror
make -j4
make install
```

### gcc
```shell
# you can add --without-headers if libgcc.a is not needed,
# (for / % etc in c, __divsi3, __modsi3) and skip target-libgcc
mkdir ~/buildtools-m68k-elf/build/gcc-14.2.0
cd ~/buildtools-m68k-elf/build/gcc-14.2.0
~/buildtools-m68k-elf/src/gcc-14.2.0/configure --target=m68k-elf --prefix=~/buildtools-m68k-elf/ --disable-threads --enable-languages=c --disable-shared --disable-libquadmath --disable-libssp --disable-libgcj --disable-gold --disable-libmpx --disable-libgomp --disable-libatomic --with-cpu=68000
make -j4 all-gcc
make -j4 all-target-libgcc
make install-gcc
make install-target-libgcc
```

### Blastem emulator
For keyboard press escape, go to settings -> system and change IO port 2 device to Saturn Keyboard.  
Press right control in emulator to turn on key capture.
```shell
cd ~/buildtools-m68k-elf/src
cd tar -xf blastem64-0.6.2.tar.gz
ln -s ../src/blastem64-0.6.2/blastem ~/buildtools-m68k-elf/bin/blastem
```

### GDB
Debug with `m68k-elf-gdb -q --tui -ex "target remote | blastem -D build/main.gen" build/main.elf`  
Set `gsettings set org.gnome.mutter check-alive-timeout 0` in gnome to stop the annoying "not responding" pop-up
```shell
sudo apt-get build-dep gdb
cd ~/buildtools-m68k-elf/src
wget https://ftp.gnu.org/gnu/gdb/gdb-15.2.tar.gz
tar -xf gdb-15.2.tar.gz
cd gdb-15.2
./configure --target=m68k-elf --enable-languages=c --enable-tui=yes --prefix=/home/eythor/buildtools-m68k-elf/
make -j3
make install
```
