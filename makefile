CC := gcc

CCFLAGS := -I .
BFLAGS := --no-lines
# CCFLAGS := -g -I $(CURDIR) -Wall -Wextra -Wpedantic -fsanitize=address
# BFLAGS := -Wcounterexamples
OUTDIR := out

all: $(OUTDIR)/t |$(OUTDIR)

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

$(OUTDIR)/t: t.c $(OUTDIR)/game $(OUTDIR)/robot $(OUTDIR)/parse |$(OUTDIR)
	$(CC) $(CCFLAGS) $^ -o $@

# makefile crimes for my own debugging
$(OUTDIR)/tx: |$(OUTDIR)
	rsync -rva --exclude $(OUTDIR) . vm:tbot
	ssh -A vm "cd tbot && make"
	scp vm:~/tbot/out/t $(OUTDIR)/tx

clean:
	rm -rf $(OUTDIR)

.PHONY: all clean
