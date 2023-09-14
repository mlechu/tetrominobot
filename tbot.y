/* Infix notation calculator. */

%{

#include <math.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <strings.h>
#include "game.h"

    typedef shape_t (gfunc_t) (game_t * g);

    typedef struct {
        char *name;
        gfunc_t *f;
    } fte_t;


    fte_t functable[] = {
        {"left", move_left},       {"right", move_right},
        {"down", move_down},       {"drop", move_drop},
        {"rot_l", move_rot_l},     {"rot_r", move_rot_r},
        {"rot_180", move_rot_180}, {"hold", move_hold},
        {"die", move_drop} /* todo  */
    };

    int game_funcs = sizeof(functable) / sizeof(fte_t);

    int isfunc(char *name, uint64_t n) {
        printf("\tgfunc name: %.*s\n", n, name);
        for (int i = 0; i < game_funcs; i++) {
            if (!strncmp(functable[i].name, name, n)) {
                return 1;
            }
        }
        return 0;
    }


    int call_func(char *name, uint64_t n, game_t *g) {
        for (int i = 0; i < game_funcs; i++) {
            if (!strncmp(functable[i].name, name, n)) {
                return functable[i].f(g);
            }
        }
        return -1;
    }

    int yyparse (char *prog, uint64_t *ppos, game_t *g);
    int yylex (char *prog, uint64_t *ppos, game_t *g);
    void yyerror (char *prog, uint64_t *ppos, game_t *g, char *s);


    %}

/* Highest line number = highest precedence */
%define api.value.type {int32_t}
%define parse.trace
%param {char *prog}
%param {uint64_t *ppos}
%param {game_t *g}

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
'{' stmts '}' { printf("\t\ttbot\n");}
;

fcall:
"call" '(' GFUNC ')' { printf("\t\tfcall\n");}
;

stmts:
%empty
| stmt semicolon.opt stmts { printf("\t\tstmts\n");}
;

stmt:
ifelse
| mem '=' exp { printf("\t\tmem_assign\n"); }
| fcall
/* or macro call? */
;

ifelse:
IF '(' exp ')' '{' stmts '}'
| IF '(' exp ')' '{' stmts '}' ELSE '{' stmts '}'
| IF '(' exp ')' '{' stmts '}' ELSE ifelse
;

/* writable vars */
mem:
MEM '[' exp ']' { printf("\t\tmem\n");}
;

exp:
NUM
| mem
| BOARD '[' exp ']' '[' exp ']' { $$ = (int)g->board[$3][$6]; }
| "piece_counter"               { $$ = (int)g->p.s; } // todo
| "score"                       { $$ = (int)g->score; }
| "piece_type"                  { $$ = (int)g->p.s; }
| "piece_x"                     { $$ = (int)g->p.pos.x; }
| "piece_y"                     { $$ = (int)g->p.pos.y; }
| "ghost_y"                     { $$ = (int)g->p.s; } // todo
| "piece_angle"                 { $$ = (int)g->p.angle; }
| "hold_piece_type"             { $$ = (int)g->held; }
| fcall
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

void yyerror (char *prog, uint64_t *ppos, game_t *g, char *s) {
    fprintf (stderr, "at pos %lld (\"%c\"): %s\n", *ppos, prog[*ppos], s);
}

#include <ctype.h>
#include <stdlib.h>

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
            printf("\tSTR %s\n", tlist[i].s);
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
int yylex (char *prog, uint64_t *ppos, game_t *g) {
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
            printf("\t%c\n", prog[p]);
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
        printf("\t%d\n", yylval);
        *ppos = end;
        return NUM;

    } else if (isalpha(prog[p]) || prog[p] == '_') {
        int end = p;
        while (isalnum(prog[end]) || prog[end] == '_') {
            end++;
        }
        *ppos = end;

        int at_i = toksearch(alpha_toks, prog + p, end - p);
        if (at_i != -1) {
            return alpha_toks[at_i].yyshit;
        } else if (isfunc(prog + p, end - p)) {
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
