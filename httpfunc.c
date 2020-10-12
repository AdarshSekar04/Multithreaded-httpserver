//httpfunc.c
//Adarsh Sekar
//This file is a library of the functions we will use to implement our multithreaded httpserver.c

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

//Libraries that I added below
#include <sys/types.h>
#include <errno.h>
#include <ctype.h>
#include <pthread.h>

//Header file
#include "httpfunc.h"

#define OK " 200 OK\r\n"
#define CREATED " 201 Created\r\n"
#define BAD_REQUEST " 400 Bad Request\r\n"
#define FORBIDDEN " 403 Forbidden\r\n"
#define FILE_NOT_FOUND " 404 Not Found\r\n"
#define INTERNAL_ERROR " 500 Internal Server Error\r\n"
//#define BUFFER_SIZE 4096
#define ERROR_OFFSET 24
#define SUCCESS_OFFSET 11
#define STDR_OFFSET 9
//int free;

//This function will simply check if there was an error in a read, write, recv, or send. If there was, it will return true. Otherwise false
bool error_checker(int val, struct httpObject* message){
    if (val < 0){
    //printf("Entered errno");
        if (errno == EACCES){
            message->status_code = 403;
            return true;
        }
        else if (errno == ENOENT){
        	message->status_code = 404;
        	return true;
        }
        message->status_code = 500;
        return true;
    }
    return false;
}
//This function simply checks if the entered filename is valid. It returns 1 if it is valid, and 0 if it isn't.
bool is_valid_filename(char* filename){
    //printf("%s\n", filename);
    //The first thing we will do is check the length of the filename. If it is longer than 27, we return 1.
    if (filename[0] != '/' || strlen(filename) == 1){
        return false;
    }
    char* tempname = filename;
    tempname++;
    if (strlen(tempname) > 27){
        return false;
    }
    //Otherwise, since the length of the string is valid, we must check that the filename is only made up of valid characters
    for(uint8_t i = 0; i < strlen(tempname); i++){
        if (isalpha(tempname[i]) || isdigit(tempname[i]) || tempname[i] == '-' || tempname[i] == '_'){
            continue;
        }
        //If a character in the string is none of our valid characters, return 1.
        return false;
    }
    return true;
}
//Function to handle client input. Takes in the file descriptor of the client we are going to read from, and the file descriptor of a file we will write to, the bytes_left to write (content length) and a httpObject* message
void socketInput(int cfd, int fd, ssize_t bytes_left, struct httpObject* message){
    //Initialise variables bytes_read, bytes_written, and error.
    ssize_t bytes_read = 0;
    ssize_t bytes_written = 0;
    bool error;
    //In this while loop, we keep reading in bytes until our bytes_left is 0. If we have an errors, we set the appropriate status code, and return.
    while(bytes_left != 0){
        bytes_read = recv(cfd, message->buffer, BUFFER_SIZE, 0);
        //write(1, message->buffer, bytes_read);
        error = error_checker(bytes_read, message);
        if (error == true){
        	//printf("Set in here1\n");
            return;
        }
        //If we are done inputting, simply break
        //If we just read in more bytes then there is space in the file, we write only the characters we can take and leave the rest
        if (bytes_read > bytes_left){
            ssize_t checker = write(fd, message->buffer, bytes_left);
            //If there is an error while writing, print to standard error, and exit the program
            error = error_checker(checker, message);
            if (error == true){
            	//printf("Set in here2\n");
                return;
            }
            break;
        }
        bytes_left -= bytes_read;
        bytes_written = write(fd, message->buffer, bytes_read);
        //printf("%s", message->buffer);
        //Check if there is an error using error_checker. If there is, return
        error = error_checker(bytes_written, message);
        if (error == true){
        	//printf("Set in here 3, checker = %li\n", checker);
            return;
        }
        if (bytes_written != bytes_read){
        	message->status_code = 500;
        	return;
        } 
    }
    //If there are still bytes left, set message->status_code to 400
    if (bytes_left > 0){
        message->status_code = 400;
        return;
    }
    //message->content_length = bytes_left;
    return;
}

//This function will print out the contents of a file to our client on a GET call
void print_to_client(int fd, int cfd, struct httpObject* message, off_t offset, int lfd){
    //printf("Entered print_to_client\n");
    //We want to first read from our file descriptor while we haven't reached the EOF
    //ssize_t total_bytes_read = 0
    ssize_t bytes_read = 0;
    off_t* temp_offset = &offset;
    ssize_t bytes_written = 0;
    while((bytes_read = read(fd, message->buffer, BUFFER_SIZE)) != 0){
    	//bytes_read = read(fd, message->buffer, BUFFER_SIZE);
        //If there was an error reading, set the status code to 500 (Internal Error) and return
        bool error = error_checker(bytes_read, message);
        if (error == true){
        	//printf("Error over here 1\n");
            return;
        }
        
        logger(lfd, message, bytes_read, temp_offset, &bytes_written);
        //total_bytes_read += bytes_read;
        //Otherwise we write the number of bytes to the client
        if (strcmp(message->method, "GET") == 0){
        	//printf("GET\n");
		    ssize_t checker = write(cfd, message->buffer, bytes_read);
		    if (bytes_read != checker){
	 			message->status_code = 500;
	 			return;
	 		}       
		    //If there was an error writing, set the status code to 500 (Internal Error) and return
		    error = error_checker(checker, message);
		    if (error == true){
		    	printf("Error over here 2\n");
		        return;
		    }
        }
        //message->content_length -= bytes_read;
    }
    ssize_t error = 0;
    if(bytes_written % 20 != 0){
    	sprintf((char*)&message->buffer, "\n");
    	error = pwrite(lfd, &message->buffer, 1, offset);
    	offset += error;
    }
    sprintf((char*)&message->buffer, "========\n");
    error = pwrite(lfd, &message->buffer, strlen((char*)&message->buffer), *temp_offset);
    if (error != (ssize_t)strlen((char*)&message->buffer)){
     message->status_code = 500;
    }
    //message->status_code = 200;
    return;
}
/*
    \brief 1. Want to read in the HTTP message/ data coming in from socket
    \param client_sockd - socket file descriptor
    \param message - object we want to 'fill in' as we read in the HTTP message
*/
void read_http_response(ssize_t client_sockd, struct httpObject* message) {
     //printf("Reading in http request\n");

    /*
     * Start constructing HTTP request based off data from socket
     */
    //char request[4096];
    //Read in the request into our buffer. We then check if there was an error reading in the request, anf if there was we return.
    ssize_t valid = recv(client_sockd, (char*)&message->buffer, BUFFER_SIZE, 0);
    bool error = error_checker(valid, message);
    if (error == true){
        return;
    }
    //printf("Request is;\n\n%s\n\n", (char*)&message->buffer);
    //Now we should have the clients request in our variable request
    //Now we must split request into the various segments
    char filename[BUFFER_SIZE]; 
    sscanf((char*)&message->buffer, "%s %s %s", message->method, filename, message->httpversion);
    //Here we check if the filename is okay by sending a call to is_valid_filename
    bool okay_name = is_valid_filename(filename);
    sscanf(filename, "%*c%s", message->filename);
    //If it is invalid, we set the status code to 400 and return
    if (okay_name == false){
    	//printf("Filename is: %s\n", filename);
        //printf("Entered here\n");
        message->status_code = 400;
        return;
    } 
    //sscanf(filename, "%*c%s", message->filename);
    //Here we check if the httpversion is okay or not
    if (strcmp(message->httpversion, "HTTP/1.1")){
    	message->status_code = 400;
    	return;
    }
    //printf("Method = %s", message->method);
    //If the message is a PUT, we get the content-length, and store it in message->content_length
    if ((strcmp("PUT", message->method)) == 0){
        char* conlen = strstr((char*)&message->buffer, "Content-Length:");
        if (conlen == NULL){
        	message->status_code = 400;
        	return;
        }
        sscanf(conlen, "Content-Length: %zd", &message->content_length);
        //printf("Message content length = %li\n", message->content_length);
    }
    char* newlines = strstr((char*)&message->buffer, "\r\n\r\n");
    //check for \r\n\r\n, if it isn't there, we set the status code to 400 and return.
    if(newlines == NULL){
    	message->status_code = 400;
    	return;
    }
    //Set the status code to 200, and return
    message->status_code = 200;
    return;
}

/*
    \brief 2. Want to process the message we just recieved
*/
void process_request(int client_fd, struct httpObject* message, int lfd) {
    //printf("Processing Request\n");
    //First we check if the status code = 400. If it is, we return
    if (message->status_code != 200){
        return;
    }
    //Here, we check if the the filename is healtcheck, as that is a special request
    if (strcmp(message->filename, "healthcheck") == 0){
    	//printf("Entered here\n");
        //If the method is not GET, or the logfile is not valid, set the status code to 400, and return.
        if (strcmp(message->method, "GET")){
            message->status_code = 403;
            return;
        }
        if (lfd == -1){
            message->status_code = 404;
            return;
        }
        //Otherwise, we just return
        return;
    }
    //First, we will initialise some variables to make the it easier to store the information we want about the message
    //If the method is PUT
    if (strcmp(message->method, "PUT") == 0){
    	//printf("Entered if in processing request\n");
        //We want to open a file with with the name stored in filename. If the file doesn't already exist, we will create it with the O_CREAT flag.
        int fd = open(message->filename, O_WRONLY | O_TRUNC, 0664);
        bool error = error_checker(fd, message);
        if (error == true){
        	//printf("Got here");
            if (message->status_code == 404){
                fd = open(message->filename, O_CREAT | O_WRONLY | O_TRUNC, 0664);
                error = error_checker(fd, message);
                if (error == true){
                    return;
                }
                message->status_code = 201;
            }
            else if (message->status_code != 404){
            	return;
            }
        }
        //printf("Got past if in pr\n");
        //Now that we have created the file, we want to read the number of bytes stored in content_length from the client
        if(message->content_length == 0){
        	return;
        }
        ssize_t content_length = message->content_length;
        //Now we simply call the function socketInput, and enter the correct number of bytes into the file corresponding to by fd. fileInput will return a status code.
        socketInput(client_fd, fd, content_length, message);
        //Then we close the file
        int cls = close(fd);
        error = error_checker(cls, message);
        if (error == true){
        	return;
        }
    }
    //If the method is a GET or a HEAD
    else if (strcmp(message->method, "GET") == 0 || strcmp(message->method, "HEAD") == 0){
        //We want to look for the file the client is asking us to GET. If there is no file, or an error while opening the file, we return.
        int fd = open(message->filename, O_RDONLY);
        bool error = error_checker(fd, message);
        if (error == true){
        	return;
        }
        //If there is such a file, we want to find the content length of it, i.e, the number of bytes written into the file.
        //We move the file offset to the end, and store the returned number of bytes.
        off_t clen = lseek(fd, 0, SEEK_END);
        message->content_length = clen;
        //Here, we reset the file offset to the start
        clen = lseek(fd, 0, SEEK_SET);
        if (clen != 0){
            message->status_code = 500;
            return;
        }
        //Then we close the file
        int cls = close(fd);
        //Check if there were any errors while closing the file. If there was an error, that's an internal servor error, so we return.
        error = error_checker(cls, message);
        if (error == true){
        	return;
        }
    }
    //In case any other request is made
    else{
        message->status_code = 400;
    }
    return;
}

/*
    \brief 3. Construct some response based on the HTTP request you recieved
*/
void construct_http_response(int cfd, struct httpObject* message, off_t offset, int lfd, uint64_t num_errors, uint64_t num_requests) {
    //printf("Constructing Response\n");
    int error = 0;
    //char clen[17] = "Content-Length: ";
    if (message->status_code == 200){
        //First we check if the filename is healthcheck
        if (strcmp(message->filename, "healthcheck") == 0){
            //If it is, we return the appropriate response
            dprintf(cfd, "%s%sContent-Length: %li\r\n\r\n", message->httpversion, OK, message->content_length);
            sprintf((char*)&message->buffer, "%s /%s length %li\n", message->method, message->filename, message->content_length);
            error = pwrite(lfd, &message->buffer, strlen((char*)&message->buffer), offset);
            offset += error;
            //sprintf((char*)&message->buffer, "%ld\n%ld\n", num_errors, num_requests);
            dprintf(cfd, "%ld\n%ld", num_errors, num_requests);
            //pwrite(lfd, &message->buffer, strlen((char*)&message->buffer), offset);
            //offset += strlen((char*)&message->buffer);
            sprintf((char*)&message->buffer, "========\n");
            error = pwrite(lfd, &message->buffer, strlen((char*)&message->buffer), offset);
            return;

        }
        //printf("200\n");
        //If the method is PUT or HEAD, we output the same thing. The httpversion, status code, and the Content-Length
        if (strcmp(message->method, "HEAD") == 0){
            dprintf(cfd, "%s%sContent-Length: %li\r\n\r\n", message->httpversion, OK, message->content_length);
            //If there is no log, we just return
            if (lfd == -1){
            	return;
            }
            //Need to write to log here
            sprintf((char*)&message->buffer, "%s /%s length %li\n", message->method, message->filename, message->content_length);
            error = pwrite(lfd, &message->buffer, strlen((char*)&message->buffer), offset);
            offset += error;
            sprintf((char*)&message->buffer, "========\n");
            error = pwrite(lfd, &message->buffer, strlen((char*)&message->buffer), offset);
        }
        //Else if the method is PUT or GET, we output the same thing as HEAD, but also the contents of the file for GET, and the contents of the file to the logfile for both
        else if (strcmp(message->method, "PUT") == 0 || strcmp(message->method, "GET") == 0){
            if (strcmp(message->method, "PUT") == 0){
                dprintf(cfd, "%s%sContent-Length: %d\r\n\r\n", message->httpversion, OK, 0);
                if (lfd == -1){
                	return;
                }
            }
            else{
                dprintf(cfd, "%s%sContent-Length: %li\r\n\r\n", message->httpversion, OK, message->content_length);
            }
            //Here, we open the file and print the contents using the print_to_client function
            int fd = open(message->filename, O_RDONLY);
            if (fd < 0){
            	 printf("Problem opening file");
                return;
            }
            if (lfd >= 0){
            	//Need to write to log here
            	sprintf((char*)&message->buffer, "%s /%s length %li\n", message->method, message->filename, message->content_length);
            	error = pwrite(lfd, &message->buffer, strlen((char*)&message->buffer), offset);
            	offset += error;
            }
            print_to_client(fd, cfd, message, offset, lfd);
            close(fd);
            //sprintf((char*)&message->buffer, "========\n");
            //pwrite(lfd, &message->buffer, strlen((char*)&message->buffer), offset);
            //And we are done
        }
    }
    //If the message was 201, it can only be a PUT that occured
    else if (message->status_code == 201){
    	//printf("Entered 201 if\n");
        dprintf(cfd, "%s%sContent-Length: %d\r\n\r\n", message->httpversion, CREATED, 0);
        //If there is no log, we just return
        if (lfd == -1){
        	return;
        }
    //Need to print to the logile, so we read from the file we just PUT, and print out the contents in hex to the logfile
    //Need to write to log here
        sprintf((char*)&message->buffer, "%s /%s length %li\n", message->method, message->filename, message->content_length);
        error = pwrite(lfd, &message->buffer, strlen((char*)&message->buffer), offset);
        offset += error;
        int fd = open(message->filename, O_RDONLY);
        if (fd < 0){
        	perror("Problem opening file");
            return;
        }
        print_to_client(fd, cfd, message, offset, lfd);
        close(fd);
        //sprintf((char*)&message->buffer, "========\n");
        //pwrite(lfd, &message->buffer, strlen((char*)&message->buffer), offset);
    
    }
    //Following are else ifs for the different error status codes. All are the same, with just different messages outputted.
    else if (message->status_code == 400){
        dprintf(cfd, "HTTP/1.1%sContent-Length: %d\r\n\r\n", BAD_REQUEST, 0);
        //If there is no log, we just return
        if (lfd == -1){
        	return;
        }
        //Need to write to log here
        sprintf((char*)&message->buffer, "FAIL: %s /%s %s --- response %d\n", message->method, message->filename, message->httpversion, message->status_code);
        error = pwrite(lfd, &message->buffer, strlen((char*)&message->buffer), offset);
        offset += error;
        sprintf((char*)&message->buffer, "========\n");
        error = pwrite(lfd, &message->buffer, strlen((char*)&message->buffer), offset);
    } 
    else if (message->status_code == 403){
       	dprintf(cfd, "%s%sContent-Length: %d\r\n\r\n", message->httpversion, FORBIDDEN, 0);
       	//If there is no log, we just return
        if (lfd == -1){
        	return;
        }
       	//Need to write to log here
        sprintf((char*)&message->buffer, "FAIL: %s /%s %s --- response %d\n", message->method, message->filename, message->httpversion, message->status_code);
        error = pwrite(lfd, &message->buffer, strlen((char*)&message->buffer), offset);
        offset += error;
        sprintf((char*)&message->buffer, "========\n");
        error = pwrite(lfd, &message->buffer, strlen((char*)&message->buffer), offset);
    }
    else if (message->status_code == 404){
    	//printf("Entered 404\n");
        dprintf(cfd, "%s%sContent-Length: %d\r\n\r\n", message->httpversion, FILE_NOT_FOUND, 0);
        //If there is no log, we just return
        if (lfd == -1){
        	return;
        }
        //Need to write to log here
        sprintf((char*)&message->buffer, "FAIL: %s /%s %s --- response %d\n", message->method, message->filename, message->httpversion, message->status_code);
        error = pwrite(lfd, &message->buffer, strlen((char*)&message->buffer), offset);
        offset += error;
        sprintf((char*)&message->buffer, "========\n");
        error = pwrite(lfd, &message->buffer, strlen((char*)&message->buffer), offset);
    }
    else if (message->status_code == 500){
        dprintf(cfd, "%s%sContent-Length: %d\r\n\r\n", message->httpversion, INTERNAL_ERROR, 0);
        //If there is no log, we just return
        if (lfd == -1){
        	return;
        }
        //Need to write to log here
        sprintf((char*)&message->buffer, "FAIL: %s /%s %s --- response %d\n", message->method, message->filename, message->httpversion, message->status_code);
        error = pwrite(lfd, &message->buffer, strlen((char*)&message->buffer), offset);
        offset += error;
        sprintf((char*)&message->buffer, "========\n");
        error = pwrite(lfd, &message->buffer, strlen((char*)&message->buffer), offset);
    }
    else{
        printf("Didn't set message->status_code");
    }
    //all possible cases have been taken care of.
}

//Here on out, we have the new functions for the asgn2


void* worker(void* thread){
    workerThread* this_thread = (workerThread *) thread;
    while (true){
    	//printf("Worker thread %d is ready for instruction\n", this_thread->id);
        //Have to lock the mutex before waiting
        int error = pthread_mutex_lock(this_thread->lock);
        if (error){
        	perror("Error with pthread_mutex_lock");
            //exit(EXIT_FAILURE);
            continue;
        }
        //printf("Thread %d has entered critical region\n", this_thread->id);
        *this_thread->free = this_thread->id;
        error = pthread_cond_signal(this_thread->dissignal);
        if (error){
        	perror("Error with pthread_cond_signal");
            exit(EXIT_FAILURE);
        }
        //Now we lock dispatcher mutex
        while(this_thread->cfd < 0){
        	//printf("Thread %d waiting to be woken up\n", this_thread->id);
            //wait on our condition variable
            error = pthread_cond_wait(&this_thread->cond_var, this_thread->dlock);
            if (error){
            	perror("Problem with pthread_cond_wait\n");
            	exit(EXIT_FAILURE);
            }
        }
        *this_thread->free = -1;
        //Unlock the mutex as we've exited out critical section
        //printf("Thread %d connected to socket %d\n", this_thread->id, this_thread->cfd);
        error = pthread_mutex_unlock(this_thread->lock);
        if(error){
            perror("Error with pthread_mutex_unlock\n");
            exit(EXIT_FAILURE);
        }
		
        //Do some stuff over here
        /*
         * 2. Read HTTP Message
         */
        //printf("About to read http response\n");
        read_http_response(this_thread->cfd, &this_thread->message);

        /*
         * 3. Process Request
         */
        //Processing the request
        //printf("Thread %d about to process request\n", this_thread->id);
        process_request(this_thread->cfd, &this_thread->message, this_thread->logfd);
        /*
         * 4. Construct Response
         */
         //Now that we are going to construct the http response, we will collect the logfile offset and store it in a local variable
         //We only do this if we have a logfile
        off_t offset = 0;
        uint64_t num_errors = -1;
        uint64_t num_requests = -1;
        if(this_thread->logfd != -1){
		    error = pthread_mutex_lock(this_thread->loglock);
		    if(error){
		        perror("Error with pthread_mutex_unlock");
		        //exit(EXIT_FAILURE);
		        this_thread->message.status_code = 500;
		    }
		    //store the offset in a local variable offset
		    offset = *this_thread->log_offset;
            num_errors = *this_thread->num_errors;
            num_requests = *this_thread->num_requests;
		    printf("Offset = %li\n", offset);
		    //Now we call increment_offset on the actual offset
		    increment_offset(this_thread->log_offset, &this_thread->message, num_errors, num_requests);
            *this_thread->num_requests += 1;
            if (this_thread->message.status_code > 201){
                *this_thread->num_errors += 1;
            }
		    //Now, we can unlock our loglock mutex
		    error = pthread_mutex_unlock(this_thread->loglock);
		    if(error){
		        perror("Error with pthread_mutex_unlock");
		        exit(EXIT_FAILURE);
		    }
        }
        printf("Thread %d constructing response now\n", this_thread->id);
        //Now, we can call construct_http_response with our offset
        construct_http_response(this_thread->cfd, &this_thread->message, offset, this_thread->logfd, num_errors, num_requests);

        /*
         * 5. Send Response
         */
        printf("Response Sent\n");
        
        //sleep(10);

        //Here, we reset our cfd to and send a signal to our dispatcher
        this_thread->cfd = -1;
        //error = pthread_cond_signal(this_thread->dissignal);
    }
}

void increment_offset(off_t* offset, httpObject* message, uint64_t num_errors, uint64_t num_requests){
	//Now we want to increment the offset depending on the number of bytes we think we'll write
	//We want to check whether it was a success or not
	if(message->status_code == 200 || message->status_code == 201){
		//Add the offset for if it is a successful HEAD call
		int temp = strlen((char*)&message->method);
		//printf("temp = %d\n", temp);
		temp += strlen((char*)&message->filename);
		//printf("temp = %d\n", temp);
        //Special if for healthcheck. If we enter the if, we return at the end
        if (strcmp(message->filename, "healthcheck") == 0){
            sprintf((char*)&message->buffer, "%ld", num_errors);
            //temp += strlen((char*)&message->buffer);
            message->content_length = strlen((char*)&message->buffer);
            sprintf((char*)&message->buffer, "%ld", num_requests);
            //temp += strlen((char*)&message->buffer);
            message->content_length += strlen((char*)&message->buffer);
            //Add newline to content_length
            message->content_length += 1;
            //Add another one for newline
            //temp += 1;
            //Now add the amount of space the content_length itself will take
            sprintf((char*)&message->buffer, "%ld", message->content_length);
            temp += strlen((char*)&message->buffer);
            //Now, we add standard offsets for successful healthcheck call
            //Then, we finally add the standard offsets for a successful call
            temp += STDR_OFFSET;
            temp += SUCCESS_OFFSET;
            //printf("temp = %d\n", temp);
            *offset += temp;
            return;
        }
		//temp += sizeof(message->content_length);
		sprintf((char*)&message->buffer, "%ld", message->content_length);
		temp += strlen((char*)&message->buffer);
		//printf("temp = %d\n", temp);
		//If it is a PUT or GET, we must add the content_length, plus bytes for the newlines, and byte count ending and starting each sentence
		if (strcmp(message->method, "PUT") == 0 || strcmp(message->method, "GET") == 0){
			temp += message->content_length * 3;
			//printf("temp = %d\n", temp);
			temp += (message->content_length / 20) * 9;
			//printf("temp = %d\n", temp);
			//If there will be an extra line since the modulo of the content_length is not 0, we need to add another 2 bytes to the offset.
			if ((message->content_length % 20) != 0){
				temp += 9;
				//printf("temp = %d\n", temp);
			}	
		}
		//Then, we finally add the standard offsets for a successful call
		temp += STDR_OFFSET;
		temp += SUCCESS_OFFSET;
		//printf("temp = %d\n", temp);
		*offset += temp;
	}
	//Else, there was some error , so we instead add the offset for an error
	else{
		//We do the same thing as earlier, but we don't care for content of PUT or GET
		//We also add bytes for http version and status code instead of content length
		int temp = strlen((char*)&message->method);
		temp += strlen((char*)&message->filename);
		temp += strlen((char*)&message->httpversion);
		//temp += sizeof(message->content_length);
		sprintf((char*)&message->buffer, "%d", message->status_code);
		temp += strlen((char*)&message->buffer);
		//Now we add the standard bytes for a failed http call
		temp += ERROR_OFFSET;
		temp += STDR_OFFSET;
		*offset += temp;
	}
}


void logger(int logfd, httpObject* message, ssize_t bytes_read, off_t* offset, ssize_t* bytes_written){
	//printf("Entered logger2\nString is %s\n\n", (char*)&message->buffer);
	//First thing we want to do is create a buffer
    uint8_t hex_buffer[BUFFER_SIZE];
	ssize_t i = 0;
	ssize_t j = 0;
	//printf("Bytes read = %li\n", bytes_read);
	//First, we want to check if we read a mutltiple of 20 bytes. If we haven't, we need to finish off the line
	while((*bytes_written % 20) != 0 && (*bytes_written != 0)){
		//printf("Entered this while\n");
		sprintf((char*)hex_buffer + j, " %02x", message->buffer[i]);
		*bytes_written += 1;
		j += 3;
		i += 1;
		//If the bytes_written mod 20 is now 0, we print to the file, and add a newline
		if ((*bytes_written % 20) == 0){
			sprintf((char*)hex_buffer + j, "\n");
			j++;
			//printf("hexbuffer  = %s\n", (char*)&hex_buffer);
			int error = pwrite(logfd, hex_buffer, j, (*offset));
            //Nothing we can do if there was an error writing
            if (error != j){
            	//message->status_code = 500;
                return;
            }
            //Add bytes written to offset
            *offset += j;
            j = 0;
            //sprintf(hex_buffer + j, "%08d",(int) *bytes_written);
            //error = pwrite(logfd, hex_buffer, 8, (*offset));
            //Nothing we can do if there was an error writing
            /*if (error != 8){
            	//message->status_code = 500;
                return;
            }
            *offset += 8;*/
            //memset();
		}
	}
	//Reset j
    j = 0;
    //Create var arr_off and set it to i
    ssize_t arr_off = i;
    sprintf((char*)hex_buffer + j, "%08d", (int)*bytes_written);
    int error = pwrite(logfd, hex_buffer, 8, (*offset));
    //Nothing we can do if there was an error writing
    if (error < 0){
    	//message->status_code = 500;
        return;
    }
    *offset += 8;
    //printf("%s\n", hex_buffer);
    //Now, we want to enter a while loop while we are less than the number of bytes_read
    for (i = i; i < bytes_read; i++){
        //If we have read 20 bytes, then we print them to our logfile
        if ((i+1-arr_off) % 20 == 0 && i != 0){
        	//printf("If statement, i = %li\n", i);
            //We want to print out the hex character followed by a newline, and then the count of bytes printed (i) on the newline
            sprintf((char*)hex_buffer + j, " %02x\n", message->buffer[i]);
            //*bytes_written += 20;
            //printf("%s", hex_buffer);
            //Increment j by 4 bytes, as we just printed 4 bytes
            j += 4;
            //printf("j = %li\n", j);
            //printf("logfd = %d\n", logfd);
            //printf("offset = %li\n", *offset);
            error = pwrite(logfd, hex_buffer, j, (*offset));
            //Nothing we can do if there was an error writing
            if (error < 0){
            	perror("Error\n");
            	//message->status_code = 500;
            	//printf("Error here\nErrno = %d", errno);
                return;
            }
            //Now that we've written the bytes, we increment our offset by j
            *offset += j;
            *bytes_written += 20;
            if(i < (bytes_read - 1)){
			    sprintf((char*)hex_buffer, "%08d", (int)*bytes_written);
			    error = pwrite(logfd, hex_buffer, 8, (*offset));
				//Nothing we can do if there was an error writing
				if (error < 0){
					perror("Error\n");
					//message->status_code = 500;
					return;
				}
				*offset+= 8;
			}
            //reset j, and loop again
            j = 0;
            continue;
        }
        //Otherwise, we read the data into our hex_buffer
        sprintf((char*)&hex_buffer + j, " %02x", message->buffer[i]);
        //And we increment j by 3
        j += 3;
    }
    //At the end of the for loop, we want to write whatever is in the buffer to the log
    if (j != 0){
		error = pwrite(logfd, hex_buffer, j, (*offset));
		if (error != j){
			//message->status_code = 500;
		}
		//printf("%s\n", hex_buffer);
		*bytes_written += j/3;
		*offset += j;
	}	
    
}
