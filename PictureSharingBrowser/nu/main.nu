(load "nu")      	;; essentials
(load "cocoa")		;; wrapped frameworks
(load "console")	;; interactive console

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
