
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

- (IBAction)serviceClicked:(id)sender {
    // The row that was clicked corresponds to the object in services we wish to contact.
    int index = [sender selectedRow];

    //  Make sure to cancel any previous resolves.
    if (serviceBeingResolved) {
        [serviceBeingResolved stop];
        [serviceBeingResolved release];
        serviceBeingResolved = nil;
    }

    [imageView setImage:nil];

    if(-1 == index) {
        [ipAddressField setStringValue:@""];
        [portField setStringValue:@""];
    } else {        
        serviceBeingResolved = [services objectAtIndex:index];
        [serviceBeingResolved retain];
        [serviceBeingResolved setDelegate:self];
        [serviceBeingResolved resolve];
    }
}


- (void)netServiceDidResolveAddress:(NSNetService *)sender {

    if ([[sender addresses] count] > 0) {
        NSData * address;
        struct sockaddr * socketAddress;
        NSString * ipAddressString = nil;
        NSString * portString = nil;
        int socketToRemoteServer;
        char buffer[256];
        int index;

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
            } else {
                close(socketToRemoteServer);
            }
        }
    }
}


- (void)readAllTheData:(NSNotification *)note {
    NSImage * theImage = [[NSImage alloc] initWithData:[[note userInfo] objectForKey:NSFileHandleNotificationDataItem]];
    [imageView setImage:theImage];
    [theImage release];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadToEndOfFileCompletionNotification object:[note object]];
    [[note object] release];
}


- (void)awakeFromNib {
    browser = [[NSNetServiceBrowser alloc] init];
    services = [[NSMutableArray array] retain];
    [browser setDelegate:self];

    [ipAddressField setStringValue:@""];
    [portField setStringValue:@""];

    // Passing in "" for the domain causes us to browse in the default browse domain,
    // which currently will always be "local".  The service type should be registered
    // with IANA, and it should be listed at <http://www.iana.org/assignments/port-numbers>.
    // At minimum, the service type should be registered at <http://www.dns-sd.org/ServiceTypes.html>
    // Our service type "wwdcpic" isn't listed because this is just sample code.
    [browser searchForServicesOfType:@"_wwdcpic._tcp." inDomain:@""];
}


// This object is the delegate of its NSNetServiceBrowser object. We're only interested in services-related methods,
// so that's what we'll call.
- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
    [services addObject:aNetService];

    if(!moreComing) [pictureServiceList reloadData];
}


- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
    // This case is slightly more complicated. We need to find the object in the list and remove it.
    NSEnumerator * enumerator = [services objectEnumerator];
    NSNetService * currentNetService;

    while(currentNetService = [enumerator nextObject]) {
        if ([currentNetService isEqual:aNetService]) {
            [services removeObject:currentNetService];
            break;
        }
    }

    if (serviceBeingResolved && [serviceBeingResolved isEqual:aNetService]) {
        [serviceBeingResolved stop];
        [serviceBeingResolved release];
        serviceBeingResolved = nil;
    }

    if(!moreComing) [pictureServiceList reloadData];
}


// This object is the data source of its NSTableView. servicesList is the NSArray containing all those services that
// have been discovered.
- (int)numberOfRowsInTableView:(NSTableView *)theTableView {
    return [services count];
}


- (id)tableView:(NSTableView *)theTableView objectValueForTableColumn:(NSTableColumn *)theColumn row:(int)rowIndex {
    return [[services objectAtIndex:rowIndex] name];
}
@end