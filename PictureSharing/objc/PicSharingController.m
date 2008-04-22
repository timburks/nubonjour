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
- (IBAction)toggleSharing:(id)sender;
- (IBAction)popupChangedPicture:(id)sender;
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


- (void)awakeFromNib {
    NSImage * picture;
    picture = [[NSImage alloc] initWithContentsOfFile:[NSString stringWithFormat:@"/Library/Desktop Pictures/Nature/Dew Drop.jpg"]];

    if(picture) [imageView setImage:picture];

    [picture release];
    // Set up a default name for the picture service. The user should change this, but it's not a big deal.
    [serviceNameField setStringValue:@"Just another picture service"];
    [[NSApplication sharedApplication] setDelegate: self];
}


- (IBAction)popupChangedPicture:(id)sender {
    NSImage * picture;
    picture = [[NSImage alloc] initWithContentsOfFile:[NSString stringWithFormat:@"/Library/Desktop Pictures/Nature/%@.jpg", [[sender selectedItem] title]]];

    if (picture) [imageView setImage:picture];

    [picture release];
}


// This object is the delegate of the NSApplication instance so we can get notifications about various states.
// Here, the NSApplication shared instance is asking if and when we should terminate. By listening for this
// message, we can stop the service cleanly, and then indicate to the NSApplication instance that it's all right
// to quit immediately.
- (NSApplicationTerminateReply) applicationShouldTerminate:(NSApplication *)sender {

    if(netService) [netService stop];
        return NSTerminateNow;
}


// This object is the delegate of its NSNetService. It should implement the NSNetServiceDelegateMethods that
// are relevant for publication (see NSNetServices.h).
- (void)netServiceWillPublish:(NSNetService *)sender {
    [toggleSharingButton setTitle:@"Stop"];
    [shortStatusText setStringValue:@"Picture Sharing is on."];
    [longerStatusText setStringValue:@"Click Stop to turn off Picture Sharing."];
}


- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict {
    // Display some meaningful error message here, using the longerStatusText as the explanation.
    [toggleSharingButton setTitle:@"Start"];
    [shortStatusText setStringValue:@"Picture Sharing is off."];

    if([[errorDict objectForKey:NSNetServicesErrorCode] intValue] == NSNetServicesCollisionError) {
        [longerStatusText setStringValue:@"A name collision occurred. A service is already running with that name someplace else."];
        [serviceNameField setEnabled:YES];
    } else {
        [longerStatusText setStringValue:@"Some other unknown error occurred."];
    }

    [listeningSocket release];
    listeningSocket = nil;
    [netService release];
    netService = nil;
}


- (void)netServiceDidStop:(NSNetService *)sender {
    [toggleSharingButton setTitle:@"Start"];
    [shortStatusText setStringValue:@"Picture Sharing is off."];
    [longerStatusText setStringValue:@"Click Start to turn on Picture Sharing and allow other users to see a thumbnail of the picture below."];

    // We'll need to release the NSNetService sending this, since we want to recreate it in sync with the socket
    // at the other end. Since there's only the one NSNetService in this application, we can just release it.
    [netService release];
    netService = nil;
}


// This object is also listening for notifications from its NSFileHandle. When an incoming connection is seen
// by the listeningSocket object, we get the NSFileHandle representing the near end of the connection. We write
// the thumbnail image to this NSFileHandle instance.
- (void)connectionReceived:(NSNotification *)aNotification {
    NSFileHandle * incomingConnection = [[aNotification userInfo] objectForKey:NSFileHandleNotificationFileHandleItem];
    NSData * representationToSend = [[imageView image] TIFFRepresentation];
    [[aNotification object] acceptConnectionInBackgroundAndNotify];
    [incomingConnection writeData:representationToSend];
    [incomingConnection closeFile];
    numberOfDownloads++;
    [longerStatusText setStringValue:[NSString stringWithFormat:@"Click Stop to turn off Picture Sharing.\nNumber of downloads this session: %d.", numberOfDownloads]];
}
@end