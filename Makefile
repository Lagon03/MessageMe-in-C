# Makefile
 
CC=gcc -fsanitize=address
CPPFLAGS= -MMD -D_XOPEN_SOURCE=500 -D_POSIX_C_SOURCE=200112L
CFLAGS= -Wall -Wextra -std=c99 -O0 -g
LDFLAGS=
LDLIBS=
 
SRC= server.c
OBJ= ${SRC:.c=.o}
DEP= ${SRC:.c=.d}
 
all: server
 
server: ${OBJ}
 
clean:
	${RM} ${OBJ}
	${RM} ${DEP}
	${RM} server
 
-include ${DEP}
 
# END
