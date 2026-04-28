%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int yylex();
void yyerror(const char *s);
extern FILE *yyin;
extern int yylineno;

#define MAX_TASKS 128

static char *task_names[MAX_TASKS];
static int dependency_graph[MAX_TASKS][MAX_TASKS];
static int task_count = 0;
static char *current_task = NULL;

static int find_task_index(const char *name);
static int get_task_index(const char *name);
static int has_path(int from, int target, int *visited);
static int would_create_cycle(int from, int to);
static int add_dependency_edge(const char *from, const char *to, const char *relation);
static void cleanup_graph(void);

%}

%union {
    char *str;
}

%token TASK RUN EVERY DAY WEEK ON AT AFTER BEFORE IF
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
            // Check for duplicate task definition
            if (find_task_index($2) >= 0) {
                yyerror("Duplicate task definition");
                free($2);
            }

            current_task = strdup($2);
            if (!current_task) {
                yyerror("Out of memory");
            }

            printf("Executing Task: %s\n", $2);
            free($2); 
        }
       LCURL run_command command RCURL{
           printf("\n");
           if (current_task) {
               free(current_task);
               current_task = NULL;
           }
       }
    ;

command : schedule_command
        | dependency_command 
    ;

run_command : RUN filename {
                printf("  Script: %s\n", $2);
                free($2);
            }
        ;

schedule_command : AT time {
                        printf("  Schedule: AT %s\n", $2);
                    free($2);
                   }
                 | EVERY DAY AT time {
                        printf("  Schedule: EVERY DAY AT %s\n", $4);
                    free($4);
                   }
                 | EVERY WEEK ON day_of_week AT time {
                        printf("  Schedule: EVERY WEEK ON %s AT %s\n", $4, $6);
                    free($4);
                    free($6);
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

dependency_command : AFTER identifier {
                        if (!current_task) {
                            yyerror("Dependency declared outside of a task");
                            free($2);
                            YYABORT;
                        }

                        if (!add_dependency_edge(current_task, $2, "AFTER")) {
                            free($2);
                            YYABORT;
                        }

                        printf("  Depends on: %s\n", $2);
                        free($2);
                    }
                    opt_conditional_command
                 | BEFORE identifier {
                        if (!current_task) {
                            yyerror("Dependency declared outside of a task");
                            free($2);
                            YYABORT;
                        }

                        if (!add_dependency_edge($2, current_task, "BEFORE")) {
                            free($2);
                            YYABORT;
                        }

                        printf("  Depends on: %s\n", $2);
                        free($2);
                    }
        ;

opt_conditional_command : conditional_command
                            | /* empty */ 
        ;

conditional_command : IF condition {
                        printf("  Condition: %s\n", $2);
                        free($2);
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

static int find_task_index(const char *name) {
    int i;

    for (i = 0; i < task_count; i++) {
        if (strcmp(task_names[i], name) == 0) {
            return i;
        }
    }

    return -1;
}

static int get_task_index(const char *name) {
    int i;

    i = find_task_index(name);
    if (i >= 0) {
        return i;
    }

    return set_task_index(name);
}

static int set_task_index(const char *name) {
    if (task_count >= MAX_TASKS) {
        yyerror("Too many tasks in dependency graph");
        return -1;
    }

    task_names[task_count] = strdup(name);

    if (!task_names[task_count]) {
        yyerror("Out of memory");
        return -1;
    }

    return task_count++;
}

static int has_path(int from, int target, int *visited) {
    int i;

    if (from == target) {
        return 1;
    }

    visited[from] = 1;

    for (i = 0; i < task_count; i++) {
        if (dependency_graph[from][i] && !visited[i]) {
            if (has_path(i, target, visited)) {
                return 1;
            }
        }
    }

    return 0;
}

static int would_create_cycle(int from, int to) {
    int visited[MAX_TASKS] = {0};
    return has_path(to, from, visited);
}

static int add_dependency_edge(const char *from, const char *to, const char *relation) {
    int from_idx = get_task_index(from);
    int to_idx = get_task_index(to);

    if (from_idx < 0 || to_idx < 0) {
        return 0;
    }

    if (dependency_graph[from_idx][to_idx]) {
        return 1;
    }

    if (would_create_cycle(from_idx, to_idx)) {
        fprintf(stderr, "\n>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n");
        fprintf(stderr, "\033[31m");
        fprintf(
            stderr,
            ">> %d : Cycle detected after %s dependency (%s -> %s)\n",
            yylineno,
            relation,
            from,
            to
        );
        fprintf(stderr, "\033[0m");
        fprintf(stderr, ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n");
        return 0;
    }

    dependency_graph[from_idx][to_idx] = 1;
    return 1;
}

static void cleanup_graph(void) {
    int i;

    for (i = 0; i < task_count; i++) {
        free(task_names[i]);
        task_names[i] = NULL;
    }

    task_count = 0;

    if (current_task) {
        free(current_task);
        current_task = NULL;
    }
}

void yyerror(const char *s) {
    const char *red = "\033[31m";
    const char *reset = "\033[0m";

    fprintf(stderr, "\n>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n");
    fprintf(stderr, "%s", red);
    if (strstr(s, "unexpected") != NULL) {
        fprintf(stderr, ">> %d : Unexpected token at line %d\n", yylineno, yylineno);
    }else if (strstr(s, "expecting") != NULL) {
        fprintf(stderr, ">> %d : Missing or misplaced token at line %d\n", yylineno, yylineno);
    }else {
        fprintf(stderr, ">> %d : Syntax error: %s at line %d\n", yylineno, s, yylineno);
    }
    fprintf(stderr, "%s", reset);
    fprintf(stderr, ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n");
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

    cleanup_graph();

    return rc;
}
int yywrap(){
    return 1;
}
