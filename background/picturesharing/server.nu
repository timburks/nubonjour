(load "nu")      	;; essentials
(load "NuBonjour")

(import Cocoa)

;; define the application delegate class
(class PicSharingController is NSObject
     (ivars)
     
     (- (void)connectionReceived:(id)notification is
        (set incomingConnection ((notification userInfo) objectForKey:NSFileHandleNotificationFileHandleItem))
        ((notification object) acceptConnectionInBackgroundAndNotify)
        (incomingConnection writeData:(@picture TIFFRepresentation));
        (incomingConnection closeFile)
        (set @numberOfDownloads (+ 1 @numberOfDownloads))
        (@longerStatusText setStringValue:<<-END
Click Stop to turn off Picture Sharing.
Number of downloads this session: #{@numberOfDownloads}.END))
     
     ; This object is the delegate of the NSApplication instance so we can get notifications about various states.
     ; Here, the NSApplication shared instance is asking if and when we should terminate. By listening for this
     ; message, we can stop the service cleanly, and then indicate to the NSApplication instance that it's all right
     ; to quit immediately.
     (- (int) applicationShouldTerminate:(id)sender is
        (if @netService (@netService stop))
        NSTerminateNow)
     
     (- initWithName:name picture:file is
        (super init)
        (set @serviceName name)
        (set @picture ((NSImage alloc) initWithContentsOfFile:file))
        (self toggleSharing:self)
        self)
     
     (- (void)toggleSharing:(id)sender is
        (unless (and @netService @listeningSocket)
                (set @listeningSocket (NSFileHandle fileHandleWithLocalINETStreamCloseOnDealloc:YES))
                ;; lazily instantiate the NSNetService object that will advertise on our behalf.
                ;; Passing in "" for the domain causes the service to be registered in the
                ;; default registration domain, which will currently always be "local"
                (set @netService ((NSNetService alloc) initWithDomain:""
                                  type:"_wwdcpic._tcp."
                                  name:@serviceName
                                  port:(@listeningSocket portNumber)))
                (@netService setDelegate:self))
        
        (if (and @netService @listeningSocket)       
            (set @numberOfDownloads 0)
            ((NSNotificationCenter defaultCenter)
             addObserver:self selector:"connectionReceived:"
             name:NSFileHandleConnectionAcceptedNotification object:@listeningSocket)
            (@listeningSocket acceptConnectionInBackgroundAndNotify)
            (@netService publish)))
          
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

(set c ((PicSharingController alloc) initWithName:"one" picture:"/Library/Desktop Pictures/Nature/Dew Drop.jpg"))
(set d ((PicSharingController alloc) initWithName:"two" picture:"/Library/Desktop Pictures/Flow 3.jpg"))

(puts "here we go")
((NSRunLoop mainRunLoop) runUntilDate:(NSDate distantFuture))

