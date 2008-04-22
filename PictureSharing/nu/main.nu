(load "nu")      	;; essentials
(load "cocoa")		;; wrapped frameworks
(load "console")	;; interactive console
(load "NuNetwork")
(import Cocoa)

;; define the application delegate class
(class PicSharingController is NSObject
     (ivar (id) imageView
           (id) longerStatusText
           (id) serviceNameField
           (id) shortStatusText
           (id) toggleSharingButton
           (id) picturePopUpMenu
           (id) netService
           (id) listeningSocket
           (int) numberOfDownloads)
     
     (- (void) applicationDidFinishLaunching: (id) sender is
        (set $console ((NuConsoleWindowController alloc) init))
        ($console toggleConsole:self))
     
     (- (void)connectionReceived:(id)notification is
        (set incomingConnection ((notification userInfo) objectForKey:NSFileHandleNotificationFileHandleItem))
        ((notification object) acceptConnectionInBackgroundAndNotify)
        (incomingConnection writeData:((@imageView image) TIFFRepresentation));
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
     
     (- (void)awakeFromNib is
        (set picture ((NSImage alloc) initWithContentsOfFile:"/Library/Desktop Pictures/Nature/Dew Drop.jpg"))
        (if picture (@imageView setImage:picture))
        ;; Set up a default name for the picture service. The user should change this, but it's not a big deal.
        (@serviceNameField setStringValue:"Just another picture service"))
     
     (- (void)toggleSharing:(id)sender is
        (unless (and @netService @listeningSocket)
                (set @listeningSocket (NSFileHandle fileHandleWithLocalINETStreamCloseOnDealloc:YES))
                ;; lazily instantiate the NSNetService object that will advertise on our behalf.
                ;; Passing in "" for the domain causes the service to be registered in the
                ;; default registration domain, which will currently always be "local"
                (set @netService ((NSNetService alloc) initWithDomain:""
                                  type:"_wwdcpic._tcp."
                                  name:(@serviceNameField stringValue)
                                  port:(@listeningSocket portNumber)))
                (@netService setDelegate:self))
        
        (if (and @netService @listeningSocket)
            (if (eq (sender title) "Start")
                (then
                     (set @numberOfDownloads 0)
                     ((NSNotificationCenter defaultCenter)
                      addObserver:self selector:"connectionReceived:"
                      name:NSFileHandleConnectionAcceptedNotification object:@listeningSocket)
                     (@listeningSocket acceptConnectionInBackgroundAndNotify)
                     (@netService publish)
                     (@serviceNameField setEnabled:NO))
                (else
                     (@serviceNameField setEnabled:YES)
                     (@netService stop)
                     ((NSNotificationCenter defaultCenter) removeObserver:self
                      name:NSFileHandleConnectionAcceptedNotification object:@listeningSocket)
                     ;; There is at present no way to get an NSFileHandle to -stop- listening for events,
                     ;; so we'll just have to tear it down and recreate it the next time we need it.
                     (set @listeningSocket nil)))))
     
     (- (void)popupChangedPicture:(id)sender is
        (set picture ((NSImage alloc) initWithContentsOfFile:
                      (+ "/Library/Desktop Pictures/Nature/" ((sender selectedItem) title) ".jpg")))
        (if picture (@imageView setImage:picture)))
     
     ;; This object is the delegate of its NSNetService. It should implement the NSNetServiceDelegateMethods that
     ;; are relevant for publication (see NSNetServices.h).
     (- (void)netServiceWillPublish:(id)sender is
        (@toggleSharingButton setTitle:"Stop")
        (@shortStatusText setStringValue:"Picture Sharing is on.")
        (@longerStatusText setStringValue:"Click Stop to turn off Picture Sharing."))
     
     (- (void)netServiceDidStop:(id)sender is
        (@toggleSharingButton setTitle:"Start")
        (@shortStatusText setStringValue:"Picture Sharing is off.")
        (@longerStatusText setStringValue:"Click Start to turn on Picture Sharing and allow other users to see a thumbnail of the picture below.")
        ;; We'll need to release the NSNetService sending this, since we want to recreate it in sync with the socket
        ;; at the other end. Since there's only the one NSNetService in this application, we can just release it.
        (set @netService nil))
     
     (- (void)netService:(id)sender didNotPublish:(id)errorDict is
        ;; Display some meaningful error message here, using the longerStatusText as the explanation.
        (@toggleSharingButton setTitle:"Start")
        (@shortStatusText setStringValue:"Picture Sharing is off.")
        (if (eq (errorDict objectForKey:NSNetServicesErrorCode) NSNetServicesCollisionError)
            (then (@longerStatusText setStringValue:"A name collision occurred. A service is already running with that name someplace else.")
                  (@serviceNameField setEnabled:YES))
            (else (@longerStatusText setStringValue:"Some other unknown error occurred.")))
        (set @listeningSocket nil)
        (set @netService nil)))

;; install the delegate and keep a reference to it since the application won't retain it.
((NSApplication sharedApplication) setDelegate:(set delegate ((PicSharingController alloc) init)))

;; this makes the application window take focus when we've started it from the terminal
((NSApplication sharedApplication) activateIgnoringOtherApps:YES)

;; run the main Cocoa event loop
(NSApplicationMain 0 nil)
