
#import <Cocoa/Cocoa.h>

@interface PicBrowserController : NSObject
{
    IBOutlet id imageView;
    IBOutlet id ipAddressField;
    IBOutlet id pictureServiceList;
    IBOutlet id portField;
    NSNetServiceBrowser * browser;
    NSMutableArray * services;
    NSNetService * serviceBeingResolved;
}

- (IBAction)serviceClicked:(id)sender;
@end

#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>

@implementation PicBrowserController

- (void)netServiceDidResolveAddress:(NSNetService *)sender
{

    if ([[sender addresses] count] > 0) {
        NSData * address;
        struct sockaddr * socketAddress;
        NSString * ipAddressString = nil;
        NSString * portString = nil;
        int socketToRemoteServer;
        char buffer[256];
        int index;

        // get an address and port

        // Iterate through addresses until we find an IPv4 address
        for (index = 0; index < [[sender addresses] count]; index++) {
            address = [[sender addresses] objectAtIndex:index];
            socketAddress = (struct sockaddr *)[address bytes];
            if (socketAddress->sa_family == AF_INET) break;
        }

        // Be sure to include <netinet/in.h> and <arpa/inet.h> or else you'll get compile errors.
        if (socketAddress) {
            switch(socketAddress->sa_family) {
                case AF_INET:
                    if (inet_ntop(AF_INET, &((struct sockaddr_in *)socketAddress)->sin_addr, buffer, sizeof(buffer))) {
                        ipAddressString = [NSString stringWithCString:buffer];
                        portString = [NSString stringWithFormat:@"%d", ntohs(((struct sockaddr_in *)socketAddress)->sin_port)];
                    }
                    // Cancel the resolve now that we have an IPv4 address.
                    [sender stop];
                    [sender release];
                    serviceBeingResolved = nil;
                    break;
                case AF_INET6:
                    // PictureSharing server doesn't support IPv6
                    return;
            }
        }
        //

        if (ipAddressString) [ipAddressField setStringValue:ipAddressString];
        if (portString) [portField setStringValue:portString];

        socketToRemoteServer = socket(AF_INET, SOCK_STREAM, 0);
        if(socketToRemoteServer > 0) {
            NSFileHandle * remoteConnection = [[NSFileHandle alloc] initWithFileDescriptor:socketToRemoteServer closeOnDealloc:YES];
            if(remoteConnection) {
                [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(readAllTheData:) name:NSFileHandleReadToEndOfFileCompletionNotification object:remoteConnection];
                if(connect(socketToRemoteServer, (struct sockaddr *)socketAddress, sizeof(*socketAddress)) == 0) {
                    [remoteConnection readToEndOfFileInBackgroundAndNotify];
                }
            }
            else {
                close(socketToRemoteServer);
            }
        }
    }
}

@end
