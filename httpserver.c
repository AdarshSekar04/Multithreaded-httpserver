//httpserver.c
//Adarsh Sekar
//1619894
//adsekar@ucsc.edu

//This assignment implements an httpserver with multithreading and logging


#define _POSIX_C_SOURCE 200809L
#define _GNU_SOURCE
#include <sys/socket.h>
#include <sys/stat.h>
#include <stdio.h>
#include <netinet/in.h>
#include <netinet/ip.h>
#include <fcntl.h>
#include <unistd.h> // write
#include <string.h> // memset
#include <stdlib.h> // atoi
#include <stdbool.h> // true, false
#include <err.h>
#include <pthread.h>
//Libraries that I added below
#include <sys/types.h>
#include <errno.h>
#include <ctype.h>
#include "httpfunc.h" //library that I added


//This main function is going to read in the arguments the program was called with, and create an inputData object, that will be sent to our dispatcher().
int main(int argc, char** argv){
	if (argc < 2){
		perror("Too few arguments");
		return EXIT_FAILURE;
	}
	if (argc > 6){
		perror("Too many arguments");
		return EXIT_FAILURE;
	}
	//printf("argv = %s\n", (char *)argv);
	int numthreads = 4;
	char* logfile = NULL;
	int c = 0;
    bool checker = false;
    int port = 0;
    opterr = 0;
	//while((c = getopt(argc, argv, "N:l:")) != -1){
	for (int i = 0; i < argc; i++){
		c = getopt(argc, argv, "-:N:l:");
		//printf("Entered for\n");
		switch(c){
			case '\1':
                if(checker == false && atoi(optarg)){
                    port = atoi(optarg);
                    checker = true;
                    break;
                }
                perror("More than one port number or invalid argument\n");
				return EXIT_FAILURE;
			    break;
			case 'N':
				//printf("%s\n", optarg);
				if (atoi(optarg)){
					numthreads = atoi(optarg);
					break;
				}
				perror("Invalid number of threads\n");
				return EXIT_FAILURE;
				break;
			case 'l':
				if (optarg == NULL){
					perror("No log file provided\n");
					return EXIT_FAILURE;
				}
				logfile = optarg;
				break;
			case '?':
				printf("%s\n", argv[optind - 1]);
				/*if (optopt == 'N' || optopt == 'l'){
					perror("Option -N and -l require an argument\n");
					return EXIT_FAILURE;
				}*/
				perror("Invalid argument\n");
				return EXIT_FAILURE;
			case ':':
				if (optopt == 'N' || optopt == 'l'){
					perror("Option -N and -l require an argument\n");
					return EXIT_FAILURE;
				}
		}

	}
	//printf("Successfully got all arguments\n");
	printf("Port number = %d\nNum threads = %d\nlogfile = %s\n", port, numthreads, logfile);
	//Check if the port is valid
	if (port <= 1024){
		perror("Invalid port number\n");
		return EXIT_FAILURE;
	}
    if (numthreads < 1){
        perror("Invalid number of threads\n");
        return EXIT_FAILURE;
    }
	//printf("Now, entering dispatcher part\n");
    //Starter code given to initialize a client socket
    struct sockaddr_in server_addr;
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(port);
    server_addr.sin_addr.s_addr = htonl(INADDR_ANY);
    socklen_t addrlen = sizeof(server_addr);

    /*
        Create server socket
    */
    int server_sockd = socket(AF_INET, SOCK_STREAM, 0);

    // Need to check if server_sockd < 0, meaning an error
    if (server_sockd < 0) {
        perror("socket");
    }

    /*
        Configure server socket
    */
    int enable = 1;
    
    /*
        This allows you to avoid: 'Bind: Address Already in Use' error
    */
    int ret = setsockopt(server_sockd, SOL_SOCKET, SO_REUSEADDR, &enable, sizeof(enable));
    if (ret < 0){
        perror("setsockopt");
        //return EXIT_FAILURE;
        exit(EXIT_FAILURE);
    }

    /*
        Bind server address to socket that is open
    */
    ret = bind(server_sockd, (struct sockaddr *) &server_addr, addrlen);
    if (ret < 0){
        perror("bind");
        exit(EXIT_FAILURE);
    }

    /*
        Listen for incoming connections
    */
    //Listen marks our socket server_sockd as a passive socket, i.e, a socket that will be used to accept incoming information. It returns 0 on success and -1 on error. 
    ret = listen(server_sockd, SOMAXCONN); // 5 should be enough, if not use SOMAXCONN

    if (ret < 0) {
        perror("listen");
        exit(EXIT_FAILURE);
    }

    /*
        Connecting with a client
    */
    struct sockaddr client_addr;
    socklen_t client_addrlen = sizeof(client_addr);

    //From here, my code again
    //We create an array of worker threads
    workerThread workers[numthreads];
    int error = 0;
    //open the log file if it isn't NULL
    int logfd = -1;
    if (logfile != NULL){
    	printf("Log file present\n");
    	error = open(logfile, O_CREAT | O_RDWR | O_TRUNC, 0664);
    	if (error < 0){
    		perror("Error opening log file\n");
    		return EXIT_FAILURE;
    	}
    	logfd = error;
    }
    //Initializing various mutexes and condition variables
    pthread_cond_t free = PTHREAD_COND_INITIALIZER;
    pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
    pthread_mutex_t dlock = PTHREAD_MUTEX_INITIALIZER;
    pthread_mutex_t log_lock = PTHREAD_MUTEX_INITIALIZER;
    //pthread_mutex_t parse_lock = PTHREAD_MUTEX_INITIALIZER;
    //Set variable free_thread to -1
    int free_thread = -1;
    off_t offset = 0;
    uint64_t num_requests = 0;
    uint64_t num_error = 0;
    //Initialize the various values of each of the worker threads
    for (int i = 0; i < numthreads; i++){
        workers[i].cfd = -1;
        workers[i].logfd = logfd;
        workers[i].cond_var = (pthread_cond_t) PTHREAD_COND_INITIALIZER;
        workers[i].dissignal = &free;
        workers[i].id = i;
        workers[i].free = &free_thread;
        workers[i].lock = &lock;
        workers[i].dlock = &dlock;
        workers[i].loglock = &log_lock;
        //workers[i].parselock = &parse_lock;
        workers[i].log_offset = &offset;
        workers[i].num_requests = &num_requests;
        workers[i].num_errors = &num_error;
        //printf("ERROR HERE\n");
        error = pthread_create(&workers[i].worker_id, NULL, worker, (void *) &workers[i]);
        if (error){
            printf("Error with pthread_create() in dispatcher\n");
            exit(EXIT_FAILURE);
        }

        
    }
    printf("Errno before while = %d\n", errno);
    printf("Threads created\n");
    while (true){
		/*error = pthread_mutex_lock(&dlock);
		if (error){
		    perror("Error locking mutex\n");
		    exit(EXIT_FAILURE);
		}*/
    	printf("Waiting for client\n");
        int client_sockd = accept(server_sockd, &client_addr, &client_addrlen);
        //If there was an error accepting the client connection, we simply continue
        if (client_sockd < 0){
        	printf("Entered bad client_sockd. Errno = %d\n", errno);
            continue;
        }
        printf("Recieved client: %d\n", client_sockd);
        //While we don't have a free_thread, we make our dispatcher sleep on our condition variable free.
        error = pthread_mutex_lock(&dlock);
        if (error){
            perror("Error locking mutex\n");
            exit(EXIT_FAILURE);
        }
        while(free_thread < 0){
            pthread_cond_wait(&free, &dlock);
        }
        printf("Free_thread = %d\n", free_thread);
        /*error = pthread_mutex_unlock(&dlock);
        if (error){
            perror("Error unlocking mutex\n");
            exit(EXIT_FAILURE);
        }*/
        //Now that we have a free thread, we set the free threads cfd to client_sockd
        workers[free_thread].cfd = client_sockd;
        //Then we signal the free thread, so it can wake up and parse the request
        pthread_cond_signal(&workers[free_thread].cond_var);
        error = pthread_mutex_unlock(&dlock);
        if (error){
            perror("Error unlocking mutex\n");
            exit(EXIT_FAILURE);
        }
        
    }
	return EXIT_SUCCESS;
}
