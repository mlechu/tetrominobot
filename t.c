#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "game.h"
#include "robot.h"

/* #include "util.h" */

// considering a global timeout (seconds) for infra reasons
game_t global_game = {0};

/* move game_moves[] = { */
/*     {"left", &move_left},   {"right", &move_right},     {"down", &move_down},
 */
/*     {"sdrop", &move_sdrop}, {"drop", &move_drop},       {"rot_l",
 * &move_rot_l}, */
/*     {"rot_r", &move_rot_r}, {"rot_180", &move_rot_180}, {"hold",
 * &move_hold}}; */

/* typedef struct { */
/*     uint64_t name; */
/*     // ... */
/*     uint64_t nonsense; */
/*     uint64_t enabled; */
/*     uint32_t latest_use; */
/*     uint32_t use_count; */
/*     // ... */
/* } rule; */

/* typedef struct { */
/*     char *name; */
/*     int (*check)(); */
/*     int (*call)(); */
/* } rule_t; */
/*  */
/* // rule compiler */
/* rule_t *parse_prog(char *in) { */
/*     puts("parse_prog called"); */
/*     return NULL; */
/* } */
/*  */
/* int exec_rule(char *rname, rule_t *rules, int r_count) { */
/*     for (int i = 0; i < r_count; i++) { */
/*         if (rules[i].name == rname || rules[i].check()) { */
/*             return rules[i].call(); */
/*         } */
/*     } */
/*     return 1; // should not happen with die ruel */
/* } */

///////// checkable functions
/* int check_round() {} */

/*
 * BUGGY: This will return the first cell of the shape || board, which may or
 * may not be on the board at the time. maybe?
 */
/* int check_shape() {} */
// move_restart?

// return 1 when done
/* int add_piece(game_t *g, rule_t *rules, int r_count) { */
/*     puts("play() called"); */
/*  */
/*     while (1) { */
/*         shape_t s = rand_shape(); */
/*         // do something with s */
/*  */
/*         int done_p = 0; */
/*         for (int i = 0; i < PIECE_TIMEOUT && !done_p; i++) { */
/*             done_p = exec_rule(NULL, rules, r_count); */
/*             /\* print_game(g); *\/ */
/*         } */
/*  */
/*         if (check_dead(g, &g->p)) { */
/*             return 1; */
/*         } */
/*     } */
/* } */

int main(int argc, char **argv) {
    if (argc == 2 && !strcmp(argv[1], "-p")) {
        play_manual(&global_game);
    } else {
        char retry[3] = {0};

        /* do { */
        game_t *g = new_game(&global_game);
        tbot_t *t = tbot_new();
        /* t->debug = 1; */
        tbot_run(t, g);

        print_game(g);
        printf("Score: %llu\n", g->score);
        /* puts("Retry? (y/N)"); */
        /* printf("> "); */
        /* fgets(retry, 3, stdin); */
        /* free(g); // free each time? */
        /* } while (retry[0] == 'y' || retry[0] == 'Y'); */
    }

    return 0;
}
