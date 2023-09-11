/* Infix notation calculator. */

%{

#include <math.h>
#include <stdio.h>
#include <string.h>
#include <strings.h>

    int yylex (void);
    void yyerror (char const *);

    %}

/* Bison declarations. */
%define api.value.type union

%token <int32_t> NUM
 /* %token  <int32_t> '-' */
 /* %token  <int32_t> '+' */
%left '-' '+'
%left '*' '/' LSHIFT
 /* %precedence NEG   /\* negation--unary minus *\/ */
 /* %right '^'        /\* exponentiation *\/ */
%token  <int32_t> LSHIFT "<<"
%nterm <int32_t> exp
 /* %left '%' */

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
/* | exp '*' exp        { $$ = $1 * $3;      } */
/* | exp '/' exp        { $$ = $1 / $3;      } */
/* | exp '%' exp        { $$ = $1 % $3;      } */
| exp LSHIFT exp        { $$ = $1 + $3;      }
/* | '~' exp  %prec NEG { $$ = ~$2;          } */
/* | '-' exp  %prec NEG { $$ = -$2;          } */
/* | exp '^' exp        { $$ = $1 ^ $3; } */
/* | '(' exp ')'        { $$ = $2;           } */
;

/* semicolon.opt: | ";"; */

%%


/* Called by yyparse on error. */
void
yyerror (char const *s)
{
    fprintf (stderr, "%s\n", s);
}

/* The lexical analyzer returns a double floating point
   number on the stack and the token NUM, or the numeric code
   of the character read if not a number.  It skips all blanks
   and tabs, and returns 0 for end-of-input. */

#include <ctype.h>
#include <stdlib.h>

int yylex (void)
{
    /* char *prog = "robot { call(drop) }"; */
    /* char *ws = " \t\n"; */
    /* int len = strcspn() */
    int c = getchar ();
    while (c == ' ' || c == '\t')
        c = getchar ();
    if (isdigit (c))
    {
        ungetc (c, stdin);
        if (scanf ("%d", &yylval) != 1)
            abort ();
        return NUM;
    }
    else if (c == EOF)
        return YYEOF;
    else
        return c;
}

int
main (int argc, char **argv)
{
    return yyparse ();
}
