#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <termios.h>
#include <unistd.h>

#define CSI "\033["
#define ALT_ENA CSI "?1049h"
#define ALT_DIS CSI "?1049l"

#define BOARD_W 10
#define BOARD_H 21

#define PROG_SIZE 0x1000

#define PIECE_TIMEOUT 50
#define PIECE_PREVIEWS 5

// considering a global timeout (seconds) for infra reasons

#define TERM_ENDCOLOUR "\e[0m"
#define TERM_COLOUR "\033[%dm"

typedef enum {
    P_NONE = 0,
    P_I = 1,
    P_O = 2,
    P_T = 3,
    P_J = 4,
    P_L = 5,
    P_S = 6,
    P_Z = 7,
    P_WALL = 8,
} shape_t;

int PIECE_COLOURS[] = {16, 14, 11, 13, 12, 214, 10, 9};
int GHOST_COLOURS[] = {16, 6, 3, 5, 4, 166, 2, 1};

typedef struct {
    int x;
    int y;
} pos_t;

/*
      x  0  1  2  3
    y

    0    X

    1

    2

    3
 */

/* [angle][shape][cell] */
pos_t SHAPES[4][8][4] = {
    {{0},
     {{0, 1}, {1, 1}, {2, 1}, {3, 1}},  /* I */
     {{1, 1}, {1, 2}, {2, 1}, {2, 2}},  /* O */
     {{1, 1}, {0, 1}, {1, 0}, {2, 1}},  /* T */
     {{0, 0}, {0, 1}, {1, 1}, {2, 1}},  /* J */
     {{0, 1}, {1, 1}, {2, 1}, {2, 0}},  /* L */
     {{0, 1}, {1, 1}, {1, 0}, {2, 0}},  /* S */
     {{0, 0}, {1, 0}, {1, 1}, {2, 1}}}, /* Z */

    {{0},
     {{2, 0}, {2, 1}, {2, 2}, {2, 3}},  /* I */
     {{1, 1}, {1, 2}, {2, 1}, {2, 2}},  /* O */
     {{1, 1}, {1, 0}, {2, 1}, {1, 2}},  /* T */
     {{1, 0}, {2, 0}, {1, 1}, {1, 2}},  /* J */
     {{1, 0}, {2, 2}, {1, 1}, {1, 2}},  /* L */
     {{1, 0}, {1, 1}, {2, 1}, {2, 2}},  /* S */
     {{2, 0}, {1, 1}, {2, 1}, {1, 2}}}, /* Z */

    {{0},
     {{0, 2}, {1, 2}, {2, 2}, {3, 2}},  /* I */
     {{1, 1}, {1, 2}, {2, 1}, {2, 2}},  /* O */
     {{1, 1}, {2, 1}, {1, 2}, {0, 1}},  /* T */
     {{0, 1}, {1, 1}, {2, 1}, {2, 2}},  /* J */
     {{0, 1}, {1, 1}, {2, 1}, {0, 2}},  /* L */
     {{0, 2}, {1, 2}, {1, 1}, {2, 1}},  /* S */
     {{0, 1}, {1, 1}, {1, 2}, {2, 2}}}, /* Z */

    {{0},
     {{1, 0}, {1, 1}, {1, 2}, {1, 3}}, /* I */
     {{1, 1}, {1, 2}, {2, 1}, {2, 2}}, /* O */
     {{1, 1}, {1, 2}, {0, 1}, {1, 0}}, /* T */
     {{1, 0}, {1, 1}, {0, 2}, {1, 2}}, /* J */
     {{1, 0}, {1, 1}, {0, 0}, {1, 2}}, /* L */
     {{0, 0}, {0, 1}, {1, 1}, {1, 2}}, /* S */
     {{1, 0}, {0, 1}, {1, 1}, {0, 2}}} /* Z */
};

int max2(int a, int b) { return a >= b ? a : b; }
int max4(int a, int b, int c, int d) { return max2(max2(a, b), max2(c, d)); }

int min2(int a, int b) { return a <= b ? a : b; }

int min4(int a, int b, int c, int d) { return min2(min2(a, b), min2(c, d)); }

int not_random = 0;
shape_t rand_shape() {
    not_random = (not_random + 1) % 7;
    return not_random + 1;
}

typedef struct {
    pos_t pos;
    shape_t s;
    int colour;
    int gcolour;
    uint8_t angle;
} piece_t;

void get_cells(piece_t p, pos_t out[4]) {
    for (int i = 0; i < 4; i++) {
        pos_t cell = SHAPES[p.angle % 4][p.s][i];
        out[i].x = p.pos.x + cell.x;
        out[i].y = p.pos.y + cell.y;
    }
}

piece_t new_piece(int s) {
    piece_t p;
    p.s = s != 0 ? s : rand_shape();
    p.colour = PIECE_COLOURS[p.s];
    p.gcolour = GHOST_COLOURS[p.s];
    p.pos.x = 3;
    p.pos.y = 0;
    p.angle = 0;
    return p;
}

// each cell just holds the piece colour
typedef int board_t[BOARD_H][BOARD_W];

typedef struct {
    board_t board;
    uint64_t score;
    piece_t p;
    /* since no gravity, no point in limiting # of holds per piece */
    shape_t held;
    shape_t preview[PIECE_PREVIEWS];
} game_t;

game_t *new_game() {
    game_t *g = calloc(sizeof(game_t), 1);
    g->p = new_piece(0);
    for (int i = 0; i < PIECE_PREVIEWS; i++) {
        g->preview[i] = rand_shape();
    }
    return g;
}

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
} rule_t;

/* Return 1 if p overlaps with any placed piece in g */
int check_dead(game_t *g, piece_t *p) {
    pos_t cells[4];
    get_cells(*p, cells);
    for (int i = 0; i < 4; i++) {
        if (g->board[cells[i].y][cells[i].x] != P_NONE) {
            return 1;
        }
    }
    return 0;
}

void print_game(game_t *g) {
    board_t outb = {PIECE_COLOURS[P_NONE]};
    /* board pieces and voids */
    for (int y = 0; y < BOARD_H; y++) {
        for (int x = 0; x < BOARD_W; x++) {
            outb[y][x] = PIECE_COLOURS[g->board[y][x]];
        }
    }

    /* ghost piece */
    piece_t ghost = g->p;
    piece_t new_ghost = ghost;
    new_ghost.pos.y++;
    while (1) {
        pos_t cells[4];
        get_cells(new_ghost, cells);
        int max_y = max4(cells[0].y, cells[1].y, cells[2].y, cells[3].y);
        if (max_y >= BOARD_H) {
            break;
        }
        if (check_dead(g, &new_ghost)) {
            break;
        }
        ghost.pos.y++;
        new_ghost.pos.y++;
    }
    pos_t ghost_cells[4];
    get_cells(ghost, ghost_cells);
    for (int i = 0; i < 4; i++) {
        outb[ghost_cells[i].y][ghost_cells[i].x] = g->p.gcolour;
    }

    /* curr piece */
    pos_t cells[4];
    get_cells(g->p, cells);
    for (int i = 0; i < 4; i++) {
        outb[cells[i].y][cells[i].x] = g->p.colour;
    }

    int lpanel[BOARD_H][6];
    int rpanel[BOARD_H][6];
    for (int y = 0; y < BOARD_H; y++) {
        for (int x = 0; x < BOARD_W; x++) {
            lpanel[y][x] = PIECE_COLOURS[P_NONE];
            rpanel[y][x] = PIECE_COLOURS[P_NONE];
        }
    }

    /* lpanel: hold piece */
    if (g->held != P_NONE) {
        piece_t held = new_piece(g->held);
        held.pos.x = 1;
        held.pos.y = 1;
        pos_t lcells[4];
        get_cells(held, lcells);
        for (int i = 0; i < 4; i++) {
            lpanel[lcells[i].y][lcells[i].x] = PIECE_COLOURS[held.s];
        }
    }

    /* rpanel: next */
    for (int i = 0; i < PIECE_PREVIEWS; i++) {
        piece_t prv = new_piece(g->preview[i]);
        prv.pos.x = 1;
        prv.pos.y = i * 4 + 1;
        pos_t rcells[4];
        get_cells(prv, cells);
        for (int i = 0; i < 4; i++) {
            rpanel[cells[i].y][cells[i].x] = PIECE_COLOURS[prv.s];
        }
    }

    /* print */
    printf("\n");
    printf("+------------+--------------------+------------+\n");
    printf("| Hold:      |  *Practice mode*   | Next:      |\n");
    printf("+------------+--------------------+------------+\n");
    for (int y = 0; y < BOARD_H; y++) {
        printf("|");
        for (int x = 0; x < 6; x++) {
            printf("\e[48;5;%dm  ", lpanel[y][x]);
        }
        printf(TERM_ENDCOLOUR);
        printf("|");
        for (int x = 0; x < BOARD_W; x++) {
            printf("\e[48;5;%dm  ", outb[y][x]);
        }
        printf(TERM_ENDCOLOUR);
        printf("|");
        for (int x = 0; x < 6; x++) {
            printf("\e[48;5;%dm  ", rpanel[y][x]);
        }
        printf(TERM_ENDCOLOUR);
        printf("|\n");
    }
    printf("+------------+--------------------+------------+\n");
    printf("|            | wasd  SPC   . - =  |            |\n");
    printf("+------------+--------------------+------------+\n");
}

// rule compiler
rule_t *parse_prog(char *in) {
    puts("parse_prog called");
    return NULL;
}

int exec_rule(char *rname, rule_t *rules, int r_count) {
    for (int i = 0; i < r_count; i++) {
        if (rules[i].name == rname || rules[i].check()) {
            return rules[i].call();
        }
    }
    return 1; // should not happen with die ruel
}

// return 1 when done
int add_piece(game_t *g, rule_t *rules, int r_count) {
    puts("play() called");

    while (1) {
        shape_t s = rand_shape();
        // do something with s

        int done_p = 0;
        for (int i = 0; i < PIECE_TIMEOUT && !done_p; i++) {
            done_p = exec_rule(NULL, rules, r_count);
            print_game(g);
        }

        if (check_dead(g, &g->p)) {
            return 1;
        }
    }
}

int clear_lines(game_t *g) {
    int rowcnt[BOARD_H] = {0};
    for (int y = 0; y < BOARD_H; y++) {
        for (int x = 0; x < BOARD_W; x++) {
            if (g->board[y][x] != P_NONE) {
                rowcnt[y]++;
            }
        }
    }

    int score[] = {0, 100, 300, 500, 800};
    int score_i = 0;

    for (int dst_y = BOARD_H - 1, src_y = BOARD_H - 1; dst_y >= 0;
         dst_y--, src_y--) {
        while (rowcnt[src_y] == BOARD_W) { /* clear */
            src_y--;
            score_i++;
        }

        for (int x = 0; x < BOARD_W; x++) {
            g->board[dst_y][x] = src_y < 0 ? P_NONE : g->board[src_y][x];
        }
    }
    return score[score_i];
}

/* Shift the queue forward, filling in the new spot, and throwing away curr.
 * Assumes curr piece has already been written to the board if necessary. */
int advance_shape(game_t *g) {
    g->p = new_piece(g->preview[0]);
    for (int i = 0; i < PIECE_PREVIEWS - 1; i++) {
        g->preview[i] = g->preview[i + 1];
    }
    g->preview[PIECE_PREVIEWS - 1] = rand_shape();
}

///////// checkable functions
int check_round() {}

/*
  BUGGY: This will return the first cell of the shape || board, which may or may
  not be on the board at the time. maybe?
*/
int check_shape() {}

int _move_lr(game_t *g, int m) {
    int old_x = g->p.pos.x;
    piece_t new_p = g->p;
    new_p.pos.x = old_x + m;

    /* check board excursion */
    pos_t cells[4];
    get_cells(new_p, cells);
    int min_x = min4(cells[0].x, cells[1].x, cells[2].x, cells[3].x);
    int max_x = max4(cells[0].x, cells[1].x, cells[2].x, cells[3].x);
    if (min_x < 0 || max_x >= BOARD_W) {
        return 1;
    }

    /* check collisions with placed pieces */
    if (check_dead(g, &new_p)) {
        return 1;
    }

    g->p = new_p;
    return 0;
}

///////// game actions
int move_left(game_t *g) { return _move_lr(g, -1); }
int move_right(game_t *g) { return _move_lr(g, 1); }
int move_down(game_t *g) {
    int old_y = g->p.pos.y;
    piece_t new_p = g->p;
    new_p.pos.y = old_y + 1;

    pos_t cells[4];
    get_cells(new_p, cells);
    int max_y = max4(cells[0].y, cells[1].y, cells[2].y, cells[3].y);
    if (max_y >= BOARD_H) {
        return 1;
    }

    if (check_dead(g, &new_p)) {
        return 1;
    }

    g->p = new_p;
    return 0;
}
int move_drop(game_t *g) {
    while (!move_down(g))
        ;
}
int move_rot_l(game_t *g) {
    g->p.angle--;
    return 0;
}
int move_rot_r(game_t *g) {
    g->p.angle++;
    return 0;
}
int move_rot_180(game_t *g) {
    g->p.angle--;
    g->p.angle--;
    return 0;
}
int move_hold(game_t *g) {
    if (g->held == P_NONE) {
        g->held = g->p.s;
        advance_shape(g);
    } else {
        int tmp = g->p.s;
        g->p = new_piece(g->held);
        g->held = tmp;
    }
    return 0;
}

// move_restart?

typedef struct {
    char *name;
    int (*f)(game_t *g);
} move;

move game_moves[] = {{"left", &move_left},       {"right", &move_right},
                     {"down", &move_down},       {"drop", &move_drop},
                     {"rot_l", &move_rot_l},     {"rot_r", &move_rot_r},
                     {"rot_180", &move_rot_180}, {"hold", &move_hold}};

/* just for testing the game */
/* handle inputs until drop, clear lines, spawn new piece, check for death */
int add_piece_override(game_t *g) {
    int done = 0;
    print_game(g);
    while (!done) {
        char in = getchar();
        switch (in) {
        case '-':
            move_left(g);
            break;
        case '=':
            move_right(g);
            break;
        case '.':
            move_drop(g);
            done = 1;
            break;
        case 'w':
            move_hold(g);
            break;
        case 'a':
            move_rot_l(g);
            break;
        case 's':
            move_rot_180(g);
            break;
        case 'd':
            move_rot_r(g);
            break;
        case ' ':
            move_down(g);
            break;
        default:
            continue;
        }
        print_game(g);
    }
    /* handle drop */
    pos_t cells[4];
    get_cells(g->p, cells);
    for (int i = 0; i < 4; i++) {
        g->board[cells[i].y][cells[i].x] = g->p.s;
    }

    g->score += clear_lines(g);
    advance_shape(g);
    return check_dead(g, &g->p);
}

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

int main() {
    set_up_term();
    srand(0);
    /* overflow is behind the board. need to see if this works. */
    int done = 0;
    /* board_t *board = malloc(sizeof(board_t)); */

    uint64_t score;
    char retry[3] = {0};

    do {
        game_t *g = new_game();
        puts("Build your own tetrominobot!");
        puts("Enter your bot description:");
        printf("> ");

        char user_in[PROG_SIZE];
        fgets(user_in, PROG_SIZE, stdin);
        rule_t *rules = parse_prog(user_in);
        printf("program: %s\n", user_in);

        do {
            /* done = add_piece(g, rules, 0); */
            done = add_piece_override(g);
        } while (!done);

        printf("Score: %llu\n", g->score);
        puts("Retry? (y/N)");
        printf("> ");
        fgets(retry, 3, stdin);
        free(g); // free each time?

    } while (retry[0] == 'y' || retry[0] == 'Y');

    restore_term();
    return 0;
}

/* Just to make the libc leak work, we should be maintaining a list of pieces */
