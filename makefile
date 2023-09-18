CC := gcc
CCFLAGS := -g -I $(CURDIR) # -Wall -Wextra -Wpedantic # -fsanitize=address
OUTDIR := $(CURDIR)/out

all: $(OUTDIR)/t |$(OUTDIR)

$(OUTDIR):
	mkdir -p $(OUTDIR)

$(OUTDIR)/parse.c: parse.y |$(OUTDIR)
	bison -d $< -Wcounterexamples -o $@

$(OUTDIR)/parse: $(OUTDIR)/parse.c |$(OUTDIR)
	$(CC) -c $(CCFLAGS) -o $@ $<

$(OUTDIR)/robot: robot.c $(OUTDIR)/parse |$(OUTDIR)
	$(CC) -c $(CCFLAGS) $< -o $@

$(OUTDIR)/game: game.c |$(OUTDIR)
	$(CC) -c $(CCFLAGS) $< -o $@

$(OUTDIR)/t: t.c $(OUTDIR)/game $(OUTDIR)/robot $(OUTDIR)/parse |$(OUTDIR)
	$(CC) $(CCFLAGS) $^ -o $@

clean:
	rm -rf $(OUTDIR)

.PHONY: all clean
