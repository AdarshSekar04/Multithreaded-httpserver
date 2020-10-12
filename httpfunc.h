#ifndef _HTTPFUNC_H_INCLUDE_
#define _HTTPFUNC_H_INCLUDE_

#define BUFFER_SIZE 4096



typedef struct httpObject {
    /*
        Create some object 'struct' to keep track of all
        the components related to a HTTP message
        NOTE: There may be more member variables you would want to add
    */
    char method[10];         // PUT, HEAD, GET
    char filename[BUFFER_SIZE];      // what is the file we are worried about
    char httpversion[9];    // HTTP/1.1
    ssize_t content_length; // example: 13
    int status_code;
    uint8_t buffer[BUFFER_SIZE];
}httpObject;

//Data type to store threads and information that they might need
typedef struct workerThread {
	httpObject message; //httpObject to store parsed message
	int id;	//Stores the index the worker thread is in in the workerThread array
	pthread_t worker_id; //The threads id
	int cfd; //the client file descriptor
	int logfd; //logfile descriptor, if we have one
	off_t* log_offset; //Pointer to an offset, where we store the byte offset for the log file, to indicate where to start writing
	int* free; //Is a pointer to a variable that is used to let the dispatcher know this thread is free.
    uint64_t* num_requests; //used for healthcheck to keep track of number of requests
    uint64_t* num_errors; //used for healthcheck, to keep track of number of errors
	pthread_cond_t cond_var;
	pthread_cond_t* dissignal;
	pthread_mutex_t* lock;
	pthread_mutex_t* dlock;
	pthread_mutex_t* loglock; //mutex lock for when accessing log file
	//pthread_mutex_t* parselock; //Lockss for parse request
}workerThread;

//This function will simply check if there was an error in a read, write, recv, or send. If there was, it will return true. Otherwise false
bool error_checker(int val, struct httpObject* message);

//This function simply checks if the entered filename is valid. It returns 1 if it is valid, and 0 if it isn't.
bool is_valid_filename(char* filename);


//Function to handle client input. Takes in the file descriptor of the client we are going to read from, and the file descriptor of a file we will write to, the bytes_left to write (content length) and a httpObject* message
void socketInput(int cfd, int fd, ssize_t bytes_left, struct httpObject* message);

//This function will print out the contents of a file to our client on a GET call
void print_to_client(int fd, int cfd, struct httpObject* message, off_t offset, int lfd);

/*
    \brief 1. Want to read in the HTTP message/ data coming in from socket
    \param client_sockd - socket file descriptor
    \param message - object we want to 'fill in' as we read in the HTTP message
*/
void read_http_response(ssize_t client_sockd, struct httpObject* message);

/*
    \brief 2. Want to process the message we just recieved. 
    Now we also take a log file descriptor, to check if logging is allowed
*/
void process_request(int client_fd, struct httpObject* message, int lfd);


/*
    \brief 3. Construct some response based on the HTTP request you recieved
*/
void construct_http_response(int cfd, struct httpObject* message, off_t offset, int lfd, uint64_t num_errors, uint64_t num_requests);


//Function where the worker threads parse the http request, and send a response
void* worker(void* thread);
//Function used to enter data into the log
//We want the logfile descriptor, an httpObject* message, the number of bytes read in, and a pointer to the offset. We also have a pointer to a variable that stores the number of bytes written in previous calls.
void logger(int logfd, httpObject* message, ssize_t bytes_read, off_t* offset, ssize_t* bytes_written);
//
void increment_offset(off_t* offset, httpObject* message, uint64_t num_errors, uint64_t num_requests);

#endif
