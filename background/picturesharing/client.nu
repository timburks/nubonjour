(load "nu")      	;; essentials
(load "cocoa")		;; wrapped frameworks
(load "console")	;; interactive console
(load "NuBonjour")

(import Cocoa)

(global AF_INET 2)

(class PicBrowserController is NSObject
     (ivars)
     
     (- (void)awakeFromNib is
        (set @browser ((NSNetServiceBrowser alloc) init))
        (set @services (array))
        (@browser setDelegate:self)
        ;; Passing in "" for the domain causes us to browse in the default browse domain,
        ;; which currently will always be "local".  The service type should be registered
        ;; with IANA, and it should be listed at <http://www.iana.org/assignments/port-numbers>.
        ;; At minimum, the service type should be registered at <http://www.dns-sd.org/ServiceTypes.html>
        ;; Our service type "wwdcpic" isn't listed because this is just sample code.
        (@browser searchForServicesOfType:"_wwdcpic._tcp." inDomain:""))
     
     (- (void)readAllTheData:(id)note is
        (set theData ((note userInfo) objectForKey:NSFileHandleNotificationDataItem))
        (puts ("received #{(theData length)} bytes"))
        ((NSNotificationCenter defaultCenter)
         removeObserver:self
         name:NSFileHandleReadToEndOfFileCompletionNotification
         object:(note object)))
     
     ;; This object is the delegate of its NSNetServiceBrowser object. We're only interested in services-related methods,
     ;; so that's what we'll call.
     (- (void)netServiceBrowser:(id)aNetServiceBrowser didFindService:(id)aNetService moreComing:(BOOL)moreComing is
        (@services addObject:aNetService)
        (puts "found service #{(aNetService name)}"))
     
     (- (void)netServiceBrowser:(id)aNetServiceBrowser didRemoveService:(id)aNetService moreComing:(BOOL)moreComing is
        ;; This case is slightly more complicated. We need to find the object in the list and remove it.
        ;(@services removeObjectIdenticalTo:aNetService)
        (set enumerator (@services objectEnumerator))
        (while (set currentNetService (enumerator nextObject))
               (if (currentNetService isEqual:aNetService)
                   (@services removeObject:currentNetService)
                   (break)))
        (puts "removed service #{(aNetService name)}")
        (if (and @serviceBeingResolved (@serviceBeingResolved isEqual:aNetService))
            (@serviceBeingResolved stop)
            (set @serviceBeingResolved nil)))
     
     (- (void)netServiceDidResolveAddress:(id)sender is
        (if (> ((sender addresses) count) 0)
            ;; Iterate through addresses until we find an IPv4 address
            (set mySocketAddress nil)
            ((sender addresses) each:
             (do (address)
                 (set a ((NuSocketAddress alloc) initWithData:address))
                 (if (eq (a family) AF_INET)
                     (set mySocketAddress a))))
            (if mySocketAddress
                ;; Cancel the resolve now that we have an IPv4 address.
                (sender stop)
                (set @serviceBeingResolved nil)
                (puts (mySocketAddress ipAddressString))
                (puts ((mySocketAddress port) stringValue))
                (set remoteConnection (NSFileHandle fileHandleWithRemoteINETStreamCloseOnDealloc:YES))
                (if remoteConnection
                    ((NSNotificationCenter defaultCenter)
                     addObserver:self
                     selector:"readAllTheData:"
                     name:NSFileHandleReadToEndOfFileCompletionNotification
                     object:remoteConnection)
                    (if (eq (remoteConnection connectToSocketAddress:mySocketAddress) 0)
                        (remoteConnection readToEndOfFileInBackgroundAndNotify))))))
     
     (- (void)download:(int)index is
        ;;  Make sure to cancel any previous resolves.
        (if @serviceBeingResolved
            (@serviceBeingResolved stop)
            (set @serviceBeingResolved nil))
        (set @serviceBeingResolved (@services objectAtIndex:index))
        (@serviceBeingResolved setDelegate:self)
        (@serviceBeingResolved resolve)))

(set c ((PicBrowserController alloc) init))
(c awakeFromNib)

(puts "here we go")

(function run ()
     ((NSRunLoop mainRunLoop) runUntilDate:(NSDate dateWithTimeIntervalSinceNow:1)))
