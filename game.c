#include "game.h"
#include "util.h"
#include <stdlib.h>
#include <string.h>
#include <time.h>

const int PIECE_COLOURS[] = {16, 14, 11, 13, 12, 208, 10, 9};
const int GHOST_COLOURS[] = {16, 6, 3, 5, 4, 130, 2, 1};

/*
      x 0 1 2 3
    y
    0
    1
    2
    3
 */

/* [angle][shape][cell] */
const pos_t SHAPES[4][8][4] = {
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

#define NO_KICKS                                                               \
    {                                                                          \
        {0, 0}, {0, 0}, {0, 0}, {0, 0}, { 0, 0 }                               \
    }

/* Super rotation system (SRS) kicklist from wiki */

/* KICKS[old_angle][new_angle][attempt] */
const pos_t KICKS_I[4][4][5] = {{NO_KICKS,
                                 {{0, 0}, {-2, 0}, {1, 0}, {-2, 1}, {1, -2}},
                                 NO_KICKS,
                                 {{0, 0}, {-1, 0}, {2, 0}, {-1, -2}, {2, 1}}},
                                {{{0, 0}, {2, 0}, {-1, 0}, {2, -1}, {-1, 2}},
                                 NO_KICKS,
                                 {{0, 0}, {-1, 0}, {2, 0}, {-1, -2}, {2, 1}},
                                 NO_KICKS},
                                {NO_KICKS,
                                 {{0, 0}, {1, 0}, {-2, 0}, {1, 2}, {-2, -1}},
                                 NO_KICKS,
                                 {{0, 0}, {2, 0}, {-1, 0}, {2, -1}, {-1, 2}}},
                                {{{0, 0}, {1, 0}, {-2, 0}, {1, 2}, {-2, -1}},
                                 NO_KICKS,
                                 {{0, 0}, {-2, 0}, {1, 0}, {-2, 1}, {1, -2}},
                                 NO_KICKS}};

const pos_t KICKS_A[4][4][5] = {{NO_KICKS,
                                 {{0, 0}, {-1, 0}, {-1, -1}, {0, 2}, {-1, 2}},
                                 NO_KICKS,
                                 {{0, 0}, {1, 0}, {1, -1}, {0, 2}, {1, 2}}},
                                {{{0, 0}, {1, 0}, {1, 1}, {0, -2}, {1, -2}},
                                 NO_KICKS,
                                 {{0, 0}, {1, 0}, {1, 1}, {0, -2}, {1, -2}},
                                 NO_KICKS},
                                {NO_KICKS,
                                 {{0, 0}, {-1, 0}, {-1, -1}, {0, 2}, {-1, 2}},
                                 NO_KICKS,
                                 {{0, 0}, {1, 0}, {1, -1}, {0, 2}, {1, 2}}},
                                {{{0, 0}, {-1, 0}, {-1, 1}, {0, -2}, {-1, -2}},
                                 NO_KICKS,
                                 {{0, 0}, {-1, 0}, {-1, 1}, {0, -2}, {-1, -2}},
                                 NO_KICKS}};

/* note these comments use y-axis increasing upwards */
/* /\* I-piece *\/ */
/* 0>>1 | {{ 0, 0}, {-2, 0}, { 1, 0}, {-2,-1}, { 1, 2}}  */
/* 0>>3 | {{ 0, 0}, {-1, 0}, { 2, 0}, {-1, 2}, { 2,-1}}  */
/* 1>>0 | {{ 0, 0}, { 2, 0}, {-1, 0}, { 2, 1}, {-1,-2}}  */
/* 1>>2 | {{ 0, 0}, {-1, 0}, { 2, 0}, {-1, 2}, { 2,-1}}  */
/* 2>>1 | {{ 0, 0}, { 1, 0}, {-2, 0}, { 1,-2}, {-2, 1}}  */
/* 2>>3 | {{ 0, 0}, { 2, 0}, {-1, 0}, { 2, 1}, {-1,-2}}  */
/* 3>>0 | {{ 0, 0}, { 1, 0}, {-2, 0}, { 1,-2}, {-2, 1}}  */
/* 3>>2 | {{ 0, 0}, {-2, 0}, { 1, 0}, {-2,-1}, { 1, 2}}  */

/* /\* all others *\/ */
/* 0>>1 | {{ 0, 0}, {-1, 0}, {-1, 1}, { 0,-2}, {-1,-2}}  */
/* 0>>3 | {{ 0, 0}, { 1, 0}, { 1, 1}, { 0,-2}, { 1,-2}}  */
/* 1>>0 | {{ 0, 0}, { 1, 0}, { 1,-1}, { 0, 2}, { 1, 2}}  */
/* 1>>2 | {{ 0, 0}, { 1, 0}, { 1,-1}, { 0, 2}, { 1, 2}}  */
/* 2>>1 | {{ 0, 0}, {-1, 0}, {-1, 1}, { 0,-2}, {-1,-2}}  */
/* 2>>3 | {{ 0, 0}, { 1, 0}, { 1, 1}, { 0,-2}, { 1,-2}}  */
/* 3>>0 | {{ 0, 0}, {-1, 0}, {-1,-1}, { 0, 2}, {-1, 2}}  */
/* 3>>2 | {{ 0, 0}, {-1, 0}, {-1,-1}, { 0, 2}, {-1, 2}}  */

/* 180 degree kicks. using no kicks (only try (0,0)) for now */
/* { */
/*     {{ 0, 0},{ 1, 0},{ 2, 0},{ 1, 1},{ 2, 1}},  // 0>>2 */
/*     {{ 0, 0},{ 0, 1},{ 0, 2},{-1, 1},{-1, 2}},  // 1>>3 */
/*     {{ 0, 0},{-1, 0},{-2, 0},{-1,-1},{-2,-1}},  // 2>>0 */
/*     {{ 0, 0},{ 0, 1},{ 0, 2},{ 1, 1},{ 1, 2}},  // 3>>1 */
/* }; */
/*  */
/* { */
/*     {{ 0, 0},{-1, 0},{-2, 0},{ 1, 0},{ 2, 0}},// 0>>2 */
/*     {{ 0, 0},{ 0, 1},{ 0, 2},{ 0,-1},{ 0,-2}},// 1>>3 */
/*     {{ 0, 0},{ 1, 0},{ 2, 0},{-1, 0},{-2, 0}},// 2>>0 */
/*     {{ 0, 0},{ 0, 1},{ 0, 2},{ 0,-1},{ 0,-2}},// 3>>1 */
/* }; */

int bag_fullness = 7;
char bag[7];

/* at least a little random */
shape_t rand_shape() {
    if (bag_fullness == 0) {
        memset(bag, 0, sizeof bag);
        bag_fullness = 7;
    }
    int r = rand() % bag_fullness;
    int p;
    for (p = 0; p < 7; p++) {
        if (bag[p] == 0) {
            if (r == 0) {
                bag[p] = 1;
                break;
            }
            r--;
        }
    }
    bag_fullness--;
    return p + 1;
}

void get_cells(piece_t p, pos_t out[4]) {
    for (int i = 0; i < 4; i++) {
        pos_t cell = SHAPES[p.angle & 3][p.s][i];
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

game_t *new_game() {
    game_t *g = calloc(sizeof(game_t), 1);
    g->p = new_piece(0);
    for (int i = 0; i < PIECE_PREVIEWS; i++) {
        g->preview[i] = rand_shape();
    }
    return g;
}

/* Return 1 if p overlaps with any placed piece in g */
int check_dead(game_t *g, const piece_t *const p) {
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
    return 0;
}

int _move_lr(game_t *g, int diff) {
    int old_x = g->p.pos.x;
    piece_t new_p = g->p;
    new_p.pos.x = old_x + diff;

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
    return 1;
}

/* Rotate a test piece and try each of the five coordinates in the kick list
 * (where 0,0 is tried first). If all fail, don't rotate */
int _move_rot(game_t *g, int old_a, int new_a) {
    const pos_t(*kicklist)[5];
    if (g->p.s == P_O) {
        return 0;
    } else if (g->p.s == P_I) {
        kicklist = &KICKS_I[old_a & 3][new_a & 3];
    } else {
        kicklist = &KICKS_A[old_a & 3][new_a & 3];
    }

    for (int i = 0; i < 5; i++) {
        /* printf("ROT: trying pos %d: (%d, %d)\n", i, (*kicklist)[i].x, */
        /*        (*kicklist)[i].y); */
        piece_t new_p = g->p;
        new_p.angle = new_a;
        new_p.pos.x += (*kicklist)[i].x;
        new_p.pos.y += (*kicklist)[i].y;

        pos_t cells[4];
        get_cells(new_p, cells);
        int min_x = min4(cells[0].x, cells[1].x, cells[2].x, cells[3].x);
        int max_x = max4(cells[0].x, cells[1].x, cells[2].x, cells[3].x);
        int max_y = max4(cells[0].y, cells[1].y, cells[2].y, cells[3].y);

        if (min_x >= 0 && max_x < BOARD_W && max_y < BOARD_H &&
            !check_dead(g, &new_p)) {
            /* printf("ROT: Success\n"); */
            g->p = new_p;
            return 0;
        }
        /* printf("ROT: Failed. L ok: %d, R ok: %d, D ok: %d, checkdead ok: " */
        /*        "%d\n", */
        /*        min_x >= 0, max_x < BOARD_W, max_y < BOARD_H, */
        /*        !check_dead(g, &new_p)); */
    }

    return 1;
}

int move_rot_l(game_t *g) {
    return _move_rot(g, g->p.angle, (g->p.angle - 1) & 3);
}
int move_rot_r(game_t *g) {
    return _move_rot(g, g->p.angle, (g->p.angle + 1) & 3);
}
int move_rot_180(game_t *g) {
    return _move_rot(g, g->p.angle, (g->p.angle + 2) & 3);
}

/* can fail due to no space to swap the piece */
int move_hold(game_t *g) {
    if (g->held == P_NONE) {
        piece_t test_p = new_piece(g->preview[0]);
        if (check_dead(g, &test_p)) {
            return 1;
        }
        g->held = g->p.s;
        advance_shape(g);
    } else {
        piece_t new_p = new_piece(g->held);
        if (check_dead(g, &new_p)) {
            return 1;
        }
        g->held = g->p.s;
        g->p = new_p;
    }
    return 0;
}

/* just for testing the game */
/* handle inputs until drop, clear lines, spawn new piece, check for death */
int add_piece_manual(game_t *g) {
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

move game_moves[] = {{"left", &move_left},       {"right", &move_right},
                     {"down", &move_down},       {"drop", &move_drop},
                     {"rot_l", &move_rot_l},     {"rot_r", &move_rot_r},
                     {"rot_180", &move_rot_180}, {"hold", &move_hold}};

score_t play_manual() {
    set_up_term();
    srand(time(NULL));
    int done = 0;
    game_t *g = new_game();
    do {
        done = add_piece_manual(g);
    } while (!done);

    score_t score = g->score;
    printf("Score: %llu\n", score);
    restore_term();
    free(g);
    return score;
}
