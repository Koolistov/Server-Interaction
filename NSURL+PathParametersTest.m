//
//  NSURL+PathParametersTest.m
//
//  Created by Johan Kool on 27/9/2011.
//  Copyright 2011 Koolistov Pte. Ltd. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification, are 
//  permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above copyright notice, this list of 
//    conditions and the following disclaimer.
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

#import "NSURL+PathParametersTest.h"

@implementation NSURL_PathParametersTest

- (void)testPath {
    NSURL *URL = nil;
    
    URL = [NSURL URLWithString:@"http://www.koolistov.net/"];
    URL = [URL URLByReplacingPathWithPath:@"/action"];
    STAssertEqualObjects(URL, [NSURL URLWithString:@"http://www.koolistov.net/action"], @"Expected URLs to match");
   
    URL = [NSURL URLWithString:@"http://www.koolistov.net"];
    URL = [URL URLByReplacingPathWithPath:@"/action"];
    STAssertEqualObjects(URL, [NSURL URLWithString:@"http://www.koolistov.net/action"], @"Expected URLs to match");

    URL = [NSURL URLWithString:@"http://www.koolistov.net/?key=123"];
    URL = [URL URLByReplacingPathWithPath:@"/action"];
    STAssertEqualObjects(URL, [NSURL URLWithString:@"http://www.koolistov.net/action?key=123"], @"Expected URLs to match");

    URL = [NSURL URLWithString:@"http://www.koolistov.net/#anchor1"];
    URL = [URL URLByReplacingPathWithPath:@"/action"];
    STAssertEqualObjects(URL, [NSURL URLWithString:@"http://www.koolistov.net/action#anchor1"], @"Expected URLs to match");
    
    URL = [NSURL URLWithString:@"http://www.koolistov.net/#anchor1"];
    URL = [URL URLByReplacingPathWithPath:@"/action/"];
    STAssertEqualObjects(URL, [NSURL URLWithString:@"http://www.koolistov.net/action/#anchor1"], @"Expected URLs to match");

    URL = [NSURL URLWithString:@"http://www.koolistov.net/oldaction/?key=123#anchor1"];
    URL = [URL URLByReplacingPathWithPath:@"/action/"];
    STAssertEqualObjects(URL, [NSURL URLWithString:@"http://www.koolistov.net/action/?key=123#anchor1"], @"Expected URLs to match");

    URL = [NSURL URLWithString:@"http://www.koolistov.net/"];
    URL = [URL URLByAppendingPathWithRelativePath:@"action"];
    STAssertEqualObjects(URL, [NSURL URLWithString:@"http://www.koolistov.net/action"], @"Expected URLs to match");

    URL = [NSURL URLWithString:@"http://www.koolistov.net/test/"];
    URL = [URL URLByAppendingPathWithRelativePath:@"../action"];
    STAssertEqualObjects(URL, [NSURL URLWithString:@"http://www.koolistov.net/action"], @"Expected URLs to match");

    URL = [NSURL URLWithString:@"http://www.koolistov.net/test"];
    URL = [URL URLByAppendingPathWithRelativePath:@"../action"];
    STAssertEqualObjects(URL, [NSURL URLWithString:@"http://www.koolistov.net/action"], @"Expected URLs to match");

    URL = [NSURL URLWithString:@"http://www.koolistov.net/test/"];
    URL = [URL URLByAppendingPathWithRelativePath:@"action1/action2"];
    STAssertEqualObjects(URL, [NSURL URLWithString:@"http://www.koolistov.net/test/action1/action2"], @"Expected URLs to match");
    
    URL = [NSURL URLWithString:@"http://www.koolistov.net/test/"];
    URL = [URL URLByAppendingPathWithRelativePath:@"/action1/action2/"];
    STAssertEqualObjects(URL, [NSURL URLWithString:@"http://www.koolistov.net/test/action1/action2/"], @"Expected URLs to match");
}


- (void)testParameters {
    NSDictionary *parameters = nil;
    NSURL *URL = nil;
     
    parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"!@#$%^&* ()'\"", @"key1", nil];
    URL = [NSURL URLWithString:@"http://www.koolistov.net/"];
    URL = [URL URLByAppendingParameters:parameters];
    STAssertEqualObjects(URL, [NSURL URLWithString:@"http://www.koolistov.net/?key1=%21%40%23%24%25%5E%26%2A%20%28%29%27%22"], @"Expected URLs to match");
    
    parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"abc", @"key1", @"456", @"key2", nil];
    URL = [NSURL URLWithString:@"http://www.koolistov.net/"];
    URL = [URL URLByAppendingParameters:parameters];
    STAssertEqualObjects(URL, [NSURL URLWithString:@"http://www.koolistov.net/?key1=abc&key2=456"], @"Expected URLs to match");
    
    parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"abc", @"key1", @"456", @"key2", nil];
    URL = [NSURL URLWithString:@"http://www.koolistov.net"];
    URL = [URL URLByAppendingParameters:parameters];
    STAssertEqualObjects(URL, [NSURL URLWithString:@"http://www.koolistov.net?key1=abc&key2=456"], @"Expected URLs to match");

    parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"abc", @"key1", @"456", @"key2", nil];
    URL = [NSURL URLWithString:@"http://johan@www.koolistov.net/?"];
    URL = [URL URLByAppendingParameters:parameters];
    STAssertEqualObjects(URL, [NSURL URLWithString:@"http://johan@www.koolistov.net/?key1=abc&key2=456"], @"Expected URLs to match");

    parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"abc", @"key1", @"456", @"key2", nil];
    URL = [NSURL URLWithString:@"http://www.koolistov.net/#"];
    URL = [URL URLByAppendingParameters:parameters];
    STAssertEqualObjects(URL, [NSURL URLWithString:@"http://www.koolistov.net/?key1=abc&key2=456#"], @"Expected URLs to match");

    parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"abc", @"key1", @"456", @"key2", nil];
    URL = [NSURL URLWithString:@"http://www.koolistov.net/?key1=123#anchor1"];
    URL = [URL URLByAppendingParameters:parameters];
    STAssertEqualObjects(URL, [NSURL URLWithString:@"http://www.koolistov.net/?key1=123&key1=abc&key2=456#anchor1"], @"Expected URLs to match");
    
    parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"abc", @"key1", @"456", @"key2", nil];
    URL = [NSURL URLWithString:@"http://www.koolistov.net/#anchor1"];
    URL = [URL URLByAppendingParameters:parameters];
    STAssertEqualObjects(URL, [NSURL URLWithString:@"http://www.koolistov.net/?key1=abc&key2=456#anchor1"], @"Expected URLs to match");    
    
    URL = [NSURL URLWithString:@"http://www.koolistov.net/"];
    URL = [URL URLByAppendingParameterName:@"key1" value:@"abc"];
    STAssertEqualObjects(URL, [NSURL URLWithString:@"http://www.koolistov.net/?key1=abc"], @"Expected URLs to match");    

    parameters = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"key1", [NSNumber numberWithInteger:456], @"key2", nil];
    URL = [NSURL URLWithString:@"http://www.koolistov.net/#anchor1"];
    URL = [URL URLByAppendingParameters:parameters];
    STAssertEqualObjects(URL, [NSURL URLWithString:@"http://www.koolistov.net/?key1=1&key2=456#anchor1"], @"Expected URLs to match");    

    parameters = [NSDictionary dictionaryWithObjectsAndKeys:[NSDate dateWithTimeIntervalSinceReferenceDate:0], @"key1", nil];
    URL = [NSURL URLWithString:@"http://www.koolistov.net/#anchor1"];
    URL = [URL URLByAppendingParameters:parameters];
    STAssertEqualObjects(URL, [NSURL URLWithString:@"http://www.koolistov.net/?key1=2001-01-01%2000%3A00%3A00%20%2B0000#anchor1"], @"Expected URLs to match");    

}

@end
