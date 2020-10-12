#------------------------------------------------------------------------------
# Makefile for httpserver.c
#------------------------------------------------------------------------------
CFLAGS = -std=c99 -g -Wall -Wextra -Wpedantic -Wshadow -O2 -pthread
all : httpserver

httpserver : httpserver.o httpfunc.o
	gcc $(CFLAGS) -o httpserver httpserver.o httpfunc.o

httpserver.o : httpserver.c httpfunc.h
	gcc $(CFLAGS) -c httpserver.c 

httpfunc.o : httpfunc.c httpfunc.h
	gcc $(CFLAGS) -c httpfunc.c

clean :
	rm -f httpserver.o httpfunc.o

spotless : clean
	rm -f httpserver
