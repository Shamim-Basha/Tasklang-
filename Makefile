CC = gcc
BISON = bison
FLEX = flex
CFLAGS = -L/mingw64/lib
EXE = tasklang.exe
INPUT = sample.txt

# Default target
all: run

# Parser generation
parser.tab.c parser.tab.h: parser.y
	$(BISON) -d parser.y

# Lexer generation (depends on parser headers)
lex.yy.c: lexer.l parser.tab.h
	$(FLEX) lexer.l

# Compilation (depends on generated sources)
$(EXE): parser.tab.c lex.yy.c
	$(CC) -o $(EXE) parser.tab.c lex.yy.c $(CFLAGS)

# Run (depends on executable)
run: $(EXE)
	.\$(EXE) $(INPUT)

# Clean up generated files
clean:
	del parser.tab.c parser.tab.h lex.yy.c $(EXE)

.PHONY: all run clean
