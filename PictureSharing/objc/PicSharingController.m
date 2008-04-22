#import <Foundation/Foundation.h>

// imports required for socket initialization
#import <sys/socket.h>
#import <netinet/in.h>
#import <unistd.h>

id createSocketOnRandomPort(int *chosenPort)
{
    // Here, create the socket from traditional BSD socket calls, and then set up an NSFileHandle with
    //that to listen for incoming connections.
    int fdForListening;
    struct sockaddr_in serverAddress;
    unsigned int namelen = sizeof(serverAddress);

    id listeningSocket;
    // In order to use NSFileHandle's acceptConnectionInBackgroundAndNotify method, we need to create a
    // file descriptor that is itself a socket, bind that socket, and then set it up for listening. At this
    // point, it's ready to be handed off to acceptConnectionInBackgroundAndNotify.
    if((fdForListening = socket(AF_INET, SOCK_STREAM, 0)) > 0) {
        memset(&serverAddress, 0, sizeof(serverAddress));
        serverAddress.sin_family = AF_INET;
        serverAddress.sin_addr.s_addr = htonl(INADDR_ANY);
        serverAddress.sin_port = 0;
        // Allow the kernel to choose a random port number by passing in 0 for the port.
        if (bind(fdForListening, (struct sockaddr *)&serverAddress, namelen) < 0) {
            close (fdForListening);
            return;
        }
        // Find out what port number was chosen.
        if (getsockname(fdForListening, (struct sockaddr *)&serverAddress, &namelen) < 0) {
            close(fdForListening);
            return;
        }
        *chosenPort = ntohs(serverAddress.sin_port);
        // Once we're here, we know bind must have returned, so we can start the listen
        if(listen(fdForListening, 1) == 0) {
            listeningSocket = [[NSFileHandle alloc] initWithFileDescriptor:fdForListening closeOnDealloc:YES];
        }
    }
    return listeningSocket;
}


