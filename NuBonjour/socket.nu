;; Demo. Uses NuBonjour to execute an HTTP request

(load "NuBonjour")

(set strerror (NuBridgedFunction functionWithName:"strerror" signature:"*I"))

(class SocketTestDelegate is NSObject
     (ivars)
     
     (- (id)initWithURL:(id)url is
        (super init)
        (set @socket (AGSocket tcpSocket))
        (@socket setDelegate:self)
        (set host (url host))
        (set port (url port))
        (unless port (set port 80))
        (set address (AGInetSocketAddress addressWithHostname:host port:(port unsignedShortValue)))
        (@socket connectToAddressInBackground:address)
        (set @request ((NSMutableData alloc) initWithData:
                       ("GET #{(url description)} HTTP/1.1\r\nHOST: #{(url host)}\r\n\r\n"
                             dataUsingEncoding:NSUTF8StringEncoding)))
        self)
     
     (- (void)socketConnected:(id)sock is
        (puts "connected"))
     
     (- (void)socketConnectFailed:(id)sock is
        (puts (+ "error: " (strerror (@socket error))))
        (@socket close))
     
     (- (void)socketBecameReadable:(id)sock is
        (try
            (set @data (@socket readData))
            (catch (exception)
                   (puts (exception description))
                   (@socket close)))
        ((NSFileHandle fileHandleWithStandardOutput) writeData:@data)
        (if (eq 0 (@data length))
            (puts "closing socket")
            (@socket close)))
     
     (- (void)socketBecameWritable:(id)sock is
        (if (> (@request length) 0)
            (try
                (set dataLeft (@socket writeData:@request))
                (@request setData:dataLeft)
                (catch (exception)
                       (puts (exception description))
                       (@socket close))))))

(set url (NSURL URLWithString:"http://programming.nu/"))
(set test ((SocketTestDelegate alloc) initWithURL:url))
((NSRunLoop currentRunLoop) runUntilDate:(NSDate dateWithTimeIntervalSinceNow:2.5))
