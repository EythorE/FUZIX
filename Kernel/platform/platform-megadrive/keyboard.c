#include <kernel.h>
#include <tty.h>
#include <keycode.h>

#define SCANCODE_LEFT_ALT    0x11
#define SCANCODE_RIGHT_ALT   0x17
#define SCANCODE_LEFT_SHIFT  0x12
#define SCANCODE_RIGHT_SHIFT 0x59
#define SCANCODE_LEFT_CTRL   0x14
#define SCANCODE_RIGHT_CTRL  0x18
#define SCANCODE_CAPS_LOCK   0x58

extern void initKeyboard(void);
extern int ReadKeyboard(void);
extern uint8_t scancode_buffer[12];

static bool shift_down = false;
static bool ctrl_down = false;
static bool alt_down = false;
static bool caps_lock = false;


/* keyboard_read.S */
extern const uint8_t saturn_keymap[];


void keyboard_init(void) {
    shift_down = false;
    ctrl_down = false;
    alt_down = false;
    caps_lock = false;
    
    /* Initialize the keyboard hardware */
    initKeyboard();
}

/*
 * Update modifier key state based on scancode
 * Returns true if the keypress was a modifier key
 */
static bool update_modifiers(uint8_t scancode, bool is_make) {
    bool is_modifier = true;
    
    switch (scancode) {
        case SCANCODE_LEFT_SHIFT:
        case SCANCODE_RIGHT_SHIFT:
            shift_down = is_make;
            break;
            
        case SCANCODE_LEFT_CTRL:
        case SCANCODE_RIGHT_CTRL:
            ctrl_down = is_make;
            break;
            
        case SCANCODE_LEFT_ALT:
        case SCANCODE_RIGHT_ALT:
            alt_down = is_make;
            break;
            
        case SCANCODE_CAPS_LOCK:
            if (is_make) {
                /* Toggle caps lock on press (not on release) */
                caps_lock = !caps_lock;
            }
            break;
            
        default:
            is_modifier = false;
            break;
    }
    
    return is_modifier;
}

/*
 * Apply caps lock to a character if it's a letter
 */
static uint8_t apply_caps_lock(uint8_t keycode) {
    /* Only apply caps lock to alphabetic characters */
    if ((keycode >= 'a' && keycode <= 'z') || (keycode >= 'A' && keycode <= 'Z')) {
        if (keycode >= 'a' && keycode <= 'z') {
            return keycode - 32;  /* Convert to uppercase */
        } else {
            return keycode + 32;  /* Convert to lowercase */
        }
    }
    return keycode;
}

/*
 * Apply control key modifier to a keycode
 */
static uint8_t apply_ctrl(uint8_t keycode) {
    /* Only apply ctrl to letters and a few special characters */
    if (keycode >= 'a' && keycode <= 'z') {
        return CTRL(keycode);
    } else if (keycode >= 'A' && keycode <= 'Z') {
        return CTRL(keycode + 32);  /* Convert to lowercase first */
    }
    
    /* Handle special cases for control characters */
    switch (keycode) {
        case '@':  return CTRL('@');  /* Null character */
        case '[':  return CTRL('[');  /* Escape */
        case '\\': return CTRL('\\'); /* File separator */
        case ']':  return CTRL(']');  /* Group separator */
        case '^':  return CTRL('^');  /* Record separator */
        case '_':  return CTRL('_');  /* Unit separator */
    }
    
    return keycode;
}

/*
 * Read a key from the keyboard, handling modifiers and special keys
 * Returns the keycode or 0 if no key was pressed
 */
uint8_t keyboard_read(void) {
    int result;
    uint8_t make_break, scancode, keycode;
    bool is_make;

    /* Read a keyboard packet */
    result = ReadKeyboard();
    if (result != 0) {
        return 0;  /* No key or error */
    }
    
    /* Extract make/break bit from packet */
    make_break = scancode_buffer[7];
    is_make = (make_break & 0x08) != 0;
    
    /* Extract scancode from packet */
    scancode = (scancode_buffer[8] << 4) | scancode_buffer[9];
    // extern void dbg_printf(char s[], ...);
    // if (scancode != 0)
    //     dbg_printf("scancode: %b\n", scancode);
    
    /* Check if it's a modifier key and update state */
    if (update_modifiers(scancode, is_make)) {
        return 0;  /* Don't return codes for modifier keys */
    }

    /* Only process key-down events for non-modifiers */
    if (!is_make) {
        return 0;
    }
    
    if (shift_down) {
        /* Shifted keycodes are in the second half */	
        keycode = saturn_keymap[scancode + 256];
    } else {
        keycode = saturn_keymap[scancode];
    }
    
    if (caps_lock) {
        keycode = apply_caps_lock(keycode);
    }
    
    if (ctrl_down) {
        keycode = apply_ctrl(keycode);
    }
    
    return keycode;
}

/*
 * Returns the state of modifier keys
 */
uint8_t keyboard_modifiers(void) {
    uint8_t mods = 0;
    if (shift_down) mods |= 1;
    if (ctrl_down)  mods |= 2;
    if (alt_down)   mods |= 4;
    if (caps_lock)  mods |= 8;
    return mods;
}

/*
 * Keycode mapping for Saturn keyboard
 * First 256 bytes are unshifted values, next 256 bytes are shifted values
 * https://plutiedev.com/saturn-keyboard#scancode-to-ascii
 */
const uint8_t saturn_keymap[] = {
    /* Unshifted keys (0x00-0xFF) */
    0,    KEY_F9, 0,    KEY_F5, KEY_F3, KEY_F1, KEY_F2, KEY_F12,    // 0x00-0x07
    0,    KEY_F10, KEY_F8, KEY_F6, KEY_F4, KEY_TAB, '`',  0,    // 0x08-0x0F
    0,    0,    0,    0,    0,    'q',  '1',  0,    // 0x10-0x17
    0,    KEY_ENTER, 'z',  's',  'a',  'w',  '2',  0,    // 0x18-0x1F
    0,    'c',  'x',  'd',  'e',  '4',  '3',  0,    // 0x20-0x27
    0,    ' ',  'v',  'f',  't',  'r',  '5',  0,    // 0x28-0x2F
    0,    'n',  'b',  'h',  'g',  'y',  '6',  0,    // 0x30-0x37
    0,    0,    'm',  'j',  'u',  '7',  '8',  0,    // 0x38-0x3F
    0,    ',',  'k',  'i',  'o',  '0',  '9',  0,    // 0x40-0x47
    0,    '.',  '/',  'l',  ';',  'p',  '-',  0,    // 0x48-0x4F
    0,    0,    '\'', 0,    '[',  '=',  0,    0,    // 0x50-0x57
    0,    0,    KEY_ENTER, ']',  0,    '\\', 0,    0,    // 0x58-0x5F
    0,    0,    0,    0,    0,    0,    KEY_BS, 0,    // 0x60-0x67
    0,    '1',  0,    '4',  '7',  0,    0,    0,    // 0x68-0x6F
    '0',  '.',  '2',  '5',  '6',  '8',  KEY_ESC, 0,    // 0x70-0x77
    KEY_F11,    '+',  '3',  '-',  '*',  '9',  0,    0,    // 0x78-0x7F
    '/',  KEY_INSERT, KEY_PAUSE, KEY_F7, KEY_PRINT, KEY_DEL, KEY_LEFT, KEY_HOME,  // 0x80-0x87
    KEY_END, KEY_UP, KEY_DOWN, KEY_PGUP, KEY_PGDOWN, KEY_RIGHT, 0, 0,    // 0x88-0x8F
    0,    0,    0,    0,    0,    0,    0,    0,    // 0x90-0x97
    0,    0,    0,    0,    0,    0,    0,    0,    // 0x98-0x9F
    0,    0,    0,    0,    0,    0,    0,    0,    // 0xA0-0xA7
    0,    0,    0,    0,    0,    0,    0,    0,    // 0xA8-0xAF
    0,    0,    0,    0,    0,    0,    0,    0,    // 0xB0-0xB7
    0,    0,    0,    0,    0,    0,    0,    0,    // 0xB8-0xBF
    0,    0,    0,    0,    0,    0,    0,    0,    // 0xC0-0xC7
    0,    0,    0,    0,    0,    0,    0,    0,    // 0xC8-0xCF
    0,    0,    0,    0,    0,    0,    0,    0,    // 0xD0-0xD7
    0,    0,    0,    0,    0,    0,    0,    0,    // 0xD8-0xDF
    0,    0,    0,    0,    0,    0,    0,    0,    // 0xE0-0xE7
    0,    0,    0,    0,    0,    0,    0,    0,    // 0xE8-0xEF
    0,    0,    0,    0,    0,    0,    0,    0,    // 0xF0-0xF7
    0,    0,    0,    0,    0,    0,    0,    0,    // 0xF8-0xFF

    /* Shifted keys (0x100-0x1FF) */
    0,    KEY_F9, 0,    KEY_F5, KEY_F3, KEY_F1, KEY_F2, KEY_F12,    // 0x00-0x07
    0,    KEY_F10, KEY_F8, KEY_F6, KEY_F4, KEY_TAB, '~',  0,    // 0x08-0x0F
    0,    0,    0,    0,    0,    'Q',  '!',  0,    // 0x10-0x17
    0,    KEY_ENTER, 'Z',  'S',  'A',  'W',  '@',  0,    // 0x18-0x1F
    0,    'C',  'X',  'D',  'E',  '$',  '#',  0,    // 0x20-0x27
    0,    ' ',  'V',  'F',  'T',  'R',  '%',  0,    // 0x28-0x2F
    0,    'N',  'B',  'H',  'G',  'Y',  '^',  0,    // 0x30-0x37
    0,    0,    'M',  'J',  'U',  '&',  '*',  0,    // 0x38-0x3F
    0,    '<',  'K',  'I',  'O',  ')',  '(',  0,    // 0x40-0x47
    0,    '>',  '?',  'L',  ':',  'P',  '_',  0,    // 0x48-0x4F
    0,    0,    '"',  0,    '{',  '+',  0,    0,    // 0x50-0x57
    0,    0,    KEY_ENTER, '}',  0,    '|',  0,    0,    // 0x58-0x5F
    0,    0,    0,    0,    0,    0,    KEY_BS, 0,    // 0x60-0x67
    0,    '1',  0,    '4',  '7',  0,    0,    0,    // 0x68-0x6F
    '0',  '.',  '2',  '5',  '6',  '8',  KEY_ESC, 0,    // 0x70-0x77
    KEY_F11,    '+',  '3',  '-',  '*',  '9',  0,    0,    // 0x78-0x7F
    '/',  KEY_INSERT, KEY_PAUSE, KEY_F7, KEY_PRINT, KEY_DEL, KEY_LEFT, KEY_HOME,  // 0x80-0x87
    KEY_END, KEY_UP, KEY_DOWN, KEY_PGUP, KEY_PGDOWN, KEY_RIGHT, 0, 0,    // 0x88-0x8F
    0,    0,    0,    0,    0,    0,    0,    0,    // 0x90-0x97
    0,    0,    0,    0,    0,    0,    0,    0,    // 0x98-0x9F
    0,    0,    0,    0,    0,    0,    0,    0,    // 0xA0-0xA7
    0,    0,    0,    0,    0,    0,    0,    0,    // 0xA8-0xAF
    0,    0,    0,    0,    0,    0,    0,    0,    // 0xB0-0xB7
    0,    0,    0,    0,    0,    0,    0,    0,    // 0xB8-0xBF
    0,    0,    0,    0,    0,    0,    0,    0,    // 0xC0-0xC7
    0,    0,    0,    0,    0,    0,    0,    0,    // 0xC8-0xCF
    0,    0,    0,    0,    0,    0,    0,    0,    // 0xD0-0xD7
    0,    0,    0,    0,    0,    0,    0,    0,    // 0xD8-0xDF
    0,    0,    0,    0,    0,    0,    0,    0,    // 0xE0-0xE7
    0,    0,    0,    0,    0,    0,    0,    0,    // 0xE8-0xEF
    0,    0,    0,    0,    0,    0,    0,    0,    // 0xF0-0xF7
    0,    0,    0,    0,    0,    0,    0,    0,    // 0xF8-0xFF
};
