#ifndef ROBOT_H
#define ROBOT_H

#include <stdint.h>
#include "game.h"

#define MEM_COUNT 0x100
#define PROG_SIZE 0x8000
#define PIECE_TIMEOUT 0x100

typedef int64_t mem_t;

typedef struct {
    int debug;
    uint64_t ppos;
    char prog[PROG_SIZE];
    mem_t mem[MEM_COUNT];
} tbot_t;

tbot_t * tbot_new(void);
int tbot_run(tbot_t *t, game_t *g);

typedef shape_t(gfunc_t)(game_t *g);

typedef struct {
    char *name;
    gfunc_t *f;
} fte_t;

int gfunc_i(char *name, uint64_t n);
int gfunc_call(int i, game_t *g);

/* checked array accesses */
mem_t tbot_mem(tbot_t *t, int i);
void tbot_mem_write(tbot_t *t, int i, mem_t val);
int tbot_board(game_t *g, int y, int x);
int tbot_preview(game_t *g, int i);


#endif
