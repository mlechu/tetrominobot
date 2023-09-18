%{
#include <ctype.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <strings.h>
#include <stdlib.h>

#include "robot.h"
#include "game.h"

    int yyparse (char *prog, uint64_t *ppos, game_t *g, uint64_t *g_mem);
    int yylex (char *prog, uint64_t *ppos, game_t *g, uint64_t *g_mem);
    void yyerror (char *prog, uint64_t *ppos, game_t *g, uint64_t *g_mem, char *s);


    /* hack for conditional execution
     *
     * Whether or not the current block can have effects on the game
     * When parsing, this will be set to 0 to disable a block.
     * The block itself will keep track of whether it was zeroed (on the yacc stack)
     */
    int cond_active = 1;

    %}

/* Highest line number = highest precedence */
%define api.value.type {int32_t}
/* %define parse.trace */
%param {char *prog}
%param {uint64_t *ppos}
%param {game_t *g}
%param {uint64_t *g_mem}

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
%token PRINT "print"

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

%% /* The grammar follows. */

input:
%empty
| input tbot
;

tbot:
'{' stmts '}' { /* printf("============================\ntbot done!\n"); */}
;

fcall:
"call" '(' GFUNC ')' {
    if (cond_active) {
        $$ = gfunc_call($3, g);
    } else {
        $$ = 0xbad;
        /* printf("not called: %s\n", gfunc_table[$3].name); */
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
    if (cond_active) {
        g_mem[$3] = $6;
        $$ = $6; /* maybe? */
        /* printf("mem assigned\n"); */
    } else {
        $$ = 0xbad;
        /* printf("mem not changed\n"); */
    }
}
| fcall
| PRINT '(' exp ')' { printf("%d\n", $3); }
/* or macro call? */
;

/* value of the midrule action = 1 if it set cond_active to 0 and needs to reset it after */
cond_if:
IF '(' exp ')'         { if (cond_active && !$3) { cond_active = 0; $$ = 1; } else { $$ = 0; } }
'{' stmts '}'          { if ($5) { cond_active = 1; }
    if (cond_active && !!$3) { cond_active = 0; $$ = 1; } else { $$ = 0; } }
cond_else              { if ($9) { cond_active = 1; } }
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
| "ghost_y"                     { $$ = ghost_pos(g); }
| "piece_angle"                 { $$ = (int)g->p.angle; }
| "hold_piece_type"             { $$ = (int)g->held; }
| fcall                         { $$ = $1; }
| exp "||" exp                  { $$ = $1 || $3; }
| exp "&&" exp                  { $$ = $1 && $3; }
| exp '|' exp                   { $$ = $1 |  $3; }
| exp '^' exp                   { $$ = $1 ^  $3; }
| exp '&' exp                   { $$ = $1 &  $3; }
| exp "==" exp                  { $$ = $1 == $3; }
| exp "!=" exp                  { $$ = $1 != $3; }
| exp '>' exp                   { $$ = $1 >  $3; }
| exp ">=" exp                  { $$ = $1 >= $3; }
| exp '<' exp                   { $$ = $1 <  $3; }
| exp "<=" exp                  { $$ = $1 <= $3; }
| exp "<<" exp                  { $$ = $1 << $3; }
| exp ">>" exp                  { $$ = $1 >> $3; }
| exp '+' exp                   { $$ = $1 +  $3; }
| exp '-' exp                   { $$ = $1 -  $3; }
| exp '*' exp                   { $$ = $1 *  $3; }
| exp '/' exp                   { $$ = $1 /  $3; }
| exp '%' exp                   { $$ = $1 %  $3; }
| '~' exp                       { $$ = ~$2;           }
| '-' exp  %prec NEG            { $$ = -$2;           }
| '!' exp                       { $$ = !$2;           }
| '(' exp ')'                   { $$ = $2;            }
| exp '?' exp ':' exp           { $$ = ($1 ? $3 : $5);}
;

semicolon.opt:
%empty
| ';';

%%

void yyerror (char *prog, uint64_t *ppos, game_t *g, uint64_t *g_mem, char *s) {
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
    {"print", PRINT},
    {0, 0}
};

/* Returns position.
 * l (until whitespace) must be at least the length of the search term
 */
int toksearch(tokdef_t *tlist, char *tok, uint64_t l) {
    for (int i = 0; tlist[i].s != NULL; i++) {
        if (l >= strlen(tlist[i].s) && !strncmp(tok, tlist[i].s, l)) {
            /* printf(" %s ", tlist[i].s); */
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
            /* printf("%c", prog[p]); */
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
        /* printf("%d", yylval); */
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
