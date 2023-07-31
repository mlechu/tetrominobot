#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#define BOARD_W 10
#define BOARD_H 20

#define PROG_SIZE 0x1000

typedef enum {
    EMPTY = 0,
    P_I = 1,
    P_O = 2,
    P_T = 3,
    P_J = 4,
    P_L = 5,
    P_S = 6,
    P_Z = 7,
    WALL = 8,
} shape;

int SHAPES[7][4][2] = {
    {{0, 1}, {1, 1}, {2, 1}, {3, 1}}, {{0, 0}, {0, 1}, {1, 0}, {1, 1}},
    {{0, 1}, {1, 0}, {1, 1}, {2, 1}}, {{0, 0}, {0, 1}, {1, 1}, {2, 1}},
    {{0, 1}, {1, 1}, {2, 1}, {2, 0}}, {{0, 1}, {1, 1}, {1, 0}, {2, 0}},
    {{0, 0}, {1, 0}, {1, 1}, {2, 1}}};

typedef struct {
    int8_t base_x;
    int8_t base_y;
    shape s;
} board_piece;

void parse_prog() { puts("parse_prog called"); }

int place_piece() {
    puts("place_piece called");
    return 1;
}

int main() {

    /* overflow is behind the board. need to see if this works. */
    int done = 0;
    uint8_t *board = malloc(BOARD_H * BOARD_W);
    uint64_t score;
    char retry[3] = {0};

    do {
        score = 0;
        puts("Enter your bot description:");
        printf("> ");

        char user_in[PROG_SIZE];
        fgets(user_in, PROG_SIZE, stdin);
        /* rules = parse_prog(user_in); */
        printf("program: %s\n", user_in);

        do {
            done = place_piece();
        } while (!done);

        printf("Score: %llu\n", score);
        puts("Retry? (y/N)");
        printf("> ");
        fgets(retry, 3, stdin);

    } while (retry[0] == 'y' || retry[0] == 'Y');
    free(board); // free each time?
    return 0;
}

/* Just to make the libc leak work, we should be maintaining a list of pieces */
