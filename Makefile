CC=clang
CFLAGS=-Wall -O2 -g

FRAMEWORKS=-framework Foundation -framework IOKit

TARGETS=sensors-m1

all: ${TARGETS}

sensors-m1: sensors-m1.o
	${CC} -o $@ $< ${FRAMEWORKS} ${LIBS}

clean:
	rm -rf ${TARGETS} *.o
