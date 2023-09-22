CC := gcc

CCFLAGS := -I .
BFLAGS := --no-lines
CCFLAGS := -g -I $(CURDIR) -Wall -Wextra -Wpedantic -fsanitize=address
# BFLAGS := -Wcounterexamples
OUTDIR := out

all: $(OUTDIR)/tetrominobot |$(OUTDIR)

$(OUTDIR):
	mkdir -p $(OUTDIR)

$(OUTDIR)/parse.c: parse.y |$(OUTDIR)
	bison -d $< $(BFLAGS) -o $@

$(OUTDIR)/parse: $(OUTDIR)/parse.c |$(OUTDIR)
	$(CC) -c $(CCFLAGS) $< -o $@

$(OUTDIR)/robot: robot.c $(OUTDIR)/parse |$(OUTDIR)
	$(CC) -c $(CCFLAGS) $< -o $@

$(OUTDIR)/game: game.c |$(OUTDIR)
	$(CC) -c $(CCFLAGS) $< -o $@

$(OUTDIR)/tetrominobot: tetrominobot.c $(OUTDIR)/game $(OUTDIR)/robot $(OUTDIR)/parse |$(OUTDIR)
	$(CC) $(CCFLAGS) $^ -o $@

# makefile crimes for my own debugging
$(OUTDIR)/tx: robot.c game.c tetrominobot.c |$(OUTDIR)
	rsync -rva --exclude $(OUTDIR) . vm:tbot
	ssh -A vm "cd tbot && make && make run"
	scp vm:~/tbot/out/tetrominobot $(OUTDIR)/tx

tx: $(OUTDIR)/tx

clean:
	rm -rf $(OUTDIR)

run: $(OUTDIR)/tetrominobot
	tr -d '\n' < simple.tbot | ./out/tetrominobot

.PHONY: all clean
