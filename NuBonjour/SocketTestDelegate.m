// SocketTestDelegate.m
//
// Copyright (c) 2002 Aram Greenman. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
// 3. The name of the author may not be used to endorse or promote products derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "SocketTestDelegate.h"
#import <Foundation/Foundation.h>
#import <AGSocket/AGSocket.h>

@implementation SocketTestDelegate

- (id)initWithURL:(NSURL *)url {
	if (self = [super init]) {
		socket = [[AGSocket tcpSocket] retain];
		[socket setDelegate:self];
		
		NSString *host = [url host];
		NSNumber *port = [url port];
		AGInetSocketAddress *addr = [AGInetSocketAddress addressWithHostname:host ? host : @"localhost" port:htons(port ? [port unsignedShortValue] : 80)];
		
		if (!addr) {
			[self release];
			return nil;
		}
		
		[socket connectToAddressInBackground:addr];
		
		request = [[NSMutableData alloc] initWithData:[[NSString stringWithFormat:@"GET %@ HTTP/1.0\r\n\r\n", url] dataUsingEncoding:NSUTF8StringEncoding]];
	}
	return self;
}

- (void)dealloc {
	[socket release];
	[request release];
	[super dealloc];
}


- (void)socketConnected:(AGSocket *)sock {
	NSLog(@"Connected");
}

- (void)socketConnectFailed:(AGSocket *)sock {
	NSLog(@"Connect failed: %s", strerror([socket error]));
	[socket close];
}

- (void)socketBecameReadable:(AGSocket *)sock {
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
