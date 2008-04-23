(load "nu")      	;; essentials
(load "NuBonjour")

(import Cocoa)

(class Handler is NSObject
     (ivars)
     
     (- (void)socketConnected:(id)sock is
        (puts "handler connected")
        (set @data (NSMutableData data)))
     
     (- (void)socketConnectFailed:(id)sock is
        (puts "handler connect failed")
        (puts "error is #{(self error)}"))
     
     (- (void)socketBecameReadable:(id)sock is
        (puts "handler is readable")
        (set data (sock readData))
        (set string ((NSString alloc) initWithData:data encoding:NSUTF8StringEncoding))
        (puts (+ ">> " string))
        (self writeString:string toSocket:sock)
        (if (/quit/ findInString:string)
            (sock close))
        (if (eq (data length) 0)
            (sock close)))
     
     (- (void) writeString:(id) string toSocket:(id) socket is
        (@data appendData:(string dataUsingEncoding:NSUTF8StringEncoding))
        (if (socket isWritable)
            (self socketBecameWritable:socket)))
     
     (- (void)socketBecameWritable:(id)sock is
        (puts "handler is writable")
        (unless (eq (@data length) 0)
                (try
                    (set @data (NSMutableData dataWithData:(sock writeData:@data)))
                    (catch (exception)
                           (puts (exception description))
                           (sock close))))))

;; define the application delegate class
(class RemoteNuServer is NSObject
     (ivars)
          
     ; This object is the delegate of the NSApplication instance so we can get notifications about various states.
     ; Here, the NSApplication shared instance is asking if and when we should terminate. By listening for this
     ; message, we can stop the service cleanly, and then indicate to the NSApplication instance that it's all right
     ; to quit immediately.
     (- (int) applicationShouldTerminate:(id)sender is
        (if @netService (@netService stop))
        NSTerminateNow)
     
     (- initWithName:name is
        (super init)
        (set @serviceName name)
        (self startSharing)
        self)
     
     (- (void)startSharing is
        (unless (and @netService @listeningSocket)
                (set @listeningSocket (AGSocket tcpSocket))
                (@listeningSocket setDelegate:self)
                (set @address (AGInetSocketAddress addressWithHostname:"localhost" port:4040))
                ;; lazily instantiate the NSNetService object that will advertise on our behalf.
                ;; Passing in "" for the domain causes the service to be registered in the
                ;; default registration domain, which will currently always be "local"
                (set @netService ((NSNetService alloc) initWithDomain:""
                                  type:"_nuserve._tcp."
                                  name:@serviceName
                                  port:(@address port)))
                (@netService setDelegate:self))
        
        (if (and @netService @listeningSocket)
            (@listeningSocket listenOnAddress:@address)
            (@netService publish)))
     
     (- (void)socket:(id)sock acceptedChild:(id)child is
        (puts "connection received, creating handler")
        (set $child child)
        (child setDelegate:(set @h ((Handler alloc) init))))
     
     ;; This object is the delegate of its NSNetService. It should implement the NSNetServiceDelegateMethods that
     ;; are relevant for publication (see NSNetServices.h).
     (- (void)netServiceWillPublish:(id)sender is
        (puts "publishing"))
     
     (- (void)netServiceDidStop:(id)sender is
        (puts "stopping")
        ;; We'll need to release the NSNetService sending this, since we want to recreate it in sync with the socket
        ;; at the other end. Since there's only the one NSNetService in this application, we can just release it.
        (set @netService nil))
     
     (- (void)netService:(id)sender didNotPublish:(id)errorDict is
        (puts "did not publish")
        ;; Display some meaningful error message here, using the longerStatusText as the explanation.
        (if (eq (errorDict objectForKey:NSNetServicesErrorCode) NSNetServicesCollisionError)
            (then (puts "A name collision occurred. A service is already running with that name someplace else."))
            (else (puts "Some unknown error occurred.")))
        (set @listeningSocket nil)
        (set @netService nil)))

(set c ((RemoteNuServer alloc) initWithName:"Nu Server"))

(puts "here we go")
((NSRunLoop mainRunLoop) runUntilDate:(NSDate distantFuture))

