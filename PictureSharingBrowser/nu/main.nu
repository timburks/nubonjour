(load "nu")      	;; essentials
(load "cocoa")		;; wrapped frameworks
(load "console")	;; interactive console
(import Cocoa)

(class PicBrowserController
     (- (void)awakeFromNib is
        (set @browser ((NSNetServiceBrowser alloc) init))
        (set @services (array))
        (@browser setDelegate:self)
        
        (@ipAddressField setStringValue:"")
        (@portField setStringValue:"")
        
        ;; Passing in "" for the domain causes us to browse in the default browse domain,
        ;; which currently will always be "local".  The service type should be registered
        ;; with IANA, and it should be listed at <http://www.iana.org/assignments/port-numbers>.
        ;; At minimum, the service type should be registered at <http://www.dns-sd.org/ServiceTypes.html>
        ;; Our service type "wwdcpic" isn't listed because this is just sample code.
        (@browser searchForServicesOfType:"_wwdcpic._tcp." inDomain:""))
     
     (- (void)readAllTheData:(id)note is
        (set theImage ((NSImage alloc) initWithData:((note userInfo) objectForKey:NSFileHandleNotificationDataItem)))
        (@imageView setImage:theImage)
        ((NSNotificationCenter defaultCenter) removeObserver:self name:NSFileHandleReadToEndOfFileCompletionNotification object:(note object)))
     
     ;; This object is the delegate of its NSNetServiceBrowser object. We're only interested in services-related methods,
     ;; so that's what we'll call.
     (- (void)netServiceBrowser:(id)aNetServiceBrowser didFindService:(id)aNetService moreComing:(BOOL)moreComing is
        (@services addObject:aNetService)
        (unless moreComing (@pictureServiceList reloadData)))
     
     (- (void)netServiceBrowser:(id)aNetServiceBrowser didRemoveService:(id)aNetService moreComing:(BOOL)moreComing is
        ;; This case is slightly more complicated. We need to find the object in the list and remove it.
        ;(@services removeObjectIdenticalTo:aNetService)
        (set enumerator (@services objectEnumerator))        
        (while (set currentNetService (enumerator nextObject))
               (if (currentNetService isEqual:aNetService)
                   (@services removeObject:currentNetService)
                   (break)))
        (if (and @serviceBeingResolved (@serviceBeingResolved isEqual:aNetService))
            (@serviceBeingResolved stop)
            (set @serviceBeingResolved nil))        
        (unless moreComing (@pictureServiceList reloadData)))
     
     ;; This object is the data source of its NSTableView.
     ;; servicesList is the NSArray containing all those services that have been discovered.
     (- (int)numberOfRowsInTableView:(id)theTableView is
        (@services count))
     
     (- (id)tableView:(id)theTableView objectValueForTableColumn:(id)theColumn row:(int)rowIndex is
        ((@services objectAtIndex:rowIndex) name))
     
     (- (void)serviceClicked:(id)sender is
        ;; The row that was clicked corresponds to the object in services we wish to contact.
        (set index (sender selectedRow))
        ;;  Make sure to cancel any previous resolves.
        (if @serviceBeingResolved
            (@serviceBeingResolved stop)
            (set @serviceBeingResolved nil))
        (@imageView setImage:nil)
        (if (eq -1 index)
            (then (@ipAddressField setStringValue:"")
                  (@portField setStringValue:""))
            (else (set @serviceBeingResolved (@services objectAtIndex:index))
                  (@serviceBeingResolved setDelegate:self)
                  (@serviceBeingResolved resolve))))
     )






;; define the application delegate class
(class ApplicationDelegate is NSObject
     (imethod (void) applicationDidFinishLaunching: (id) sender is
          (set $console ((NuConsoleWindowController alloc) init))
          ($console toggleConsole:self)))

;; install the delegate and keep a reference to it since the application won't retain it.
((NSApplication sharedApplication) setDelegate:(set delegate ((ApplicationDelegate alloc) init)))

;; this makes the application window take focus when we've started it from the terminal
((NSApplication sharedApplication) activateIgnoringOtherApps:YES)

;; run the main Cocoa event loop
(NSApplicationMain 0 nil)
