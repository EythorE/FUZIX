#include <stdio.h>
#include <stdlib.h>
#include <termios.h>
#include <unistd.h>

int main() {
    struct termios old_tio, new_tio;
    char input[256];
    
    // Get the terminal settings
    tcgetattr(STDIN_FILENO, &old_tio);
    
    // Copy the old settings to new_tio
    new_tio = old_tio;
    
    // Disable canonical mode (line-by-line input)
    // and disable echo
    new_tio.c_lflag &= ~(ICANON | ECHO);
    
    // Set the new attributes
    tcsetattr(STDIN_FILENO, TCSANOW, &new_tio);
    
    printf("Type something (input won't be shown): ");
    fflush(stdout);
    
    // Read input without echoing
    int i = 0;
    while (1) {
        char c = getchar();
        if (c == 0)
            continue;
        if (c == '\n' || i >= 255)
            break;
        input[i++] = c;
    }
    input[i] = '\0';
    
    // Restore the old terminal settings
    tcsetattr(STDIN_FILENO, TCSANOW, &old_tio);
    
    printf("\nYou typed: %s\n", input);
    
    return 0;
}
