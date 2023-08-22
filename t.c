#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#define BOARD_W 10
#define BOARD_H 20

#define PROG_SIZE 0x1000

#define PIECE_TIMEOUT 50
// considering a global timeout for infra reasons

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

/* typedef struct { */
/*     uint64_t name; */
/*     // ... */
/*     uint64_t nonsense; */
/*     uint64_t enabled; */
/*     uint32_t latest_use; */
/*     uint32_t use_count; */
/*     // ... */
/* } rule; */

typedef struct {
    char *name;
    int (*check)();
    int (*call)();
} rule;

// rule compiler
rule *parse_prog(char *in) {
    puts("parse_prog called");
    return NULL;
}


int not_random = 0;
shape rand_shape() {
    not_random = (not_random + 1) % 7;
    return not_random + 1;
}

int exec_rule(char *rname, rule *rules, int r_count) {
    for (int i = 0; i < r_count; i++) {
        if (rules[i].name == rname || rules[i].check()) {
            return rules[i].call();
        }
    }
    return 1; // should not happen with die ruel
}

int game_done() { return 1; }

// return 1 when done
int play(rule *rules, int r_count) {
    puts("play() called");

    while (1) {
        shape s = rand_shape();
        // do something with s
        int done_p = 0;
        for (int i = 0; i < PIECE_TIMEOUT && !done_p; i++) {
            done_p = exec_rule(NULL, rules, r_count);
        }

        if (game_done()) {
            break;
        }
    }
}

///////// checkable functions
int check_round() {}
int check_shape() {}

///////// game actions
void move_left() {}
void move_right() {}
void move_down() {}
void move_drop() {}
void move_rot_l() {}
void move_rot_r() {}
void move_rot_180() {}
void move_hold() {}

// move_restart?

typedef struct {
    char *name;
    void (*f)();
} move;

move game_moves[] = {{"left", &move_left},       {"right", &move_right},
                     {"down", &move_down},       {"drop", &move_drop},
                     {"rot_l", &move_rot_l},     {"rot_r", &move_rot_r},
                     {"rot_180", &move_rot_180}, {"hold", &move_hold}};

int main() {
    srand(0);
    /* overflow is behind the board. need to see if this works. */
    int done = 0;
    uint8_t *board = malloc(BOARD_H * BOARD_W);
    uint64_t score;
    char retry[3] = {0};

    do {
        score = 0;
        puts("Build your own tetrominobot!");
        puts("Enter your bot description:");
        printf("> ");

        char user_in[PROG_SIZE];
        fgets(user_in, PROG_SIZE, stdin);
        rule *rules = parse_prog(user_in);
        printf("program: %s\n", user_in);

        do {
            done = play(rules, 0);
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
