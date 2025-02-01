#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <stdbool.h>
#include <tty.h>
#include <devtty.h>
// #include <vt.h>


static unsigned char tbuf1[TTYSIZ];

struct s_queue ttyinq[NUM_DEV_TTY + 1] = {	/* ttyinq[0] is never used */
	{NULL, NULL, NULL, 0, 0, 0},
	{tbuf1, tbuf1, tbuf1, TTYSIZ, 0, TTYSIZ / 2},
};

/* Define which attributes can be changed on TTY devices */
tcflag_t termios_mask[NUM_DEV_TTY + 1] = {
    0,      /* Device 0: unused */
    0       /* Device 1: no attributes changeable */
};


/* Output for the system console (kprintf etc) */
void kputchar(uint_fast8_t c)
{
	if (c == '\n')
		tty_putc(1, '\r');
	tty_putc(1, c);
}

extern void printString(uint_fast8_t *str);  // External assembly routine
void tty_putc(uint_fast8_t minor, uint_fast8_t c)
{
    uint_fast8_t buffer[2] = {0, 0};  // Buffer to store the character and null terminator
    buffer[0] = c;  // Read a character using the external function
    printString(buffer);    // Print the character
}

ttyready_t tty_writeready(uint_fast8_t minor)
{
        return TTY_READY_NOW;
}

void tty_sleeping(uint_fast8_t minor)
{
}

int tty_carrier(uint_fast8_t minor)
{
    return 1;
}

/* Perform any hardware set up necessary to open this port. If none is
   required then this can be a blank function. */
/*
 *	This function is called whenever the terminal interface is opened
 *	or the settings changed. It is responsible for making the requested
 *	changes to the port if possible. Strictly speaking it should write
 *	back anything that cannot be implemented to the state it selected.
 */
void tty_setup(uint_fast8_t minor, uint_fast8_t flags)
{
}


// void tty_poll(uint8_t minor, struct uart16x50 volatile *u)
// {	
// }

void tty_interrupt(void)
{
	// tty_poll(1, uart);
}

void plt_interrupt(void)
{
	// tty_interrupt();
}

void tty_data_consumed(uint_fast8_t minor)
{
}