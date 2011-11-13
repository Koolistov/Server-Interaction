//
//  KVRequest.m
//  Koolistov
//
//  Created by Johan Kool on 26-10-10.
//  Copyright 2010-2011 Koolistov Pte Ltd. All rights reserved.
//  
//  Redistribution and use in source and binary forms, with or without modification, are 
//  permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above copyright notice, this list of 
//    conditions and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list 
//    of conditions and the following disclaimer in the documentation and/or other materials 
//    provided with the distribution.
//  * Neither the name of KOOLISTOV PTE. LTD. nor the names of its contributors may be used to 
//    endorse or promote products derived from this software without specific prior written 
//    permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY 
//  EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF 
//  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL 
//  THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
//  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT 
//  OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
//  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, 
//  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
//  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "KVServiceRequest.h"

#import "KVService.h"

#define kMaximumNumberOfAttempts 1

@interface KVServiceRequest ()

@property (nonatomic, retain) NSURLConnection *URLConnection;
@property (nonatomic, retain) NSURLRequest *URLRequest;
@property (nonatomic, retain) NSURLResponse *URLResponse;
@property (nonatomic, retain) NSMutableData *receivedData;
@property (nonatomic, retain) NSURLAuthenticationChallenge *currentChallenge;
@property (nonatomic, assign) int attemptCount;

- (void)processResponse:(NSURLResponse *)response receivedData:(NSData *)data error:(NSError *)error;

@end

@implementation KVServiceRequest

@synthesize service=service_;
@synthesize URL=URL_;
@synthesize HTTPMethod=HTTPMethod_;
@synthesize bodyData=bodyData_;
@synthesize allowCancel=allowCancel_;
@synthesize allowCaching=allowCaching_;
@synthesize forceRefresh=forceRefresh_;
@synthesize attemptCount=attemptCount_; 
@synthesize completionHandler=completionHandler_;
@synthesize URLConnection=URLConnection_;
@synthesize URLRequest=URLRequest_;
@synthesize URLResponse=URLResponse_;
@synthesize receivedData=receivedData_;
@synthesize currentChallenge=currentChallenge_;

- (id)init {
    self = [super init];
    if (self != nil) {
        self.allowCancel = YES;
    }
    return self;
}

- (void)dealloc {
    // Stop observing
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    self.service = nil;
    self.URL = nil;
    self.HTTPMethod = nil;
    self.bodyData = nil;
    self.completionHandler = nil;
    self.URLConnection = nil;
    self.URLRequest = nil;
    self.URLResponse = nil;
    self.receivedData = nil;
    self.currentChallenge = nil;
    [super dealloc];
}

- (void)send {
    NSAssert(self.URL != nil, @"No URL set");
    
    // Output the URL if logging is enabled
#ifdef DEBUG
    NSLog (@"Loading: %@", self.URL.absoluteString);
#endif

    // Create the request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.URL];
    [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
    [request setHTTPMethod:self.HTTPMethod];
    request.timeoutInterval = self.service.timeoutInterval;
    self.URLRequest = request;
    
    if (self.bodyData != nil) {            
        [request setHTTPBody:self.bodyData];
#ifdef DEBUG
        NSLog (@"Posting data: %@", self.bodyData);
#endif
    }
    
    // Caching
    if (self.allowCaching && !self.bodyData && !self.forceRefresh) {
        NSCachedURLResponse *earlierCachedResponse = [self.service.cache cachedResponseForRequest:request];
        
        if (earlierCachedResponse) {
            // Get details from cache
            [self processResponse:[earlierCachedResponse response] receivedData:[earlierCachedResponse data] error:nil];
              
#ifdef DEBUG
            NSLog (@"Using cached response: %@", [earlierCachedResponse response]);
#endif
            return;
        } 
    }
    
    // Create the connection
    self.URLConnection = [[[NSURLConnection alloc] initWithRequest:request delegate:self] autorelease];
    if (self.URLConnection) {
        self.receivedData = [NSMutableData data];
    } else {
        NSError *error = [NSError errorWithDomain:KVServiceErrorDomain code:KVServiceErrorNoConnection userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Could not create connection to server.", NSLocalizedDescriptionKey, nil]];

        [self processResponse:nil receivedData:nil error:error];
        
#ifdef DEBUG
        NSLog (@"Connection failed init: %@", error);
#endif
    }
}

- (BOOL)cancel {
    if (!self.allowCancel) {
        return NO;
    }
    if (!self.URLConnection) {
        return NO;
    }
    
#ifdef DEBUG
    NSLog (@"Cancelled: %@", self.URL);
#endif
    
    [self.URLConnection cancel];
    
    [self processResponse:nil receivedData:nil error:nil];
    
    self.URLConnection = nil;
    self.URLResponse = nil;
    self.receivedData = nil;
    
    return YES;
}

- (void)processResponse:(NSURLResponse *)response receivedData:(NSData *)data error:(NSError *)error {
    if (self.service.preprocessHandler != nil) {
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_async(queue, ^() {
            __block NSError *preprocessError = nil;
            id result = self.service.preprocessHandler(response, data, error, &preprocessError);
            dispatch_async(dispatch_get_main_queue(), ^() {
                if ([preprocessError.domain isEqualToString:KVServiceErrorDomain] && preprocessError.code == KVServiceErrorExpiredToken) {
                    // Expired token, request new one
                    KVServiceRequest *tokenRequest = [self.service.delegate tokenRequestForService:self.service];
                    [self.service performRequest:tokenRequest];
                    
                    // Start observing for KVServiceDidReceiveTokenNotification and KVServiceFailedToReceiveTokenNotification
                    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverReceivedToken:) name:KVServiceDidReceiveTokenNotification object:self.service];
                    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverFailedToReceiveToken:) name:KVServiceFailedToReceiveTokenNotification object:self.service];
 
                    return;
                }
                
                // Inform service
                if (!error && !preprocessError) {
                    [self.service request:self receivedResponse:response data:data];
                    self.completionHandler(response, result, nil);
                } else {
                    [self.service request:self receivedError:preprocessError ? preprocessError : error];
                    self.completionHandler(nil, nil, preprocessError ? preprocessError : error);
                }
            });
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^() {
            // Inform service
            if (error) {
                [self.service request:self receivedError:error];
                self.completionHandler(nil, nil, error);
            } else {
                [self.service request:self receivedResponse:response data:data];
                self.completionHandler(response, data, nil);
            }
        });
    }
    
    self.URLConnection = nil;
    self.URLResponse = nil;
    self.receivedData = nil;
}

#pragma mark - Token 
- (void)serverReceivedToken:(NSNotification *)aNotification {
    if (self.service.token) {
        [self.service.delegate service:self.service insertToken:self.service.token intoRequest:self];
    }
    [self send];

    // Stop observing
    [[NSNotificationCenter defaultCenter] removeObserver:self];;
}

- (void)serverFailedToReceiveToken:(NSNotification *)aNotification {
    NSError *error = [NSError errorWithDomain:KVServiceErrorDomain code:KVServiceErrorNoToken userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Could not get token from server.", NSLocalizedDescriptionKey, nil]];

    [self processResponse:nil receivedData:nil error:error];

    // Stop observing
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - NSURLConnection delegate methods
// Called when the HTTP socket gets a response.
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    self.URLResponse = response;
    [self.receivedData setLength:0];
}

// Called when the HTTP socket received data.
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)value {
    [self.receivedData appendData:value];
}

// Called when the HTTP request fails.
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self processResponse:nil receivedData:nil error:error];
    
#ifdef DEBUG
    NSLog(@"Connection failed: %@", error);
#endif
}

// Called when the connection has finished loading.
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
#ifdef DEBUG
    NSLog (@"Received response: %@", self.URLResponse);
#endif

    if (self.allowCaching) { // && ![response hasFault]) {
        NSCachedURLResponse *cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:self.URLResponse data:self.receivedData];
        [self.service.cache storeCachedResponse:cachedResponse forRequest:self.URLRequest];
        [cachedResponse release];
        
#ifdef DEBUG
        NSLog (@"Cached response");
#endif
    }
    
    [self processResponse:self.URLResponse receivedData:self.receivedData error:nil];
}

// Authentication
- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
    if ([[protectionSpace authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        return self.service.allowSelfSignedSSLCertificate;
    } else {
        return NO;
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust] &&
        self.service.allowSelfSignedSSLCertificate) {
        [[challenge sender] useCredential:[NSURLCredential credentialForTrust:[[challenge protectionSpace] serverTrust]] forAuthenticationChallenge:challenge];
    } else {
        [[challenge sender] cancelAuthenticationChallenge:challenge];
    }
}

@end
