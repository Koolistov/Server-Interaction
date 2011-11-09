//
//  KVService.m
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

#import "KVService.h"

#import "KVServiceRequest.h"
#import "Reachability.h"

NSString *const KVServiceDidReceiveTokenNotification = @"KVServiceDidReceiveTokenNotification";
NSString *const KVServiceFailedToReceiveTokenNotification = @"KVServiceFailedToReceiveTokenNotification";

NSString *const KVServiceErrorDomain = @"KVServiceErrorDomain";

@interface KVService ()

@property (nonatomic, copy, readwrite) NSString *token;
@property (nonatomic, retain) NSMutableArray *activeRequests;
@property (nonatomic, retain) KVServiceRequest *tokenRequest;

@end

@implementation KVService

@synthesize delegate=delegate_;
@synthesize token=token_;
@synthesize cache=cache_;
@synthesize timeoutInterval=timeoutInterval_;
@synthesize allowSelfSignedSSLCertificate=allowSelfSignedSSLCertificate_;
@synthesize preprocessHandler=preprocessHandler_;
@synthesize activeRequests=activeRequests_;
@synthesize tokenRequest=tokenRequest_;

+ (KVService *)defaultService  {
    static dispatch_once_t pred;
    static KVService *defaultService = nil;
    
    dispatch_once(&pred, ^{ defaultService = [[self alloc] init]; });
    return defaultService;
}

- (id)init {
    self = [super init];
    if (self) {
        self.activeRequests = [NSMutableArray array];
        self.timeoutInterval = 30.0;
    }
    return self;
}

- (void)dealloc {
    self.delegate = nil;
    self.token = nil;
    self.cache = nil;
    self.preprocessHandler = nil;
    self.activeRequests = nil;
    self.tokenRequest = nil;
    [super dealloc];
}

#pragma mark - Main
- (KVServiceRequest *)performRequestWithURL:(NSURL *)URL
                                 HTTPMethod:(NSString *)HTTPMethod 
                                   bodyData:(NSData *)bodyData
                              requiresToken:(BOOL)requiresToken
                               allowCaching:(BOOL)allowCaching 
                               forceRefresh:(BOOL)forceRefresh
                          completionHandler:(KVRequestCompletionBlock)completionHandler {
    // Check network access
    if ([[Reachability reachabilityForInternetConnection] currentReachabilityStatus] == NotReachable) {
        NSError *error = [NSError errorWithDomain:KVServiceErrorDomain code:KVServiceErrorNoInternetConnection userInfo:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"The internet connection appears to be offline. Please try again later.", @""), NSLocalizedDescriptionKey, nil]];
        completionHandler(nil, nil, error);
        return nil;
    }

    // Create request
    KVServiceRequest *request = [[[KVServiceRequest alloc] init] autorelease];
    request.service = self;
    request.HTTPMethod = HTTPMethod;
    request.URL = URL;
    request.bodyData = bodyData;
    request.allowCaching = allowCaching;
    request.forceRefresh = forceRefresh;
    request.completionHandler = completionHandler;
    
    // Insert token if needed
    if (requiresToken) {
        if (!self.token && !self.tokenRequest) {
            if ([self.delegate respondsToSelector:@selector(tokenRequestForService:)]) {
                KVServiceRequest *tokenRequest = [self.delegate tokenRequestForService:self];
                tokenRequest.allowCaching = NO;

                self.tokenRequest = tokenRequest;
                [self performRequest:tokenRequest];
            } else {
                NSAssert(NO, @"Token required, but delegate didn't implement relevant method");
            } 
        }
        
        if ([self.delegate respondsToSelector:@selector(service:insertToken:intoRequest:)]) {
            [self.delegate service:self insertToken:self.token intoRequest:request];
        } else {
            NSAssert(NO, @"Token required, but delegate didn't implement relevant method");
        }
    }
    
    return [self performRequest:request];
}

- (KVServiceRequest *)performRequest:(KVServiceRequest *)request {
    request.service = self;
    
    // Start request
    [request send];
    
    // Hold on to request whilst its active
    [self.activeRequests addObject:request];
    
    // Tell delegate
    if ([self.delegate respondsToSelector:@selector(service:didStartRequest:)]) {
        [self.delegate service:self didStartRequest:request];
    }
    
    return request;
}

#pragma mark - Service Request Service Protocol
- (void)request:(KVServiceRequest *)request receivedError:(NSError *)error {
    // Notify delegate
    if ([self.delegate respondsToSelector:@selector(service:didFinishRequest:)]) {
        [self.delegate service:self didFinishRequest:request successfully:NO];
    }
    
    // If token request, post failure notification
    if (request == self.tokenRequest) {
        [[NSNotificationCenter defaultCenter] postNotificationName:KVServiceFailedToReceiveTokenNotification object:self];
        self.tokenRequest = nil;
    }
    
    // Release request when done
    [self.activeRequests removeObject:request];
}

- (void)request:(KVServiceRequest *)request receivedResponse:(NSURLResponse *)response data:(NSData *)data {
    // Notify delegate
    if ([self.delegate respondsToSelector:@selector(service:didFinishRequest:successfully:)]) {
        [self.delegate service:self didFinishRequest:request successfully:YES];
    }
    
    if (request == self.tokenRequest) {
        if ([self.delegate respondsToSelector:@selector(service:extractAndValidateTokenFromResponse:data:)]) {
            self.token = [self.delegate service:self extractAndValidateTokenFromResponse:response data:data];
        } else {
            NSAssert(NO, @"Token required, but delegate didn't implement relevant method");
        }

        if (!self.token) {
            [[NSNotificationCenter defaultCenter] postNotificationName:KVServiceFailedToReceiveTokenNotification object:self];
        } else {
            [[NSNotificationCenter defaultCenter] postNotificationName:KVServiceDidReceiveTokenNotification object:self];
        }
        self.tokenRequest = nil;
    }
    
    // Release request when done
    [self.activeRequests removeObject:request];
}

@end
