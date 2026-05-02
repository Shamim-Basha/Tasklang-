CC = gcc
BISON = bison
FLEX = flex
CFLAGS = -L/mingw64/lib
EXE = tasklang.exe
INPUT = sample.txt

all: run

parser.tab.c parser.tab.h: parser.y
	$(BISON) -d parser.y

lex.yy.c: lexer.l parser.tab.h
	$(FLEX) lexer.l

$(EXE): parser.tab.c lex.yy.c
	$(CC) -o $(EXE) parser.tab.c lex.yy.c $(CFLAGS)

run: $(EXE)
	.\$(EXE) $(INPUT)

clean:
	del parser.tab.c parser.tab.h lex.yy.c $(EXE)

.PHONY: all run clean
