%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int yylex(void);
void yyerror(const char *s);
extern FILE *yyin;
extern int yylineno;

%}

%union {
    char *str;
}

%token TASK RUN EVERY DAY WEEK ON AT AFTER BEFORE DEPENDS IF
%token SUCCESS FAILURE
%token MONDAY TUESDAY WEDNESDAY THURSDAY FRIDAY SATURDAY SUNDAY
%token <str> IDENTIFIER FILENAME TIME
%token LCURL RCURL

%type <str> identifier filename time day_of_week condition

%%

program : tasks ;

tasks : task
        | task tasks 
    ;

task : TASK identifier {
           printf("Executing Task: %s\n", $2);
           free($2); 
        }
       LCURL run_command command RCURL{ printf("\n"); }
    ;

command : schedule_command
        | dependency_command 
    ;

run_command : RUN filename {
                printf("  Script: \"%s\"\n", $2);
                free($2);
            }
        ;

schedule_command : AT time {
                        printf("  Schedule: AT %s\n", $2);
                   }
                 | EVERY DAY AT time {
                        printf("  Schedule: EVERY DAY AT %s\n", $4);
                   }
                 | EVERY WEEK ON day_of_week AT time {
                        printf("  Schedule: EVERY WEEK ON %s AT %s\n", $4, $6);
                   }
        ;

day_of_week : MONDAY { $$ = strdup("MONDAY"); }
            | TUESDAY { $$ = strdup("TUESDAY"); }
            | WEDNESDAY { $$ = strdup("WEDNESDAY"); }
            | THURSDAY { $$ = strdup("THURSDAY"); }
            | FRIDAY { $$ = strdup("FRIDAY"); }
            | SATURDAY { $$ = strdup("SATURDAY"); }
            | SUNDAY { $$ = strdup("SUNDAY"); } 
        ;

dependency_command : AFTER identifier { printf("  Depends on: %s\n", $2); }
                    opt_conditional_command
                 | BEFORE identifier { printf("  Before: %s\n", $2); }
                 | DEPENDS ON identifier { printf("  Depends on: %s\n", $3); }
        ;

opt_conditional_command : conditional_command
                            | /* empty */ 
        ;

conditional_command : IF condition {
                        printf("  Condition: %s\n", $2);
                    }
        ;

condition : SUCCESS { $$ = strdup("success"); }
          | FAILURE { $$ = strdup("failure"); } 
        ;

filename : FILENAME { $$ = $1; } 
        ;

identifier : IDENTIFIER 
        ;

time : TIME 
        ;

%%

void yyerror(const char *s) {
    const char *red = "\033[31m";
    const char *reset = "\033[0m";

    fprintf(stderr, "\n>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n");
    fprintf(stderr, "%s", red);


    if (strstr(s, "unexpected") != NULL) {
        fprintf(stderr, ">> %d : Unexpected token at line %d\n", yylineno, yylineno);
    } else if (strstr(s, "expecting") != NULL) {
        fprintf(stderr, ">> %d : Missing or misplaced token at line %d\n", yylineno, yylineno);
    } else {
        fprintf(stderr, ">> %d : Syntax error at line %d\n", yylineno, yylineno);
    }
    fprintf(stderr, "%s", reset);
    fprintf(stderr, ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n%s", reset);
}

int main(int argc, char *argv[]) {
    int rc;
    FILE *in = NULL;

    if (argc > 2 || argc < 2) {
        fprintf(stderr, "Usage: %s [input_file]\n", argv[0]);
        return 1;
    }

    if (argc == 2) {
        in = fopen(argv[1], "r");
        if (!in) {
            perror("Failed to open input file");
            return 1;
        }
        yyin = in;
    }

    printf("Parsing TaskLang++ input...\n\n");
    
    printf("--- EXECUTION START ---\n\n");
    rc = yyparse();
    if (rc == 0) {
        printf("--- EXECUTION COMPLETE ---\n");
    }

    if (in) {
        fclose(in);
    }

    return rc;
}
int yywrap(){
    return 1;
}
