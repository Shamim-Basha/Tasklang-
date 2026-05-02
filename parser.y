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
static int task_defined[MAX_TASKS];
static int task_count = 0;
static char *current_task = NULL;

static int find_task_index(const char *name);
static int get_task_index(const char *name);
static int set_task_index(const char *name);
static int is_valid_time(const char *value);
static int has_path(int from, int target, int *visited, int *parent);
static void print_cycle_path(int from_idx, int to_idx);
static int would_create_cycle(int from, int to);
static int add_dependency_edge(const char *from, const char *to);
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
            current_task = strdup($2);
            if (!current_task) {
                yyerror("Out of memory");
                free($2);
                YYABORT;
            }

            // Assign or confirm the task index for this definition
            if (set_task_index(current_task) < 0) {
                free(current_task);
                free($2);
                YYABORT;
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
                        if (!add_dependency_edge($2, current_task)) {
                            free($2);
                            YYABORT;
                        }

                        printf("  Depends on: %s\n", $2);
                        printf("  Runs after %s\n", $2);
                        free($2);
                    }
                    opt_conditional_command
                 | BEFORE identifier {
                        if (!add_dependency_edge(current_task, $2)) {
                            free($2);
                            YYABORT;
                        }

                        printf("  Depends on: %s\n", $2);
                        printf("  Runs before %s\n", $2);
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

time : TIME {
            if (!is_valid_time($1)) {
                yyerror("Invalid time format (expected HH:MM in 24-hour format)");
                free($1);
                YYABORT;
            }
            $$ = $1;
        }
        ;

%%

static int find_task_index(const char *name) {
    for (int i = 0; i < task_count; i++) {
        if (strcmp(task_names[i], name) == 0) {
            return i;
        }
    }

    return -1;
}

static int get_task_index(const char *name) {
    int i = find_task_index(name);
    if (i >= 0) {
        return i;
    }

    return set_task_index(name);
}

static int set_task_index(const char *name) {
    int i;

    i = find_task_index(name);
    if (i >= 0) {
        if (task_defined[i]) {
            yyerror("Duplicate task definition");
            return -1;
        }

        task_defined[i] = 1;
        return i;
    }

    if (task_count >= MAX_TASKS) {
        yyerror("Too many tasks in dependency graph");
        return -1;
    }

    task_names[task_count] = strdup(name);
    return task_count++;
}

static int is_valid_time(const char *value) {
    int hour, minute;
    
    if (sscanf(value, "%2d:%2d", &hour, &minute) != 2) return 0;

    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return 0;

    return 1;
}

static int has_path(int from, int target, int *visited, int *parent) {
    if (from == target) {
        return 1;
    }

    visited[from] = 1;

    for (int i = 0; i < task_count; i++) {
        if (dependency_graph[from][i] && !visited[i]) {
            if (parent) parent[i] = from;
            if (has_path(i, target, visited, parent)) {
                return 1;
            }
        }
    }

    return 0;
}

static void print_cycle_path(int from_idx, int to_idx) {
    int visited[MAX_TASKS] = {0};
    int parent[MAX_TASKS];
    int path[MAX_TASKS];
    int path_len = 0;
    int cur;

    for (int i = 0; i < MAX_TASKS; i++) {
        parent[i] = -1;
    }

    if (!has_path(to_idx, from_idx, visited, parent)) {
        fprintf(stderr, "%s -> %s\n", task_names[from_idx], task_names[to_idx]);
        return;
    }

    cur = from_idx;
    while (cur != -1 && path_len < MAX_TASKS) {
        path[path_len++] = cur;
        if (cur == to_idx) {
            break;
        }
        cur = parent[cur];
    }

    if (path_len == 0 || path[path_len - 1] != to_idx) {
        fprintf(stderr, "%s -> %s\n", task_names[from_idx], task_names[to_idx]);
        return;
    }

    fprintf(stderr, "%s", task_names[from_idx]);
    for (int i = path_len - 1; i >= 0; i--) {
        fprintf(stderr, " -> %s", task_names[path[i]]);
    }
    fprintf(stderr, "\n");
}

static int would_create_cycle(int from, int to) {
    int visited[MAX_TASKS] = {0};
    return has_path(to, from, visited, NULL);
}

static int add_dependency_edge(const char *from, const char *to) {
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
        fprintf(stderr, ">> %d : Cycle detected\n", yylineno);
        fprintf(stderr, ">> Cycle: ");
        print_cycle_path(from_idx, to_idx);
        fprintf(stderr, "\033[0m");
        fprintf(stderr, ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n");
        return 0;
    }

    dependency_graph[from_idx][to_idx] = 1;
    return 1;
}

static void cleanup_graph(void) {
    for (int i = 0; i < task_count; i++) {
        free(task_names[i]);
        task_names[i] = NULL;
        task_defined[i] = 0;
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
    if (s && *s) {
        fprintf(stderr, ">> %d : %s\n", yylineno, s);
    } else {
        fprintf(stderr, ">> %d : Syntax error\n", yylineno);
    }
    fprintf(stderr, "%s", reset);
    fprintf(stderr, ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n");
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
