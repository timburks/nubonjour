#import <Cocoa/Cocoa.h>

@interface PicSharingController : NSObject
{
    IBOutlet id imageView;
    IBOutlet id longerStatusText;
    IBOutlet id serviceNameField;
    IBOutlet id shortStatusText;
    IBOutlet id toggleSharingButton;
    IBOutlet id picturePopUpMenu;
    NSNetService * netService;
    NSFileHandle * listeningSocket;
    int numberOfDownloads;
}
@end

// imports required for socket initialization
#import <sys/socket.h>
#import <netinet/in.h>
#import <unistd.h>

@implementation PicSharingController

- (IBAction)toggleSharing:(id)sender {

    uint16_t chosenPort;
    if(!listeningSocket) {
        // Here, create the socket from traditional BSD socket calls, and then set up an NSFileHandle with
        //that to listen for incoming connections.
        int fdForListening;
        struct sockaddr_in serverAddress;
        int namelen = sizeof(serverAddress);

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
            chosenPort = ntohs(serverAddress.sin_port);
            // Once we're here, we know bind must have returned, so we can start the listen
            if(listen(fdForListening, 1) == 0) {
                listeningSocket = [[NSFileHandle alloc] initWithFileDescriptor:fdForListening closeOnDealloc:YES];
            }
        }
    }
    if(!netService) {
        // lazily instantiate the NSNetService object that will advertise on our behalf.  Passing in "" for the domain causes the service
        // to be registered in the default registration domain, which will currently always be "local"
        netService = [[NSNetService alloc] initWithDomain:@"" type:@"_wwdcpic._tcp." name:[serviceNameField stringValue] port:chosenPort];
        [netService setDelegate:self];
    }
    if(netService && listeningSocket) {
        if([[sender title] isEqual:@"Start"]) {
            numberOfDownloads = 0;
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionReceived:) name:NSFileHandleConnectionAcceptedNotification object:listeningSocket];
            [listeningSocket acceptConnectionInBackgroundAndNotify];
            [netService publish];
            [serviceNameField setEnabled:NO];
        } else {
            [serviceNameField setEnabled:YES];
            [netService stop];
            [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleConnectionAcceptedNotification object:listeningSocket];
            // There is at present no way to get an NSFileHandle to -stop- listening for events, so we'll just have to tear it down and recreate it the next time we need it.
            [listeningSocket release];
            listeningSocket = nil;
        }
    }
}


@end