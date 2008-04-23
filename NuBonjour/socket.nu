
(load "NuBonjour")

(class SocketTestDelegate is NSObject
     (ivars)
     
     (- (id)initWithURL:(id)url is
        (super init)
        (set @socket (AGSocket tcpSocket))
        (@socket setDelegate:self)
        (set host (url host))
        (set port (url port))
        (set address (AGInetSocketAddress addressWithHostname:host port:(port unsignedShortValue))) ;; port should run through htons()        
        (@socket connectToAddressInBackground:address)
        (set @request ((NSMutableData alloc) initWithData:("GET #{url} HTTP/1.0\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding)))
        self)
     
     (- (void)socketConnected:(id)sock is
        (puts "connected"))
     
     (- (void)socketConnectFailed:(id)sock is
        (puts (@socket error))
        (@socket close))
     
     (- (void)socketBecameReadable:(id)sock is
     NSData *data;
     NS_DURING
     data = [socket readData];
     NS_HANDLER
     NSLog([localException description]);
[socket close];
NS_ENDHANDLER
[[NSFileHandle fileHandleWithStandardOutput] writeData:data];
if (![data length])
[socket close];
}

- (void)socketBecameWritable:(AGSocket *)sock {
if (![request length])
return;
NS_DURING
NSData *dataLeft = [socket writeData:request];
[request setData:dataLeft];
NS_HANDLER
NSLog([localException description]);

[socket close];
NS_ENDHANDLER
}

@end
