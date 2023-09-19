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
