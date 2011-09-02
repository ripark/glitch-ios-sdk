/*-
 *  Glitch iOS SDK
 *  
 *  Copyright 2011 Tiny Speck, Inc.
 *  Created by Brady Archambo.
 *
 *  http://www.glitch.com
 *  http://www.tinyspeck.com
 */


#import "GCRequest.h"
#import "SBJson.h"


static NSString * kGCUserAgent = @"glitch-ios-sdk";
static NSString * kGCAPIUrlPrefix = @"http://api.glitch.com/simple/";
static const NSTimeInterval kGCTimeout = 120;


@implementation GCRequest


@synthesize url = _url,
                path = _path,
                params = _params,
                requestDelegate = _requestDelegate,
                connection = _connection,
                receivedResponseData = _receivedResponseData;


#pragma mark - Initialization

// Do not call this directly - call Glitch, which will call this lower-level method
//
// Get a GCRequest object with a specificed method path,
// delegate to call when request/response events occur,
// and any parameters passed in for the request.
+ (GCRequest *)requestWithPath:(NSString*)path
                       delegate:(id<GCRequestDelegate>)delegate
                       params:(NSDictionary*)params
{
    GCRequest * request = [[[GCRequest alloc] init] autorelease];
    request.path = path;
    request.url = [NSString stringWithFormat:@"%@%@",kGCAPIUrlPrefix,path];
    request.params = params;
    request.requestDelegate = delegate;
    
    return request;
}


#pragma mark - Interacting with the API

// Once you have the request object, call this to actually perform the asynchronous request
// Creates and starts a connection with the Glitch API
- (void)connect
{
    // Serialize URL with parameters if we have them, otherwise, use our base URL
    NSString * url = _params != nil ? [GCRequest serializeURL:_url params:_params] : _url;
    
    // Create the request that we're going to send
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:kGCTimeout];
    [request setHTTPMethod:@"GET"];
    [request setValue:kGCUserAgent forHTTPHeaderField:@"User-Agent"]; // Set our user agent so the server knows that we're calling from the iOS SDK
    
    // Initialize and start the connection
    _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:YES];
}


// Parse the data from the server into an object using JSON parser
- (id)parseResponse:(NSData *)data
{ 
    // Transform the data into a string
    NSString * responseString = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    
    // If the data transformation succeeds, parse the JSON into an object
    if (responseString)
    {
        SBJsonParser * jsonParser = [[SBJsonParser new] autorelease];
        return [jsonParser objectWithString:responseString];
    }
    
    return nil;
}


#pragma mark - Utility

+ (NSString *)urlEncodeString:(NSString*)string {
	return (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,
                                                               (CFStringRef)string,
                                                               NULL,
                                                               (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ",
                                                               CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
}


+ (NSString*)serializeURL:(NSString*)url params:(NSDictionary*)params
{
    NSString * preparedURL = [url stringByAppendingString:@"?"];
    
    return [preparedURL stringByAppendingString:[GCRequest serializeParams:params]];
}


+ (NSString*)serializeParams:(NSDictionary*)params
{
    NSMutableArray * arguments = [NSMutableArray arrayWithCapacity:[params count]];
    
    for (NSString * key in params)
    {
        [arguments addObject:[NSString stringWithFormat:@"%@=%@",
                              [GCRequest urlEncodeString:key],
                              [GCRequest urlEncodeString:[[params objectForKey:key] description]]]];
    }
    
    return [arguments componentsJoinedByString:@"&"];
}


+ (NSDictionary*)deserializeParams:(NSString*)fragment
{
    NSArray * pairs = [fragment componentsSeparatedByString:@"&"];
	
    NSMutableDictionary * params = [[[NSMutableDictionary alloc] init] autorelease];
	
    for (NSString * pair in pairs) {
		NSArray * keyValue = [pair componentsSeparatedByString:@"="];
		NSString * value = [[keyValue objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
		[params setObject:value forKey:[keyValue objectAtIndex:0]];
	}
    
    return params;
}


#pragma mark - NSURL Delegate Stuffs

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [_receivedResponseData release];
	_receivedResponseData = [[NSMutableData alloc] init];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	[_receivedResponseData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    id result = [self parseResponse:_receivedResponseData];
    
    if (result)
    {
        if ([_requestDelegate respondsToSelector:@selector(requestFinished:withResult:)])
        {
            [_requestDelegate requestFinished:self withResult:result];
        }
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    if ([_requestDelegate respondsToSelector:@selector(requestFailed:withError:)])
    {
        [_requestDelegate requestFailed:self withError:error];
    }
    
	[_connection release], _connection = nil;
	[_receivedResponseData release], _receivedResponseData = nil;
}


@end