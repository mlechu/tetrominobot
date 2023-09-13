CC := gcc
CCFLAGS := -g -I $(CURDIR) # -fsanitize=address
OUTDIR := $(CURDIR)/out

all: $(OUTDIR)/t |$(OUTDIR)

$(OUTDIR):
	mkdir -p $(OUTDIR)

$(OUTDIR)/tbot.tab.c: tbot.y |$(OUTDIR)
	bison -d $< -Wcounterexamples -o $@

$(OUTDIR)/parse: $(OUTDIR)/tbot.tab.c |$(OUTDIR)
	$(CC) -c $(CCFLAGS) -lm -o $@ $<

$(OUTDIR)/t: t.c game.c $(OUTDIR)/parse |$(OUTDIR)
	$(CC) $(CCFLAGS) $^ -o $@

clean:
	rm -rf $(OUTDIR)

.PHONY: all clean
