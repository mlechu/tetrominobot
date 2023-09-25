DEBUG := 0

CC := gcc
CCFLAGS := -I .
BFLAGS := --no-lines

ifeq ($(DEBUG), 1)
	CCFLAGS += -g -Wall -Wextra -Wpedantic
# CCFLAGS += -fno-pie -no-pie
# BFLAGS += -Wcounterexamples
else
	CCFLAGS += -O1
endif

OUTDIR := out
HDIR := $(OUTDIR)/handout

VM_IP := vm

all: $(OUTDIR)/tetrominobot |$(OUTDIR)

clean:
	rm -rf $(OUTDIR)

run: $(OUTDIR)/tetrominobot
	tr -d '\n' < simple.tbot | ./$(OUTDIR)/tetrominobot -n -d

.PHONY: all clean run tx_clean

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
# make tx to make handouts on the x86 vm, which spins up docker and runs make
# theoretically might be ok to to just make handouts on docker locally

tx: $(OUTDIR)/tx

tx_clean:
	rsync -rva --exclude $(OUTDIR) --exclude .git . $(VM_IP):tbot
	ssh -A $(VM_IP) "cd tbot && make clean"

$(OUTDIR)/tx: robot.c game.c tetrominobot.c |$(OUTDIR)
	rsync -rva --exclude $(OUTDIR) --exclude .git . $(VM_IP):tbot
	ssh -A $(VM_IP) "cd tbot && make handouts"
	scp -r $(VM_IP):~/tbot/$(OUTDIR)/* ./$(OUTDIR)/
# scp $(VM_IP):~/tbot/$(OUTDIR)/tetrominobot $(OUTDIR)/tx

D_IMG := tbot_img
D_CON := tbot_container
D_BUILD := /build

$(HDIR):
	mkdir -p $(HDIR)

handouts: robot.c game.c tetrominobot.c player-manual.org makefile $(OUTDIR)/docker_tbot_cont |$(HDIR)
	docker restart $(D_CON)
	docker cp . $(D_CON):$(D_BUILD)
	docker exec $(D_CON) /bin/bash -c 'cd $(D_BUILD) && make'
ifneq ($(DEBUG),1)
	docker exec $(D_CON) /bin/bash -c 'strip --strip-all $(D_BUILD)/$(OUTDIR)/tetrominobot'
endif
	docker cp $(D_CON):$(D_BUILD)/$(OUTDIR)/tetrominobot $(HDIR)
	docker cp $(D_CON):/lib/x86_64-linux-gnu/libc.so.6 $(HDIR)
	docker cp $(D_CON):/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 $(HDIR)
	docker stop $(D_CON)
	cp ./player-manual.org $(HDIR)
	cp ./simple.tbot $(HDIR)

$(OUTDIR)/docker_tbot_image: dockerfile |$(OUTDIR)
	touch $@
# clean
	docker stop $(D_CON) || true
	docker container rm --volumes $(D_CON) || true
	docker image rm $(D_IMG) || true
# build
	docker build . -t $(D_IMG) --platform=linux/amd64

$(OUTDIR)/docker_tbot_cont: $(OUTDIR)/docker_tbot_image |$(OUTDIR)
	touch $@
# clean
	docker stop $(D_CON) || true
	docker container rm --volumes $(D_CON) || true
# build
	docker run --platform=linux/amd64 -dit --name $(D_CON) $(D_IMG)

clean_docker:
	rm $(OUTDIR)/docker*
	docker stop $(D_CON) || true
	docker container rm --volumes $(D_CON) || true
	docker image rm $(D_IMG) || true
