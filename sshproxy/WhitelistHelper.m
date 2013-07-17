//
//  WhitelistHelper.m
//  sshproxy
//
//  Created by Brant Young on 7/16/13.
//  Copyright (c) 2013 Codinn Studio. All rights reserved.
//

#import "WhitelistHelper.h"
#import "NSString+SSToolkitAdditions.h"

@implementation WhitelistHelper

+ (void)setProxyMode:(NSInteger)index
{
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    
    [prefs setInteger:index forKey:@"proxy_mode"];
    [prefs synchronize];
}

+ (BOOL)isHostShouldProxy:(NSString *)host
{
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    
    NSInteger proxyMode = [prefs integerForKey:@"proxy_mode"];
    
    if (proxyMode==OW_PROXY_MODE_ALLSITES) {
        return YES;
    }
    
    if (proxyMode==OW_PROXY_MODE_DIRECT) {
        return NO;
    }
    
    NSArray *whitelist = [prefs objectForKey:@"whitelist"];
    
    for ( NSDictionary *site in whitelist ) {
        BOOL enabled = [site[@"enabled"] boolValue];
        
        if (!enabled) {
            continue;
        }
        
        NSString *address = site[@"address"];
        
        if ( NSOrderedSame == [host caseInsensitiveCompare:address] ) {
            return YES;
        }
        
        BOOL subdomains = [site[@"subdomains"] boolValue];
        
        if ( subdomains && [host.lowercaseString containsString:[NSString stringWithFormat:@".%@", address]] ) {
            return YES;
        }
    }
    
    return NO;
}

@end