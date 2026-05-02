# TaskLang++ Parser

A lexer and parser for TaskLang++, a domain-specific language for defining scheduled tasks with dependencies and conditions.

## Prerequisites

- **Bison** (parser generator)
- **Flex** (lexical analyzer generator)
- **GCC** (C compiler)

## Building

Run the Makefile to build the project:

```bash
make
```

or

```bash
mingw32-make
```


This will execute the following steps in order:
1. **Bison** generates the parser from `parser.y` → produces `parser.tab.c` and `parser.tab.h`
2. **Flex** generates the lexer from `lexer.l` → produces `lex.yy.c`
3. **GCC** compiles the parser and lexer → produces `tasklang.exe`
4. **Run** the executable on the sample input file

## Running

To parse a TaskLang++ file:

```bash
.\tasklang.exe sample.txt
```

Replace `sample.txt` with your own TaskLang++ input file.

## File Structure

- `parser.y` - Bison grammar definition
- `lexer.l` - Flex lexical rules
- `sample.txt` - Example TaskLang++ input file
- `Makefile` - Build automation
- `parser.tab.c`, `parser.tab.h` - Generated parser (auto-generated)
- `lex.yy.c` - Generated lexer (auto-generated)
- `tasklang.exe` - Compiled executable

## TaskLang++ Syntax

### Basic Task Definition

```
TASK taskName {
    RUN "script.py"
    EVERY DAY AT 06:00
}
```

### Multiple Task Definition

```
TASK dailyReport {
    RUN "report.py"
    EVERY DAY AT 06:00
}

TASK backupDB {
    RUN "backup.sh"
    EVERY DAY AT 23:08
}

TASK sendReport {
    RUN "report.py"
    AFTER backupDB
    IF SUCCESS
}

TASK cleanup {
    RUN "cleanup.sh"
    EVERY WEEK ON SUNDAY AT 03:00
}
```

### Schedule Options

- `AT HH:MM` - Run at specific time
- `EVERY DAY AT HH:MM` - Run daily at a time
- `EVERY WEEK ON MONDAY AT HH:MM` - Run weekly on a specific day

### Dependencies

- `AFTER taskName` - Run after another task
- `BEFORE taskName` - Run before another task

### Conditions

- `IF SUCCESS` - Only run if the previous task succeeded
- `IF FAILURE` - Only run if the previous task failed

## Example

See `sample.txt` for a complete example with multiple tasks, schedules, and dependencies.

## Cleaning

To remove generated files and rebuild:

```bash
make clean
```

or

```bash
mingw32-make clean
```
