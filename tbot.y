/* Infix notation calculator. */

%{

#include <math.h>
#include <stdio.h>
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
        {"rot_180", move_rot_180}, {"hold", move_hold}
    };

    int game_funcs = 8;

    int isfunc(char *name) {
        for (int i = 0; i < game_funcs; i++) {
            if (!strcmp(functable[i].name, name)) {
                return 1;
            }
        }
        return 0;
    }


    int call_func(char *name, game_t *g) {
        for (int i = 0; i < game_funcs; i++) {
            if (!strcmp(functable[i].name, name)) {
                return functable[i].f(g);
            }
        }
        return -1;
    }

    int yyparse (char *prog, game_t *g);
    int yylex (char *prog, game_t *g);
    void yyerror (char *prog, game_t *g, char *s);


    %}

/* Highest line number = highest precedence */
%define api.value.type {int32_t}
%param {char *prog}
%param {game_t *g}

/* TODO https://en.cppreference.com/w/c/language/operator_precedence */
%token GFUNC
%token NUM
%right '-' '+'
%left '%'
%left '*' '/'
%left LSHIFT
%precedence NEG   /* negation--unary minus */
%right '^'        /* exponentiation */
%token  LSHIFT "<<"
%nterm exp

%% /* The grammar follows. */

input:
%empty
| input line
;

line:
'\n'
| exp '\n'  { printf ("\t%d\n", $1); }
;

exp:
NUM
| exp '+' exp        { $$ = $1 + $3;      }
| exp '-' exp        { $$ = $1 - $3;      }
| exp '*' exp        { $$ = $1 * $3;      }
| exp '/' exp        { $$ = $1 / $3;      }
| exp '%' exp        { $$ = $1 % $3;      }
| exp LSHIFT exp     { $$ = $1 + $3;      }
| '~' exp  %prec NEG { $$ = ~$2;          }
| '-' exp  %prec NEG { $$ = -$2;          }
| exp '^' exp        { $$ = $1 ^ $3;      }
| '(' exp ')'        { $$ = $2;           }
;

/* semicolon.opt: | ";"; */

%%

void yyerror (char *prog, game_t *g, char *s) {
    fprintf (stderr, "%s\n", s);
}

#include <ctype.h>
#include <stdlib.h>

int yylex (char *prog, game_t *g) {
    char *ws = " \t\n";
    while (*prog == ' ' || *prog == '\t' || *prog == '\n') {
        prog++;
    }

    if (isdigit(*prog)) {
        if (scanf ("%d", &yylval) != 1) {
            abort ();
        }
        return NUM;
    } else if (isalpha(*prog)) {
        int l = strcspn(prog, ws);
        char *tok = strndup(prog, l);
        if (isfunc(tok)) {
            return GFUNC;
        } else {
            printf("alpha: %s", tok);
            /* if (scanf ("%s", &yylval) != 1) { */
            /*     abort (); */
            /* } */
        }
        free(tok);
    } else if (*prog == EOF) {
        return YYEOF;
    } else {
        return *prog;
    }
    return YYUNDEF;
}

/* int main (int argc, char **argv) { */
/*     char *prog = "if (1) { move_drop() }"; */
/*     return yyparse (prog, NULL); */
/* } */
