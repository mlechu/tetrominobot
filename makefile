CC := gcc
CCFLAGS := -fsanitize=address -g
OUTDIR := $(CURDIR)/out

all: $(OUTDIR)/tbot $(OUTDIR)/t
	mkdir $(@D)

$(OUTDIR):
	mkdir -p $(@D)

$(OUTDIR)/tbot: $(OUTDIR)/tbot.tab.c |$(OUTDIR)
	$(CC) -lm -o $@ $<

$(OUTDIR)/tbot.tab.c: tbot.y |$(OUTDIR)
	bison $< -Wcounterexamples -o $@

$(OUTDIR)/t: t.c game.c |$(OUTDIR)
	$(CC) $(CCFLAGS) $^ -o $@

clean:
	rm -rf $(OUTDIR)

.PHONY: all clean
