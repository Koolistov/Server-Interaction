//
//  KVService.h
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

#import <Foundation/Foundation.h>

@class KVService;
@class KVServiceRequest;

NSString * const KVServiceDidReceiveTokenNotification;
NSString * const KVServiceFailedToReceiveTokenNotification;

NSString * const KVServiceErrorDomain;

typedef enum {
    KVServiceErrorUnknown = 0,
    KVServiceErrorNoInternetConnection = 1,
    KVServiceErrorNoConnection,
    KVServiceErrorNoToken,
    KVServiceErrorExpiredToken,
    KVServiceErrorNoAuthentication
} KVServiceError;

typedef id (^KVRequestPreprocessBlock)(NSURLResponse *response, NSData *data, NSError **error);
typedef void (^KVRequestCompletionBlock)(NSURLResponse *response, id data, NSError *error);


@protocol KVServiceRequestServiceProtocol

- (void)request:(KVServiceRequest *)request receivedError:(NSError *)error;
- (void)request:(KVServiceRequest *)request receivedResponse:(NSURLResponse *)response data:(NSData *)data;

@end

@protocol KVServiceDelegate <NSObject>

@optional

// For services that need a token
- (KVServiceRequest *)tokenRequestForService:(KVService *)service;
// Delegate is expected to return nil if the token is invalid
- (NSString *)service:(KVService *)service extractAndValidateTokenFromResponse:(NSURLResponse *)response data:(NSData *)data;
- (void)service:(KVService *)service insertToken:(NSString *)token intoRequest:(KVServiceRequest *)request;

// These calls are guaranteed to be balanced. The delegate may use them to show the network activity indicator.
- (void)service:(KVService *)service didStartRequest:(KVServiceRequest *)request;
- (void)service:(KVService *)service didFinishRequest:(KVServiceRequest *)request successfully:(BOOL)successfully;

@end

@interface KVService : NSObject <KVServiceRequestServiceProtocol> 

+ (id)defaultService;

@property (nonatomic, assign) id <KVServiceDelegate> delegate;
@property (nonatomic, copy, readonly) NSString *token;

@property (nonatomic, retain) NSURLCache *cache;
@property (nonatomic, assign) NSTimeInterval timeoutInterval;
@property (nonatomic, assign) BOOL allowSelfSignedSSLCertificate;
@property (nonatomic, copy) KVRequestPreprocessBlock preprocessHandler;

- (KVServiceRequest *)performRequestWithURL:(NSURL *)URL
                                 HTTPMethod:(NSString *)HTTPMethod 
                                   bodyData:(NSData *)bodyData
                              requiresToken:(BOOL)requiresToken
                               allowCaching:(BOOL)allowCaching 
                               forceRefresh:(BOOL)forceRefresh
                          completionHandler:(KVRequestCompletionBlock)completionHandler;

- (KVServiceRequest *)performRequest:(KVServiceRequest *)request;

@end
