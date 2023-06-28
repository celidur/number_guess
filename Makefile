FILE = game.s


PROJECTNAME = a

CC = vasm6502_oldstyle
FLAGS = -Fbin -dotdir
BINTRG = $(PROJECTNAME).bin
all: $(BINTRG)
$(BINTRG): $(FILE)
	$(CC) $(FLAGS) -o $@ $<
clean:
	rm -f *.bin
install: $(BINTRG)
	minipro -p AT28C256 -w $(BINTRG)