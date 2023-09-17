%{
#include <ctype.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <strings.h>
#include <stdlib.h>


#include "game.h"

    typedef shape_t (gfunc_t) (game_t * g);

    typedef struct {
        char *name;
        gfunc_t *f;
    } fte_t;

    fte_t gfunc_table[] = {
        {"left", move_left},       {"right", move_right},
        {"down", move_down},       {"drop", move_drop},
        {"rot_l", move_rot_l},     {"rot_r", move_rot_r},
        {"rot_180", move_rot_180}, {"hold", move_hold},
        {"die", move_drop} /* todo  */
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
        printf("\nCALLING %s\n", gfunc_table[i].name);
        print_game(g);
        return gfunc_table[i].f(g);
    }

    /* int gfunc_call(char *name, uint64_t n, game_t *g) { */
    /*     for (int i = 0; i < gfunc_n; i++) { */
    /*         if (!strncmp(gfunc_table[i].name, name, n)) { */
    /*             return gfunc_table[i].f(g); */
    /*         } */
    /*     } */
    /*     return -1; */
    /* } */

    int yyparse (char *prog, uint64_t *ppos, game_t *g, uint64_t *g_mem);
    int yylex (char *prog, uint64_t *ppos, game_t *g, uint64_t *g_mem);
    void yyerror (char *prog, uint64_t *ppos, game_t *g, uint64_t *g_mem, char *s);

    /* hack for conditional execution
     * things are done to reduce stack overfilling. if we know
     * we're in a false branch, we don't bother pushing new things.
     */
    char c_stack[512] = {0};
    int c_sp = 0;

    void c_push(int val) {
        c_stack[c_sp] = val;
        c_sp++;
        if (c_sp > 512) {
            puts("Too many nested contitionals");
            exit(1);
        }
        printf("\npushing %d\n", val);
        printf("\nCACTIVE STACK  [");
        for (int i = 0; i < c_sp; i++) {
            printf("%d ", c_stack[i]);
        }
        puts("]");

    }

    int c_pop() {
        c_sp--;
        if (c_sp < 0) {
            printf("What?");
            exit(1);
        }
        printf("\npopping %d\n", c_stack[c_sp]);
        printf("\nCACTIVE STACK  [");
        for (int i = 0; i < c_sp; i++) {
            printf("%d ", c_stack[i]);
        }
        puts("]");


        return c_stack[c_sp];
    }

    /* Return whether or not the current branch is the active branch
     * If yes, then we can have effects
     *
     * exclude=1 means do not count the top element
     */
    int c_active_branch(int exclude) {
        int out = 0;
        int top = c_sp - exclude;
        for (int i = 0; i < top; i++) {
            out += !!c_stack[i];
        }
        return out == top;
    }

        %}

/* Highest line number = highest precedence */
%define api.value.type {int32_t}
%define parse.trace
%param {char *prog}
%param {uint64_t *ppos}
%param {game_t *g}
%param {uint64_t *g_mem}

/* TODO https://en.cppreference.com/w/c/language/operator_precedence */
%token GFUNC
%token NUM
%token IF "if"
%token ELSE "else"
%token CALL "call"
%token MEM "mem"
%token PIECE_COUNTER "piece_counter"
%token SCORE "score"
%token PIECE_TYPE "piece_type"
%token PIECE_X "piece_x"
%token PIECE_Y "piece_y"
%token GHOST_Y "ghost_y"
%token PIECE_ANGLE "piece_angle"
%token HOLD_PIECE_TYPE "hold_piece_type"
%token BOARD "board"

%token LSHIFT "<<"
%token RSHIFT ">>"
%token LTE "<="
%token GTE ">="
%token EE "=="
%token NE "!="
%token LOR "||"
%token LAND "&&"
%right '='
%right '?' ':'
%left LOR
%left LAND
%left '|'
%left '^'
%left '&'
%left EE NE
%left '>' GTE '<' LTE
%left LSHIFT RSHIFT
%left '+' '-'
%left '*' '/' '%'
%precedence NEG
%precedence '!' '~'

 /* %nterm exp */

%% /* The grammar follows. */

input:
%empty
| input tbot
;

tbot:
'{' stmts '}' { printf("\n============================\ntbot done!\n");}
;

fcall:
"call" '(' GFUNC ')' {
    if (c_active_branch(0)) {
        $$ = gfunc_call($3, g);
    } else {
        $$ = 0xbad;
        printf("\nnot called: %s\n", gfunc_table[$3].name);
    }
}
;

stmts:
%empty
| stmt semicolon.opt stmts
;

stmt:
cond_if
| MEM '[' exp ']' '=' exp {
    if (c_active_branch(0)) {
        g_mem[$3] = $6;
        $$ = $6; /* maybe? */
        printf("\nmem assigned\n");
    } else {
        $$ = 0xbad;
        printf("\nmem not changed\n");
    }
}
| fcall
/* or macro call? */
;

cond_if:
IF '(' exp ')'         { if (c_active_branch(0)) c_push($3); }
'{' stmts '}'          { if (c_active_branch(1)) c_pop();
                         if (c_active_branch(0)) c_push(!$3); }
cond_else              { if (c_active_branch(1)) c_pop(); }
/* | IF '(' exp ')' { c_push($3); printf("\tIFELSE EXP%d\n", $3); } '{' stmts '}' */
/* ELSE '{' stmts '}' { c_pop(); c_push(!$3) } */
/* { c_pop(); } */
/* | IF '(' exp ')' { c_push($3); } '{' stmts '}' { c_pop(); } */
;

cond_else:
%empty
| ELSE '{' stmts '}'
| ELSE cond_if
;

exp:
NUM
| MEM '[' exp ']'               { $$ = g_mem[$3]; }
| BOARD '[' exp ']' '[' exp ']' { $$ = (int)g->board[$3][$6]; }
| "piece_counter"               { $$ = (int)g->p.s; } // todo
| "score"                       { $$ = (int)g->score; }
| "piece_type"                  { $$ = (int)g->p.s; }
| "piece_x"                     { $$ = (int)g->p.pos.x; }
| "piece_y"                     { $$ = (int)g->p.pos.y; }
| "ghost_y"                     { $$ = (int)g->p.s; } // todo
| "piece_angle"                 { $$ = (int)g->p.angle; }
| "hold_piece_type"             { $$ = (int)g->held; }
| fcall                         { $$ = $1; }
| exp "||" exp         { $$ = $1 || $3; }
| exp "&&" exp         { $$ = $1 && $3; }
| exp '|' exp          { $$ = $1 |  $3; }
| exp '^' exp          { $$ = $1 ^  $3; }
| exp '&' exp          { $$ = $1 &  $3; }
| exp "==" exp         { $$ = $1 == $3; }
| exp "!=" exp         { $$ = $1 != $3; }
| exp '>' exp          { $$ = $1 >  $3; }
| exp ">=" exp         { $$ = $1 >= $3; }
| exp '<' exp          { $$ = $1 <  $3; }
| exp "<=" exp         { $$ = $1 <= $3; }
| exp "<<" exp         { $$ = $1 << $3; }
| exp ">>" exp         { $$ = $1 >> $3; }
| exp '+' exp          { $$ = $1 +  $3; }
| exp '-' exp          { $$ = $1 -  $3; }
| exp '*' exp          { $$ = $1 *  $3; }
| exp '/' exp          { $$ = $1 /  $3; }
| exp '%' exp          { $$ = $1 %  $3; }
| '~' exp              { $$ = ~$2;           }
| '-' exp  %prec NEG   { $$ = -$2;           }
| '!' exp              { $$ = !$2;           }
| '(' exp ')'          { $$ = $2;            }
| exp '?' exp ':' exp  { $$ = ($1 ? $3 : $5);}
;

semicolon.opt: | ';';

%%

void yyerror (char *prog, uint64_t *ppos, game_t *g, uint64_t *g_mem, char *s) {
    c_sp = 0;
    fprintf (stderr, "at pos %lld (\"%c\"): %s\n", *ppos, prog[*ppos], s);
}

uint64_t eat_ws(char *p, uint64_t ppos) {
    while (p) {
        switch (p[ppos]) {
        default:
            return ppos;
        case ' ':
        case '\t':
        case '\r':
        case '\n':
            ppos++;
        }
    }
    return ppos;
}

/* One past last char of what is probably a token */
uint64_t til_end(char *p, uint64_t ppos) {
    while (p && isgraph(p[ppos])) {
        ppos++;
    }
    return ppos;
}

typedef struct {
    char *s;
    int yyshit;
} tokdef_t;

tokdef_t punct_toks[] = {
    {"<<", LSHIFT},
    {">>", RSHIFT},
    {"<=", LTE},
    {">=", GTE},
    {"==", EE},
    {"!=", NE},
    {"||", LOR},
    {"&&", LAND},
    {0, 0}
};

/* multi-char non-gamefunc toks */
tokdef_t alpha_toks[] = {
    {"if", IF},
    {"else", ELSE},
    {"piece_counter", PIECE_COUNTER},
    {"score", SCORE},
    {"piece_type", PIECE_TYPE},
    {"piece_x", PIECE_X},
    {"piece_y", PIECE_Y},
    {"ghost_y", GHOST_Y},
    {"piece_angle", PIECE_ANGLE},
    {"hold_piece_type", HOLD_PIECE_TYPE},
    {"board", BOARD},
    {"mem", MEM},
    {"call", CALL},
    {0, 0}
};

/* Returns position.
 * l (until whitespace) must be at least the length of the search term
 */
int toksearch(tokdef_t *tlist, char *tok, uint64_t l) {
    for (int i = 0; tlist[i].s != NULL; i++) {
        if (l >= strlen(tlist[i].s) && !strncmp(tok, tlist[i].s, l)) {
            printf(" %s ", tlist[i].s);
            return i;
        }
    }
    return -1;
}

/*
 * Eats whitespace, checks the token's first char,
 * finds token's end, and increments the ppos accordingly.
 *
 * Tokens satisfy one of the following delicate checks:
 * - (ispunct) Two-character ops and parens
 * -           Single-character ops and parens
 * - (isdigit) Digits
 * - (isalpha or _) game vars or funcs
 *
 * Treat anything else as EOF.
 */
int yylex (char *prog, uint64_t *ppos, game_t *g, uint64_t *g_mem) {
    /* yydebug = 1; */
    char *prog_0 = prog;

    *ppos = eat_ws(prog, *ppos);
    uint64_t p = *ppos;
    /* printf("PPOS \"%d\"\n", p); */
    /* printf("TOKEN START \"%x\"\n", prog[p]); */
    uint64_t max_end = til_end(prog, p);
    /* int out = YYUNDEF; */

    if (ispunct(prog[p])) {
        int t_i = toksearch(punct_toks, prog + p, max_end - p);
        if (t_i != -1) {
            /* long punct tok */
            *ppos = p + strlen(punct_toks[t_i].s);
            return punct_toks[t_i].yyshit;
        } else {
            /* one char */
            printf("%c", prog[p]);
            *ppos = p + 1;
            return prog[p];
        }

    } else if (isdigit(prog[p])) {
        int end = p;
        /* todo: hex? */
        while (isdigit(prog[end])) {
            end++;
        }
        if (sscanf(prog + p, "%d", &yylval) != 1) {
            abort();
        }
        printf("%d", yylval);
        *ppos = end;
        return NUM;

    } else if (isalpha(prog[p]) || prog[p] == '_') {
        int end = p;
        while (isalnum(prog[end]) || prog[end] == '_') {
            end++;
        }
        *ppos = end;

        int at_i = toksearch(alpha_toks, prog + p, end - p);
        int gf_i = gfunc_i(prog + p, end - p);
        if (at_i != -1) {
            return alpha_toks[at_i].yyshit;
        } else if (gf_i != -1) {
            yylval = gf_i;
            return GFUNC;
        } else {
            return YYUNDEF;
        }
    } else {
        return YYEOF;
    }
}

/* int main (int argc, char **argv) { */
/*     char *prog = "if (1) { move_drop() }"; */
/*     return yyparse (prog, NULL); */
/* } */
