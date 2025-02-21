#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <fcntl.h>

#define STDIN_FILENO   0  /* fileno(stdin)  */
#define STDOUT_FILENO  1  /* fileno(stdout) */

#define BUFFER_SIZE    512

static char buff[BUFFER_SIZE];

/* The name of the file currently being displayed, "-" indicates stdin. */

char *filename;

int open_file(char *new_filename)
{
    int fd;

    filename = new_filename;

    if (*filename == '-' && *(filename + 1) == '\0')
	return (STDIN_FILENO);

    /*
     * If open() returns an error, the accepted behavior is for cat to
     * report the error and move on to the next file in the argument list.
     */
    if ((fd = open(filename, O_CREAT)) < 0)
	perror(filename);

    return (fd);
}


/*
 * Output from the current fd until we reach EOF, and then return.
 */

int output_file(int fd)
{
    int bytes_read;

    while ((bytes_read = read(fd, buff, BUFFER_SIZE)) > 0)
	write(STDOUT_FILENO, buff, bytes_read);

    if (bytes_read < 0)
        perror(filename);

    return (1);
}

int main(int argc, char **argv)
{
    int input_fd = open_file("test.x");
	static char buff2[] = "hello file";
	write(input_fd, buff2, 10);
	output_file(input_fd);
	close(input_fd);
    close(1);

    return (0);
}


// #include <stdio.h>
// #include <unistd.h>
// #include <syscalls.h>
// #include <time.h>

// int main(int argc, char *argv[])
// {
// 	static struct {
// 		struct _uzisysinfoblk i;
// 		char buf[128];
// 	} uts;
// 	_uname(&uts.i, sizeof(uts));
// 	printf("         total         used         free\n");
// 	printf("Mem:     %5d        %5d        %5d\n",
// 		uts.i.memk, uts.i.usedk, uts.i.memk - uts.i.usedk);
// 	printf("Swap:    %5d        %5d        %5d\n",
// 		uts.i.swapk, uts.i.swapusedk, uts.i.swapk - uts.i.swapusedk);



//     // Open a file for writing
//     FILE *fp = _open("test_file.txt", "w");
//     if (fp == NULL) {
//         printf("Error opening file!\n");
//         return 1;
//     }

    
//     fprintf(fp, "fprintf\n");
//     fclose(fp);

//     // // Now let's read and display the file contents
//     // fp = fopen("test_file.txt", "r");
//     // if (fp == NULL) {
//     //     printf("Error opening file for reading!\n");
//     //     return 1;
//     // }

//     // printf("\nReading from file:\n");
//     // char line[256];
//     // while (fgets(line, sizeof(line), fp) != NULL) {
//     //     printf("%s", line);
//     // }

//     // fclose(fp);


		
// 	return 0;
// }
