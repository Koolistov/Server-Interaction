//
//  SampleService.m
//  Koolistov
//
//  Created by Johan Kool on 26/9/2011.
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

#import "SampleService.h"
#import <UIKit/UIKit.h>
#import "NSURL+PathParameters.h"

@interface SampleService ()

@property (nonatomic, assign) NSUInteger activeRequestsCount;

@end

@implementation SampleService

@synthesize activeRequestsCount=activeRequestsCount_;
@synthesize baseURL=baseURL_;

- (id)init {
    self = [super init];
    if (self) {
        self.delegate = self;
        
        // NSURLCache currently doesn't write to disk, use SDURLCache instead if you need that
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *diskCachePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"KVServiceCache"];
        NSURLCache *cache = [[[NSURLCache alloc] initWithMemoryCapacity:1 * 1024 * 1024 diskCapacity:10 * 1024 * 1024 diskPath:diskCachePath] autorelease];
        self.cache = cache;
        
        self.preprocessHandler = ^(NSURLResponse *response, NSData *data, NSError **error) {
            // Check wether server complains about invalid token
            if (YES) {
                *error = [NSError errorWithDomain:KVServiceErrorDomain code:KVServiceErrorExpiredToken userInfo:nil];
                return (id)nil;
            }
            return data;
        };
    }
    return self;
}

#pragma mark - Methods that map to specific actions on the server 
- (KVServiceRequest *)startSessionWithCompletionHandler:(KVRequestCompletionBlock)completionHandler {
    NSURL *URL = [self.baseURL URLByAppendingPathWithRelativePath:@"session"];
    return [self performRequestWithURL:URL HTTPMethod:@"POST" bodyData:nil requiresToken:NO allowCaching:NO forceRefresh:YES completionHandler:^(NSURLResponse *response, id data, NSError *error) {
        // Do something smart
        completionHandler(response, data, error);
    }];
}

- (KVServiceRequest *)fetchGuestbookEntriesOnPage:(NSUInteger)pageIndex completionHandler:(KVRequestCompletionBlock)completionHandler {
    NSURL *URL = [self.baseURL URLByAppendingPathWithRelativePath:@"entries"];
    URL = [URL URLByAppendingParameterName:@"page" value:[NSNumber numberWithUnsignedInteger:pageIndex]];
    return [self performRequestWithURL:URL HTTPMethod:@"GET" bodyData:nil requiresToken:YES allowCaching:YES forceRefresh:NO completionHandler:completionHandler];
}

- (KVServiceRequest *)postEntry:(NSString *)message completionHandler:(KVRequestCompletionBlock)completionHandler {
    return nil;
}

- (KVServiceRequest *)deleteEntryWithID:(NSUInteger)messageID completionHandler:(KVRequestCompletionBlock)completionHandler {
    NSURL *URL = [self.baseURL URLByAppendingPathWithRelativePath:[NSString stringWithFormat:@"entries/%d", messageID]];
    return [self performRequestWithURL:URL HTTPMethod:@"DELETE" bodyData:nil requiresToken:YES allowCaching:YES forceRefresh:NO completionHandler:completionHandler];
}

#pragma mark - Delegate methods
- (KVServiceRequest *)tokenRequestForService:(KVService *)service {
    NSURL *URL = [self.baseURL URLByAppendingPathWithRelativePath:@"session"];
    KVServiceRequest *tokenRequest = [[[KVServiceRequest alloc] init] autorelease];
    tokenRequest.URL = URL;
    return tokenRequest;
}

- (NSString *)service:(KVService *)service extractAndValidateTokenFromResponse:(NSURLResponse *)response data:(NSData *)data {
    return [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease]; 
}

- (void)service:(KVService *)service insertToken:(NSString *)token intoRequest:(KVServiceRequest *)request {
    NSURL *URL = [request.URL URLByAppendingParameterName:@"token" value:token];
    request.URL = URL;
}

// For demonstration purposes these are on the same class as the KVService subclass, but it's perfectly okay to have another class instance act as delegate
- (void)service:(KVService *)service didStartRequest:(KVServiceRequest *)request {
    // Show network acitivity
    self.activeRequestsCount++;
    [UIApplication sharedApplication].networkActivityIndicatorVisible = (self.activeRequestsCount > 0);
}

- (void)service:(KVService *)service didFinishRequest:(KVServiceRequest *)request successfully:(BOOL)successfully {
    // Hide network acitivity when all done
    self.activeRequestsCount--;
    [UIApplication sharedApplication].networkActivityIndicatorVisible = (self.activeRequestsCount > 0);
}

@end
