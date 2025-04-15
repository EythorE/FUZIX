#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <fcntl.h>
#include <unistd.h>
#include <syscalls.h>
#include <termios.h>
#include <sys/stat.h>
#include <errno.h>

// I need to create libvdp for this
#define VDPCLEAR    1
#define VDPRESET    2

#define KEY_ESC     27
#define KEY_LEFT    0xC4  // 0x80 | 'D'
#define KEY_RIGHT   0xC3  // 0x80 | 'C'

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


/**
 * Get a list of .simg files from a directory
 * 
 * @param directory The directory to scan
 * @param files Array to store filenames (must be pre-allocated)
 * @param max_files Maximum number of files to store
 * @return Number of files found
 */
int get_list_of_images_from_directory(const char* directory, char files[][16], int max_files) {
    DIR* dir = opendir(directory);
    if (!dir) {
        return 0;
    }
    
    struct dirent* entry;
    struct stat file_stat;
    int count = 0;
    char full_path[256];
    
    while ((entry = readdir(dir)) != NULL && count < max_files) {
        // Skip "." and ".." directories
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
            continue;
        }
        
        // Check if it has .simg extension
        int name_len = strlen(entry->d_name);
        if (name_len <= 5 || strcmp(entry->d_name + name_len - 5, ".simg") != 0) {
            continue;
        }
        
        // Build full path to check if it's a regular file
        snprintf(full_path, sizeof(full_path), "%s/%s", directory, entry->d_name);
        if (stat(full_path, &file_stat) != 0) {
            continue;  // Skip if we can't stat the file
        }
        
        // Check if it's a regular file
        if (S_ISREG(file_stat.st_mode)) {
            // Copy filename (limit to 15 chars + null terminator)
            strncpy(files[count], entry->d_name, 15);
            files[count][15] = '\0';
            count++;
        }
    }
    
    closedir(dir);
    return count;
}


/**
 * Get images from a path and find index of specific file
 * 
 * @param path Path to file or directory
 * @param dir_path Buffer to store the directory path
 * @param dir_size Size of the directory path buffer
 * @param files Array to store filenames (must be pre-allocated)
 * @param max_files Maximum number of files to store
 * @param file_count Pointer to store the number of files found
 * @return Index of the specified file (-1 if error occurred)
 */
int get_images(const char* path, char* dir_path, int dir_size, char files[][16], 
               int max_files, int* file_count) {
    char filename[16] = {0};
    struct stat path_stat;
    int i = 0;
    
    // Check if path exists
    if (stat(path, &path_stat) != 0) {
        fprintf(stderr, "Error: Path '%s' does not exist\n", path);
        return -1;
    }
    
    // Handle file vs directory
    if (S_ISDIR(path_stat.st_mode)) {
        // It's a directory - use it directly
        strncpy(dir_path, path, dir_size - 1);
        dir_path[dir_size - 1] = '\0';
    } else {
        // It's a file - extract directory and filename
        const char* last_slash = strrchr(path, '/');
        if (last_slash) {
            // Copy directory path
            int dir_len = last_slash - path;
            strncpy(dir_path, path, dir_len < (dir_size - 1) ? dir_len : (dir_size - 1));
            dir_path[dir_len < (dir_size - 1) ? dir_len : (dir_size - 1)] = '\0';
            
            // Copy filename
            strncpy(filename, last_slash + 1, 15);
            filename[15] = '\0';
        } else {
            // No slash - file is in current directory
            strcpy(dir_path, ".");
            strncpy(filename, path, 15);
            filename[15] = '\0';
        }
        
        // Check if it's a .simg file
        if (strlen(filename) <= 5 || strcmp(filename + strlen(filename) - 5, ".simg") != 0) {
            fprintf(stderr, "Error: File '%s' does not have .simg extension\n", path);
            return -1;
        }
    }
    
    // Get list of images
    *file_count = get_list_of_images_from_directory(dir_path, files, max_files);
    
    // No images found
    if (*file_count == 0) {
        fprintf(stderr, "Error: No .simg files found in directory '%s'\n", dir_path);
        return -1;
    }
    
    // If we started with a file, find its index
    if (filename[0] != '\0') {
        for (i = 0; i < *file_count; i++) {
            if (strcmp(files[i], filename) == 0) {
                break;
            }
        }
        // If file wasn't found in the list
        if (i == *file_count) {
            fprintf(stderr, "Error: File not found '%s'\n", path);
            return -1;
        }
    }
    
    return i;
}




void fail(const char *message) {
    cleanup();
    perror(message);
    exit(EXIT_FAILURE);
}

void read_file(const char *filename, void *buffer) {
    int fd;
    struct stat file_stat;
    ssize_t bytes_read;
    
    fd = open(filename, O_RDONLY);
    if (fd == -1) {
        fail(filename);
    }
    if (fstat(fd, &file_stat) == -1) {
        close(fd);
        fail(filename);
    }
    
    bytes_read = read(fd, buffer, file_stat.st_size);
    close(fd);

    if (bytes_read == -1) {
        cleanup();
        fail(filename);
    }
    
    //if (bytes_read != file_stat.st_size) {
    //    fprintf(stderr, "Warning: Read %zd bytes, expected %ld bytes\n", 
    //            bytes_read, (long)file_stat.st_size);
    //}
    
}

void wait_for_key() {
    while (1) {
        unsigned char c = getchar();
        if (c == 10)
            break;
    }
}

int main(int argc, char *argv[])
{
    // Read file
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <filename>\n", argv[0]);
        return 1;
    }

    char dir_path[256];
    char files[16][16];  // Space for 16 files, 16 chars each
    int file_count;
    int current_index = get_images(argv[1], dir_path, sizeof(dir_path), files, 16, &file_count);
    if (current_index < 0) {
        return 1;
    }

    vdpdev = open("/dev/vdp", O_WRONLY);
    if (vdpdev < 0) {
        perror("Failed to open /dev/vdp");
        return 1;
    }

    void *buffer = malloc(32896);
    if (buffer == NULL) {
        perror("Memory allocation failed");
        return 1;
    }

    // Build the full path of the current image
    char full_path[64];
    snprintf(full_path, sizeof(full_path), "%s/%s", dir_path, files[current_index]);

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

    tcsetattr(STDIN_FILENO, TCSANOW, &new_tio);
    ioctl(vdpdev, VDPCLEAR, 0);
    read_file(full_path, buffer);
    _imshow(buffer);

    while (1) {
        unsigned char c = getchar();
        
        if (c == 'q' || c == KEY_ESC)
            break;
        
        // Handle navigation keys
        if (c == KEY_RIGHT || c == 'n') {
            current_index = (current_index + 1) % file_count;
            snprintf(full_path, sizeof(full_path), "%s/%s", dir_path, files[current_index]);
            
            read_file(full_path, buffer);
            _imshow(buffer);
            
        }
        else if (c == KEY_LEFT || c == 'p') {
            current_index = (current_index - 1 + file_count) % file_count;
            snprintf(full_path, sizeof(full_path), "%s/%s", dir_path, files[current_index]);
            
            read_file(full_path, buffer);
            _imshow(buffer);
            
        }
    }
    cleanup();
    return 0;
}
