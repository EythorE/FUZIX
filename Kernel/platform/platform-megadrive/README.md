# Interrupts
Fuzix uses the mask defined in kernel.def to enable or disable interupts.  
Normally on the mega drive we use:
```
move    #$2700,sr    ; Disable interrupts.
move    #$2300,sr    ; Enable interrupts.
```
However, for Fuzix we are using
```
0x2000 = Supervisor mode, all interrupts
0x0000 = User mode, all interrupts
```

> In the case of the Genesis, IRQ2 is assigned to the external interrupt, IRQ4 is assigned to the horizontal blank interrupt, and IRQ6 is assigned to the vertical blank interrupt. Setting the IPL bits to 3 basically just has external interrupt requests ignored, since it falls in range of IRQ1-3. You would wanna set the IPL bits to 0 or 1 if you wanna use external interrupts.
<https://forums.sonicretro.org/index.php?threads/enabling-and-disabling-interrupts-the-why.42650/>

# TODO
- implement a rom disk to load the kernel from; whatever that means
- Check if backspace can be implemented; return ascii for backspace to tty
- Switch to fuzix based VT; Fuzix has an 8x8 font and some keyboard handling

