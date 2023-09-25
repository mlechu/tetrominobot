#include "robot.h"
#include "game.h"
#include "out/parse.h"
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

const gfte_t gfunc_table[] = {{"left", move_left},       {"right", move_right},
                              {"down", move_down},       {"drop", move_drop},
                              {"rot_l", move_rot_l},     {"rot_r", move_rot_r},
                              {"rot_180", move_rot_180}, {"hold", move_hold},
                              {"sdrop", move_sdrop},     {0}};

tbot_t global_tbot = {0};

tbot_t *tbot_new(tbot_t *t, char *name, char *prog, int debug) {
    if (!t) {
        t = &global_tbot;
    }
    memset(t, 0, sizeof(tbot_t));
    *t = (tbot_t){.name = name, .prog = prog, .debug = debug};

    uint16_t not_random = 0;
    int plen = strlen(t->prog);
    /* isgraph currently corresponds to all characters yylex accepts */
    for (int i = 0; i < plen && (isgraph(t->prog[i])); i++) {
        not_random += t->prog[i];
    }
    /* printf("%d", not_random); */
    srand(not_random);

    if (t->debug) {
        printf("program: %s\n", t->prog);
    }

    return t;
}

int tbot_run(tbot_t *t, game_t *g) {
    /* this is horrible */
    for (int i = 0; i < BOT_ITERATIONS; i++) {
        t->ppos = 0;
        yyparse(g, t);
        if (check_dead(g, &g->p)) {
            break;
        }
        if (t->debug) {
            print_game(g);
        }
    }
    return 1;
}

int gfunc_i(char *name, uint64_t n) {
    for (int i = 0; gfunc_table[i].name != NULL; i++) {
        if (!strncmp(gfunc_table[i].name, name, n)) {
            return i;
        }
    }
    return -1;
}

int gfunc_call(int i, game_t *g) {
    int ok = gfunc_table[i].f(g);
    return ok;
}

mem_t tbot_mem(tbot_t *t, int i) {
    if (i < 0 || i >= MEM_COUNT) {
        puts("Out of bounds");
        exit(1);
    }
    return t->mem[i];
}

void tbot_mem_write(tbot_t *t, int i, mem_t val) {
    if (i < 0 || i >= MEM_COUNT) {
        puts("Out of bounds");
        exit(1);
    }
    t->mem[i] = val;
}

int tbot_board(game_t *g, int y, int x) {
    if (x < 0 || y < 0 || x >= BOARD_W || y >= BOARD_H) {
        puts("Out of bounds");
        exit(1);
    }
    return g->board[y][x];
}

int tbot_preview(game_t *g, int i) {
    if (i < 0 || i >= PIECE_PREVIEWS) {
        puts("Out of bounds");
        exit(1);
    }
    return g->preview[i];
}
