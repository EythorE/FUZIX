#ifndef _SATURN_KEYBOARD_H
#define _SATURN_KEYBOARD_H

#include <kernel.h>

void keyboard_init(void);
uint8_t keyboard_read(void);

/*
 * Returns the state of modifier keys as a bitmap:
 * Bit 0: Shift
 * Bit 1: Control
 * Bit 2: Alt
 * Bit 3: Caps Lock
 */
uint8_t keyboard_modifiers(void);

#endif /* _SATURN_KEYBOARD_H */
