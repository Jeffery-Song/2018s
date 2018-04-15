all: main.byte

BUILD = corebuild
FLAGS = -use-ocamlfind -use-menhir

%.byte: always
	$(BUILD) $(FLAGS) src/$@

clean:
	mv solution.byte solution.b
	rm -rf *.byte *.top _build
	mv solution.b solution.byte

always:

.PHONY: always
