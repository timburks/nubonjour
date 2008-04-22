
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

@interface NuSocketAddress : NSObject
{
    NSData *data;
    struct sockaddr *socketAddress;
}

@end

@implementation NuSocketAddress

- (NuSocketAddress *) initWithData:(NSData *) d
{
    [super init];
    data = [d retain];
    socketAddress = (struct sockaddr *)[data bytes];
    return self;
}

- (void) dealloc
{
    [data release];
    [super dealloc];
}

- (int) family
{
    return socketAddress->sa_family;
}

- (struct sockaddr *) socketAddress
{
    return socketAddress;
}

- (NSString *) ipAddressString
{
    char buffer[256];
    if (inet_ntop(AF_INET, &((struct sockaddr_in *)socketAddress)->sin_addr, buffer, sizeof(buffer))) {
        return [NSString stringWithCString:buffer];
    }
    else {
        return nil;
    }
}

- (int) port
{
    return ntohs(((struct sockaddr_in *) socketAddress)->sin_port);
}

@end

@implementation NSFileHandle(Nu)

- (int) connectToSocketAddress:(struct sockaddr *) socketAddress
{
    return connect([self fileDescriptor], (struct sockaddr *)socketAddress, sizeof(*socketAddress));
}

@end

@implementation PicBrowserController

- (void)netServiceDidResolveAddress:(NSNetService *)sender
{
    if ([[sender addresses] count] > 0) {
        // get an address and port
        NuSocketAddress *mySocketAddress = nil;

        // Iterate through addresses until we find an IPv4 address
        int index;
        for (index = 0; index < [[sender addresses] count]; index++) {
            mySocketAddress = [[NuSocketAddress alloc] initWithData:[[sender addresses] objectAtIndex:index]];
            if ([mySocketAddress family] == AF_INET)
                break;
        }

        // Be sure to include <netinet/in.h> and <arpa/inet.h> or else you'll get compile errors.
        if (mySocketAddress) {
            switch([mySocketAddress family]) {
                case AF_INET:
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

        // get presentation forms of the socket address
        NSString *ipAddressString = [mySocketAddress ipAddressString];
        if (ipAddressString) [ipAddressField setStringValue:ipAddressString];
        [portField setStringValue:[NSString stringWithFormat:@"%d", [mySocketAddress port]]];

        int socketToRemoteServer = socket(AF_INET, SOCK_STREAM, 0);
        if(socketToRemoteServer > 0) {
            NSFileHandle * remoteConnection = [[NSFileHandle alloc] initWithFileDescriptor:socketToRemoteServer closeOnDealloc:YES];
            if(remoteConnection) {
                [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(readAllTheData:) name:NSFileHandleReadToEndOfFileCompletionNotification object:remoteConnection];
                if ([remoteConnection connectToSocketAddress:[mySocketAddress socketAddress]] == 0) {
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
