# include <unistd.h>
# include <err.h>
# include <errno.h>
# include <stdlib.h>
# include <sys/types.h>
# include <sys/socket.h>
# include <string.h>
# include <netdb.h>
# include <signal.h>

//# define _POSIX_SOURCE
//# define _X_OPEN_SOURCE

void echo(int fdin, int fdout)
{   
    int r;
    char buf[1024];

    while ( (r = read (fdin, buf, 1024)) != 0)
    {
        if (r == -1)
        {
             if (errno == EINTR || errno == EAGAIN)
                 continue;
             else
                err(EXIT_FAILURE, "error while reading");  
        }
        
        r = write(fdout, buf, r);
        if (r == -1)
        {
            if (errno == EINTR || errno == EAGAIN)
                continue;
            else
                err(EXIT_FAILURE, "error while writing");
        }
    }
}

int fdaccept_register(int fd) {
    static int fdaccept = -1;
    if (fdaccept == -1 && fd != -1) {
        fdaccept = fd;
    }
    return fdaccept;
}
 
// signal handler for SIGINT
void sigint_handler(int sig) {
    (void)sig;
    int fd = fdaccept_register(-1);
    if (fd != -1)
        close(fd);
    _exit(0);
}

void server(const char *portname)
{   
    int errm = 0; //error register
    int info_err = 0;
    struct addrinfo hints, *resinfo = NULL;
 
    // setup hints and get local info
    memset(&hints, 0, sizeof (struct addrinfo));
    hints.ai_family = AF_UNSPEC;                 // IPv4 or IPv6
    hints.ai_socktype = SOCK_STREAM;             // TCP
    hints.ai_protocol = 0;
    hints.ai_flags = AI_PASSIVE | AI_ADDRCONFIG; // server mode
    // let's go !
    info_err = getaddrinfo(NULL, portname, &hints, &resinfo);
 
        // Error management
    if (info_err != 0) {
        errx(EXIT_FAILURE, "Server setup fails on port %s: %s", portname,
         gai_strerror(info_err));
    }
    //create socket
    
    int server_fd = socket(resinfo->ai_family, resinfo->ai_socktype,
                           resinfo->ai_protocol);
    if(server_fd == -1)
        err(EXIT_FAILURE, "Fail to create socket");
    
    //set option SOL_REUSEADDR
    int reuse_err;
    int reuse = 1;
    reuse_err = setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR,
                           &reuse, sizeof (reuse));
 
        // Error management
    if (reuse_err == -1)
        err(EXIT_FAILURE, "Fail to set socket options");

    //save socket
    
    server_fd = fdaccept_register(server_fd);
    
    if(server_fd == -1)
        err(EXIT_FAILURE, "Fail to accept socket");    

    //bind socket
    
    errm = bind(server_fd, resinfo->ai_addr, resinfo->ai_addrlen);
    
    if (errm == -1)
        err(EXIT_FAILURE, "Fail to bind socket");
    
    //start listenning
    
    errm = listen(server_fd, 128); //Max pending connection is 128
        
    if (errm == -1)
        err(EXIT_FAILURE, "Fail to listen on socket");
    
    //enter accepting loop
    
    warn("Server is listenning on port %s", portname);
    
    for(;;)
    {
        int fdcnx = accept(server_fd, NULL, 0);
        
        if(fdcnx == -1)
            err(EXIT_FAILURE, "Failed to accept connexion");
        
        if(fork())
        {
            //Parent
            
            close(fdcnx);
            continue;
        }
        
        //Child
        
        close(server_fd);
        
        //Here comes the program function
        //BEGIN
        
        echo(fdcnx, fdcnx);
        
        //END
        
        close(fdcnx);
    }
    close(server_fd);  
}

int main(int argc, char* argv[])
{
    //Handle arguments
    
    const char *portname;
     
    if(argc > 1)    
    {
        portname = argv[1];
    }
    else
        err(EXIT_FAILURE, "Failed to get port");
    
    struct sigaction sigint;
 
    // Handle terminaison through Ctrl-C SIGINT
    memset(&sigint, 0, sizeof (struct sigaction));
    sigint.sa_handler = sigint_handler;
    sigfillset(&sigint.sa_mask);
    sigint.sa_flags = SA_NODEFER;
    if ( sigaction(SIGINT, &sigint, NULL) == -1)
        err(EXIT_FAILURE, "can't change SIGINT behavior");
 
    struct sigaction sigchld;
 
    // Avoid zombies and don't get notify about children SIGCHLD
    memset(&sigchld, 0, sizeof (struct sigaction));
    sigchld.sa_handler = SIG_DFL;
    sigemptyset(&sigchld.sa_mask);
    sigchld.sa_flags = SA_NOCLDSTOP | SA_NOCLDWAIT;
    if ( sigaction(SIGCHLD, &sigchld, NULL) == -1 )
        err(EXIT_FAILURE, "can't change SIGCHLD behavior");
    
    //Server

    server(portname);
    return 1;
}
