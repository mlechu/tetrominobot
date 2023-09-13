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
        printf("name: %s, n: %lld", name, n);
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

/* line: */
/* '\n' */
/* | exp '\n'  { printf ("\t%d\n", $1); } */
/* ; */

tbot:
'{' stmts '}' { printf("\ttbot\n");}
;

fcall:
"call" '(' GFUNC ')' { printf("\tfcall\n");}
;

stmts:
%empty
| stmt semicolon.opt stmts { printf("\tstmts\n");}
;

ifelse:
IF '(' exp ')' '{' stmts '}'

stmt:
IF '(' exp ')' '{' stmts '}' ELSE '{' stmts '}'  { printf("\tifelse\n");}
| MEM '[' exp ']' '=' exp { printf("\tmemexp\n");}
| MEM '[' exp ']' '=' fcall { printf("\tmemfcall\n");}
| fcall
/* or macro call? */
;

var:
"mem"
| "piece_counter"    { $$ = (int)g->p.s; }
| "score"            { $$ = (int)g->score; }
| "piece_type"       { $$ = (int)g->p.s; }
| "piece_x"          { $$ = (int)g->p.s; }
| "piece_y"          { $$ = (int)g->p.s; }
| "ghost_y"          { $$ = (int)g->p.s; }
| "piece_angle"      { $$ = (int)g->p.s; }
| "hold_piece_type"  { $$ = (int)g->p.s; }
| "board"            { $$ = (int)g->p.s; }
| fcall
;

binop:
exp "||" exp { $$ = $1 || $3; }
| exp "&&" exp { $$ = $1 && $3; }
| exp '|' exp { $$ = $1 | $3; }
| exp '^' exp { $$ = $1 ^ $3; }
| exp '&' exp { $$ = $1 & $3; }
| exp "==" exp { $$ = $1 == $3; }
| exp "!=" exp { $$ = $1 != $3; }
| exp '>' exp { $$ = $1 > $3; }
| exp ">=" exp { $$ = $1 >= $3; }
| exp '<' exp { $$ = $1 < $3; }
| exp "<=" exp { $$ = $1 <= $3; }
| exp "<<" exp { $$ = $1 << $3; }
| exp ">>" exp { $$ = $1 >> $3; }
| exp '+' exp { $$ = $1 + $3; }
| exp '-' exp { $$ = $1 - $3; }
| exp '*' exp { $$ = $1 * $3; }
| exp '/' exp { $$ = $1 / $3; }
| exp '%' exp { $$ = $1 % $3; }
;

exp:
var
| NUM
| binop
| '~' exp              { $$ = ~$2;           }
| '-' exp  %prec NEG   { $$ = -$2;           }
| '!' exp              { $$ = !$2;           }
| '(' exp ')'          { $$ = $2;            }
| exp '?' exp ':' exp  { $$ = ($1 ? $3 : $5);}
;

semicolon.opt: | ';';

%%

void yyerror (char *prog, uint64_t *ppos, game_t *g, char *s) {
    fprintf (stderr, "%s\n", s);
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
        case '\n':
            ppos++;
        }
    }
    return ppos;
}

uint64_t till_ws(char *p, uint64_t ppos) {
    while (p && isgraph(p[ppos])) {
        ppos++;
    }
    return ppos;
}

typedef struct {
    char *s;
    int yyshit;
} tokdef_t;

tokdef_t toks[] = {
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
    {"call", CALL}
};


int toksearch(char *tok, uint64_t l) {
    int toksn = (sizeof(toks)/ sizeof(tokdef_t));
    for (int i = 0; i < toksn; i++) {
        if (!strncmp(tok, toks[i].s, l)) {
            printf("\ttokserach found %s: \n", toks[i].s);
            return toks[i].yyshit;
        }
    }
    return YYUNDEF;
}

int yylex (char *prog, uint64_t *ppos, game_t *g) {
    /* yydebug = 1; */
    puts("\tlexing...");
    char *prog_0 = prog;
    char *ws = " \t\n";

    *ppos = eat_ws(prog, *ppos);
    uint64_t p = *ppos;
    uint64_t pend = p + strcspn(prog + p, ws);
    int out = YYUNDEF;

    if (isdigit(prog[p])) {
        /* Integers */

        pend = p + strspn(prog + p, "01234567890");
        if (sscanf (prog + p, "%d", &yylval) != 1) {
            puts("bad number fucko");
            abort ();
        }
        printf("\tnum: %d\n", yylval);
        out = NUM;

    } else if (isalpha(prog[p])) {
        pend = p;
        while (isalpha(prog[pend])) {
            pend++;
        }

        /* keywords */
        out = toksearch(prog + p, pend - p);

        if (out == YYUNDEF && isfunc(prog + p, pend - p)) {

            puts("\tgfunc");
            out = GFUNC;
        } else if (out == YYUNDEF) {
            puts("heyeyyyyyyyyyyyyyyyyy");
            printf("\talpha");
            /* if (scanf ("%s", &yylval) != 1) { */
            /*     abort (); */
            /* } */
        }

    } else if (prog[p] == EOF) {
        out = YYEOF;

    } else {
        printf("\tlex returning char: %c\n", prog[p]);
        pend = *ppos + 1;
        out = prog[p];
    }

    *ppos = pend;
    return out;
}

/* int main (int argc, char **argv) { */
/*     char *prog = "if (1) { move_drop() }"; */
/*     return yyparse (prog, NULL); */
/* } */
