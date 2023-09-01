#ifndef UTIL_H
#define UTIL_H

#include <stdio.h>
#include <sys/ioctl.h>
#include <termios.h>
#include <unistd.h>

#define CSI "\033["
#define ALT_ENA CSI "?1049h"
#define ALT_DIS CSI "?1049l"

#define TERM_ENDCOLOUR "\e[0m"
#define TERM_COLOUR "\033[%dm"

int max2(int a, int b) { return a >= b ? a : b; }
int max4(int a, int b, int c, int d) { return max2(max2(a, b), max2(c, d)); }

int min2(int a, int b) { return a <= b ? a : b; }
int min4(int a, int b, int c, int d) { return min2(min2(a, b), min2(c, d)); }

static struct termios oldt, newt;
void set_up_term() {
    tcgetattr(STDIN_FILENO, &oldt);
    newt = oldt;
    newt.c_lflag &= ~(ICANON | ECHO);
    tcsetattr(STDIN_FILENO, TCSANOW, &newt);

    /* setvbuf(stdout, NULL, _IOFBF, 0); */
    /* printf(ALT_ENA); */
    fflush(stdout);
}

void restore_term() {
    /* printf(ALT_DIS); */
    tcsetattr(STDIN_FILENO, TCSANOW, &oldt);
}

#endif
