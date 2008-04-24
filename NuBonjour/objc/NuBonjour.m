#import <Foundation/Foundation.h>

// imports required for socket initialization
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>
#import <ifaddrs.h>

@interface NuSocketAddress : NSObject
{
    NSData *data;
    struct sockaddr *socketAddress;
}

@end

@implementation NuSocketAddress

+ (int) familyForAddress:(NSData *)data
{
    return ((struct sockaddr *)[data bytes])->sa_family;
}

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

+ (NSString *) localIPAddress
{
    NSString *name = nil;
    struct ifaddrs*                 list;
    struct ifaddrs*                 ifap;

    if(getifaddrs(&list) < 0)
        return NULL;

    for(ifap = list; ifap; ifap = ifap->ifa_next) {
        // Ignore loopback
        if((ifap->ifa_name[0] == 'l') && (ifap->ifa_name[1] == 'o'))
            continue;

        if(ifap->ifa_addr->sa_family == AF_INET) {
            char buffer[256];
            if (inet_ntop(AF_INET, &((struct sockaddr_in *)ifap->ifa_addr)->sin_addr, buffer, sizeof(buffer))) {
                name = [NSString stringWithCString:buffer];
            }
            break;
        }
    }

    freeifaddrs(list);
    return name;
}

@end

@implementation NSFileHandle(Nu)

+ (id) fileHandleWithRemoteINETStreamCloseOnDealloc:(int) closeOnDealloc
{
    int socketToRemoteServer = socket(AF_INET, SOCK_STREAM, 0);
    if(socketToRemoteServer > 0) {
        return [[self alloc]
            initWithFileDescriptor:socketToRemoteServer
            closeOnDealloc:closeOnDealloc];
    }
    else {
        return nil;
    }
}

- (int) connectToSocketAddress:(NuSocketAddress *) socketAddress
{
    struct sockaddr *s = [socketAddress socketAddress];
    return connect([self fileDescriptor], s, sizeof(*s));
}

+ (id) fileHandleWithLocalINETStreamCloseOnDealloc:(int) closeOnDealloc
{
    // Here, create the socket from traditional BSD socket calls,
    // and then set up an NSFileHandle with that to listen for incoming connections.
    int fdForListening;
    struct sockaddr_in serverAddress;
    unsigned int namelen = sizeof(serverAddress);

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
            close(fdForListening);
            return nil;
        }
        // Once we're here, we know bind must have returned, so we can start the listen
        if(listen(fdForListening, 1) == 0) {
            return [[self alloc] initWithFileDescriptor:fdForListening closeOnDealloc:closeOnDealloc];
        }
    }
    return nil;
}

- (int) portNumber
{
    // Find out what port number is being used by the socket
    struct sockaddr_in serverAddress;
    unsigned int namelen = sizeof(serverAddress);
    if (getsockname([self fileDescriptor], (struct sockaddr *)&serverAddress, &namelen) < 0)
        return 0;
    else
        return ntohs(serverAddress.sin_port);
}

@end
