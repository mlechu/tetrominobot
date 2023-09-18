#include "robot.h"
#include "out/parse.h"
#include <stdio.h>
#include <strings.h>

tbot_t global_tbot = {0};

tbot_t *tbot_new(void) {
    memset(&global_tbot, 0, sizeof(tbot_t));
    puts("Build your own tetrominobot!");
    puts("Enter your bot description:");
    printf("> ");

    fgets(global_tbot.prog, PROG_SIZE, stdin);
    printf("program: %s\n", global_tbot.prog);
    return &global_tbot;
}

int tbot_run(tbot_t *t, game_t *g) {
    uint64_t ppos = 0;

    /* this is horrible */
    for (int i = 0; i < 2000; i++) {
        ppos = 0;
        yyparse((char *)&t->prog, &ppos, g, (uint64_t *)&t->mem);
        if (check_dead(g, &g->p)) {
            break;
        }
        if (t->debug) {
            print_game(g);
        }
    }

    return 1;
}

fte_t gfunc_table[] = {
    {"left", move_left},       {"right", move_right},
    {"down", move_down},       {"drop", move_drop},
    {"rot_l", move_rot_l},     {"rot_r", move_rot_r},
    {"rot_180", move_rot_180}, {"hold", move_hold},
    {"sdrop", move_sdrop}
};


int gfunc_n = sizeof(gfunc_table) / sizeof(fte_t);

int gfunc_i(char *name, uint64_t n) {
    for (int i = 0; i < gfunc_n; i++) {
        if (!strncmp(gfunc_table[i].name, name, n)) {
            return i;
        }
    }
    return -1;
}

int gfunc_call(int i, game_t *g) {
    printf("CALLING %s\n", gfunc_table[i].name);
    print_game(g);
    return gfunc_table[i].f(g);
}
