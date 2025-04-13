#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <syscalls.h>
#include <termios.h>

// I need to create libvdp for this
#define VDPCLEAR    1
#define VDPRESET    2

#define KEY_ESC     27

extern void _imshow();

int vdpdev;
struct termios old_tio, new_tio;

void cleanup() {
    // Restore the old terminal settings
    tcsetattr(STDIN_FILENO, TCSANOW, &old_tio);
    ioctl(vdpdev, VDPRESET, 0);
    close(vdpdev);
}

void cleanup_handler(int signum) {
    cleanup();
    /* Exit with a special code to indicate signal termination */
    exit(128 + signum);
}

#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <errno.h>

void* read_file(const char *filename) {
    int fd;
    void *buffer;
    struct stat file_stat;
    ssize_t bytes_read;
    
    fd = open(filename, O_RDONLY);
    if (fd == -1) {
        perror("Error opening file");
        return NULL;
    }
    if (fstat(fd, &file_stat) == -1) {
        perror("Error getting file size");
        close(fd);
        return NULL;
    }

    buffer = malloc(file_stat.st_size);
    if (buffer == NULL) {
        perror("Memory allocation failed");
        close(fd);
        return NULL;
    }
    
    bytes_read = read(fd, buffer, file_stat.st_size);
    if (bytes_read == -1) {
        perror("Error reading file");
        free(buffer);
        close(fd);
        return NULL;
    }
    
    if (bytes_read != file_stat.st_size) {
        fprintf(stderr, "Warning: Read %zd bytes, expected %ld bytes\n", 
                bytes_read, (long)file_stat.st_size);
    }
    
    close(fd);
    
    return buffer;
}


int main(int argc, char *argv[])
{
    // Read file
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <filename>\n", argv[0]);
        return 1;
    }
    void *data = read_file(argv[1]);
    if (data == NULL) {
        return 1;
    }

    // Get the terminal settings
    tcgetattr(STDIN_FILENO, &old_tio);
    // Copy the old settings to new_tio
    new_tio = old_tio;
    // Disable canonical mode (line-by-line input)
    // and disable echo
    new_tio.c_lflag &= ~(ICANON | ECHO);
    // Set the new attributes
    tcsetattr(STDIN_FILENO, TCSANOW, &new_tio);

    /* SIGINT (Ctrl+C) */
    signal(SIGINT, cleanup_handler);
    /* SIGTERM (killall, kill default signal) */
    signal(SIGTERM, cleanup_handler);

    vdpdev = open("/dev/vdp", O_WRONLY);
    if (vdpdev < 0) {
        perror("Failed to open /dev/vdp");
        return 1;
    }

    ioctl(vdpdev, VDPCLEAR, 0);
    _imshow(data);
    free(data);

    while (1) {
        char c = getchar();
        if (c == 'q' || c == KEY_ESC)
            break;
    }
    cleanup();
    return 0;
}
