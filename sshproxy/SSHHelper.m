//
//  SSHHelper.m
//  sshproxy
//
//  Created by Brant Young on 15/5/13.
//  Copyright (c) 2013 Charm Studio. All rights reserved.
//

#import "SSHHelper.h"
#import "EMKeychain.h"

@implementation SSHHelper


+ (NSMutableArray*) getConnectArgs
{
    NSString* userHome = NSHomeDirectory();
    NSString* knownHostFile = @"/dev/null";
//    NSString* knownHostFile= [userHome stringByAppendingPathComponent:@".sshproxy_known_hosts"];
    NSString* identityFile= [userHome stringByAppendingPathComponent:@".sshproxy_identity"];
    //    NSString* configFile= [userHome stringByAppendingPathComponent:@".sshproxy_config"];
    
    NSMutableArray *arguments = [NSMutableArray arrayWithObjects:
                                 [NSString stringWithFormat:@"-oUserKnownHostsFile=\"%@\"", knownHostFile],
                                 [NSString stringWithFormat:@"-oGlobalKnownHostsFile=\"%@\"", knownHostFile],
                                 [NSString stringWithFormat:@"-oIdentityFile=\"%@\"", identityFile],
                                 // TODO:
                                 //                        [NSString stringWithFormat:@"-F \"%@\"", configFile],
                                 @"-oIdentitiesOnly=yes",
//                                 @"-oPreferredAuthentications=publickey",
                                 @"-oPubkeyAuthentication=yes",
                                 @"-oAskPassGUI=no", // TODO:
                                 @"-T", @"-a",
                                 @"-oConnectTimeout=8", @"-oConnectionAttempts=1",
                                 @"-oServerAliveInterval=8", @"-oServerAliveCountMax=1",
                                 @"-oStrictHostKeyChecking=no", @"-oExitOnForwardFailure=yes",
                                 @"-oNumberOfPasswordPrompts=1", @"-oLogLevel=DEBUG",
                                 nil];
    
    return arguments;
}

// for ProxyCommand Env
+ (NSDictionary*) getProxyCommandEnv:(NSDictionary*) server
{
    NSMutableDictionary* env = [NSMutableDictionary dictionary];
    
    BOOL proxyCommand = [(NSNumber *)[server valueForKey:@"proxy_command"] boolValue];
    BOOL proxyCommandAuth = [(NSNumber *)[server valueForKey:@"proxy_command_auth"] boolValue];
    
    NSString* proxyCommandUsername = (NSString *)[server valueForKey:@"proxy_command_username"];
    NSString* proxyCommandPassword = (NSString *)[server valueForKey:@"proxy_command_password"];
    
    if (proxyCommand && proxyCommandAuth) {
        if (proxyCommandUsername) {
            [env setValue:@"YES" forKey:@"HTTP_PROXY_FORCE_AUTH"];
            [env setValue:proxyCommandUsername forKey:@"CONNECT_USER"];
            if (proxyCommandPassword) {
                [env setValue:proxyCommandPassword forKey:@"CONNECT_PASSWORD"];
            }
        }
    }
    
    return env;
}

// for ProxyCommand
+ (NSString*)getProxyCommandStr:(NSDictionary*) server
{
    NSString *connectPath = [NSBundle pathForResource:@"connect" ofType:@""
                                          inDirectory:[[NSBundle mainBundle] bundlePath]];
    
    BOOL proxyCommand = [(NSNumber *)[server valueForKey:@"proxy_command"] boolValue];
    int proxyCommandType = [(NSNumber *)[server valueForKey:@"proxy_command_type"] intValue];
    NSString* proxyCommandHost = (NSString *)[server valueForKey:@"proxy_command_host"];
    int proxyCommandPort = [(NSNumber *)[server valueForKey:@"proxy_command_port"] intValue];
    
    NSString* proxyCommandStr = nil;
    if (proxyCommand){
        if (proxyCommandHost) {
            NSString* proxyType = @"-S";
            
            switch (proxyCommandType) {
                case 0:
                    proxyType = @"-5 -S";
                    break;
                case 1:
                    proxyType = @"-4 -S";
                    break;
                case 2:
                    proxyType = @"-H";
                    break;
            }
            
            if (proxyCommandPort<=0 || proxyCommandPort>65535) {
                proxyCommandPort = 1080;
            }
            
            proxyCommandStr = [NSString stringWithFormat:@"-oProxyCommand=\"%@\" -d -w 8 %@ %@:%d %@", connectPath, proxyType, proxyCommandHost, proxyCommandPort, @"%h %p"];
        }
    }
    
    return proxyCommandStr;
}

+ (NSArray *)getServers
{
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs synchronize];
    
    return [[NSUserDefaults standardUserDefaults] arrayForKey:@"servers"];
}

+ (void)setServers:(NSMutableArray *) servers
{
    [[NSUserDefaults standardUserDefaults] arrayForKey:@"servers"];
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs synchronize];
}

+ (NSInteger) getActivatedServerIndex
{
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs synchronize];
    
    NSArray* servers = [prefs arrayForKey:@"servers"];
    NSInteger index = [prefs integerForKey:@"activated_server"];
    
    if (index<0 || index>=servers.count) {
        index = 0;
    }
    
    return index;
}

+ (NSDictionary*) getActivatedServer
{
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs synchronize];
    
    NSArray* servers = [prefs arrayForKey:@"servers"];
    
    if ( [servers count]<=0 ){
        return nil;
    }
    
    NSInteger index = [SSHHelper getActivatedServerIndex];
    return [servers objectAtIndex:index];
}

+ (void) setActivatedServer:(int) index
{
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs synchronize];
    
    [prefs setInteger:index forKey:@"activated_server"];
    [prefs synchronize];
}

// code that upgrade user preferences from 13.04 to 13.05
+ (void)upgrade1:(NSArrayController*) serverArrayController
{
    // fetch preferences that need upgrade
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    
    NSString* remoteHost = [prefs stringForKey:@"remote_host"];
    if (!remoteHost) {
        // do not need upgrade
        return;
    }
    
    NSString* loginName = [prefs stringForKey:@"login_name"];
    if (!loginName) {
        loginName = @"";
    }
    
    int remotePort = (int)[prefs integerForKey:@"remote_port"];
    if (remotePort<=0 || remotePort>65535) {
        remotePort = 22;
    }
    
    BOOL enableCompression = [prefs boolForKey:@"enable_compression"];
    BOOL shareSocks = [prefs boolForKey:@"share_socks"];
    
    BOOL proxyCommand = [prefs boolForKey:@"proxy_command"];
    int proxyCommandType = (int)[prefs integerForKey:@"proxy_command_type"];
    NSString* proxyCommandHost = (NSString*)[prefs stringForKey:@"proxy_command_host"];
    int proxyCommandPort = (int)[prefs integerForKey:@"proxy_command_port"];
    
    if (proxyCommandPort<=0 || proxyCommandPort>65535) {
        proxyCommandPort = 1080;
    }
    
    BOOL proxyCommandAuth = [prefs boolForKey:@"proxy_command_auth"];
    NSString* proxyCommandUsername = [prefs stringForKey:@"proxy_command_username"];
    NSString* proxyCommandPassword = [prefs stringForKey:@"proxy_command_password"];
    
    // upgrade
    
    NSMutableDictionary* server = [[NSMutableDictionary alloc] init];
    
    [server setObject:remoteHost forKey:@"remote_host"];
    [server setObject:[NSNumber numberWithInt:remotePort] forKey:@"remote_port"];
    [server setObject:loginName forKey:@"login_name"];
    [server setObject:[NSNumber numberWithBool:enableCompression] forKey:@"enable_compression"];
    [server setObject:[NSNumber numberWithBool:shareSocks] forKey:@"share_socks"];
    
    [server setObject:[NSNumber numberWithBool:proxyCommand] forKey:@"proxy_command"];
    [server setObject:[NSNumber numberWithBool:proxyCommandType] forKey:@"proxy_command_type"];
    if (proxyCommandHost) [server setObject:proxyCommandHost forKey:@"proxy_command_host"];
    [server setObject:[NSNumber numberWithInt:proxyCommandPort] forKey:@"proxy_command_port"];
    
    
    [server setObject:[NSNumber numberWithBool:proxyCommandAuth] forKey:@"proxy_command_auth"];
    if (proxyCommandUsername) [server setObject:proxyCommandUsername forKey:@"proxy_command_username"];
    if (proxyCommandPassword) [server setObject:proxyCommandPassword forKey:@"proxy_command_password"];
    
    [serverArrayController addObject:server];
    
    // remove old preferences
    
    [prefs removeObjectForKey:@"remote_host"];
    [prefs removeObjectForKey:@"remote_port"];
    [prefs removeObjectForKey:@"login_name"];
    
    [prefs removeObjectForKey:@"enable_compression"];
    [prefs removeObjectForKey:@"share_socks"];
    
    [prefs removeObjectForKey:@"proxy_command"];
    [prefs removeObjectForKey:@"proxy_command_type"];
    [prefs removeObjectForKey:@"proxy_command_host"];
    [prefs removeObjectForKey:@"proxy_command_port"];
    
    [prefs removeObjectForKey:@"proxy_command_auth"];
    [prefs removeObjectForKey:@"proxy_command_username"];
    [prefs removeObjectForKey:@"proxy_command_password"];
    
    [prefs synchronize];
}


#pragma mark -
#pragma mark Password Helper

//! Simply looks for the keychain entry corresponding to a username and hostname and returns it. Returns nil if the password is not found
+ (NSString *)passwordForHost:(NSString *)hostName port:(int) hostPort user:(NSString *) userName
{
	if ( hostName == nil || userName == nil ){
		return nil;
	}
	
	EMInternetKeychainItem *keychainItem = [EMInternetKeychainItem internetKeychainItemForServer:hostName withUsername:userName path:nil port:hostPort protocol:kSecProtocolTypeSSH];
    
    return keychainItem ? keychainItem.password : @"";
}

+ (NSString *)passwordForServer:(NSDictionary *)server
{
    NSString* remoteHost = [self hostFromServer:server];
    NSString* loginName = [self userFromServer:server];
    int remotePort = [self portFromServer:server];
    
    return [SSHHelper passwordForHost:remoteHost port:remotePort user:loginName];
}


/*! Set the password into the keychain for a specific user and host. If the username/hostname combo already has an entry in the keychain then change it. If not then add a new entry */
+ (BOOL) setPassword:(NSString*)newPassword forHost:(NSString*)hostName port:(int) hostPort user:(NSString*) userName
{
	if ( hostName == nil || userName == nil ) {
		return NO;
	}
	
	// Look for a password in the keychain
    EMInternetKeychainItem *keychainItem = [EMInternetKeychainItem internetKeychainItemForServer:hostName withUsername:userName path:nil port:hostPort protocol:kSecProtocolTypeSSH];
    
    if (!keychainItem) {
        keychainItem = [EMInternetKeychainItem addInternetKeychainItemForServer:hostName withUsername:userName password:newPassword path:nil port:hostPort protocol:kSecProtocolTypeSSH];
        return NO;
    }
    
    keychainItem.password = newPassword;
    return YES;
}
+ (BOOL) setPassword:(NSString *)newPassword forServer:(NSDictionary *)server
{
    NSString* remoteHost = [self hostFromServer:server];
    NSString* loginName = [self userFromServer:server];
    int remotePort = [self portFromServer:server];
    
    return [self setPassword:newPassword forHost:remoteHost port:remotePort user:loginName];
}

+ (BOOL) deletePasswordForHost:(NSString*)hostName port:(int) hostPort user:(NSString*) userName
{
	if ( hostName == nil || userName == nil ) {
		return NO;
	}
    
	// Look for a password in the keychain
    EMInternetKeychainItem *keychainItem = [EMInternetKeychainItem internetKeychainItemForServer:hostName withUsername:userName path:nil port:hostPort protocol:kSecProtocolTypeSSH];
    
    if (!keychainItem) {
        return NO;
    }
    
    [EMInternetKeychainItem removeKeychainItem:keychainItem];
    return YES;
}

#pragma mark Local Settings

+ (NSInteger)getLocalPort
{
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    NSInteger localPort = [prefs integerForKey:@"local_port"];
    [prefs synchronize];
    
    if (localPort<=0 || localPort>65535) {
        localPort = 7070;
    }
    
    return localPort;
}

#pragma mark Getters for server parameters

+ (NSString *)hostFromServer:(NSDictionary *)server
{
    NSString* remoteHost = (NSString *)[server valueForKey:@"remote_host"];
    
    if (!remoteHost) {
        remoteHost = @"";
    }
    
    return remoteHost;
}

+ (int)portFromServer:(NSDictionary *)server
{
    int remotePort = [(NSNumber*)[server valueForKey:@"remote_port"] intValue];
    
    if (remotePort<=0 || remotePort>65535) {
        remotePort = 22;
    }
    
    return remotePort;
}

+ (NSString *)userFromServer:(NSDictionary *)server
{
    NSString* loginName = (NSString *)[server valueForKey:@"login_name"];
    
    if (!loginName) {
        loginName = @"";
    }
    
    return loginName;
}

+ (NSString *)privatekeyFromServer:(NSDictionary *)server
{
    NSString* privatekey = (NSString *)[server valueForKey:@"privatekey_path"];
    
    if (!privatekey) {
        privatekey = @"";
    }
    
    return privatekey;
}


+ (BOOL)isEnableCompress:(NSDictionary *)server
{
    return [(NSNumber*)[server valueForKey:@"enable_compression"] boolValue];
}
+ (BOOL)isShareSOCKS:(NSDictionary *)server
{
    return [(NSNumber*)[server valueForKey:@"share_socks"] boolValue];
}

#pragma mark setters

+ (NSDictionary *)setPrivatekey:(NSString *)path ForServer:(NSDictionary *)server
{
    [server setValue:path forKey:@"privatekey_path"];
    return server;
}

#pragma mark Prompt Password

+ (NSArray *)promptPasswordForServer:(NSDictionary *)server
{
    NSString* remoteHost = [self hostFromServer:server];
    int remotePort = [self portFromServer:server];
    NSString* loginUser = [self userFromServer:server];
    
	CFUserNotificationRef passwordDialog;
	SInt32 error;
	CFOptionFlags responseFlags;
	int button;
	CFStringRef passwordRef;
    
	NSMutableArray *returnArray = [NSMutableArray arrayWithObjects:@"PasswordString",[NSNumber numberWithInt:0],[NSNumber numberWithInt:1],nil];
    
    NSString* hostString = [NSString stringWithFormat:@"%@:%d", remoteHost, remotePort];
    
	NSString *passwordMessageString = [NSString stringWithFormat:@"Enter the password for user “%@”.", loginUser];
    
    NSString* headerString = [NSString stringWithFormat:@"SSH Proxy connecting to the SSH server “%@”.", hostString];
    
    NSURL *iconURL = [[NSBundle mainBundle] URLForResource:@"logo" withExtension:@"icns" subdirectory:@""];
    
	NSDictionary *panelDict = [NSDictionary dictionaryWithObjectsAndKeys:
                               iconURL, kCFUserNotificationIconURLKey,
                               headerString,kCFUserNotificationAlertHeaderKey,
                               passwordMessageString,kCFUserNotificationAlertMessageKey,
							   @"",kCFUserNotificationTextFieldTitlesKey,
							   @"Cancel",kCFUserNotificationAlternateButtonTitleKey,
                               @"Remember this password in my keychain",kCFUserNotificationCheckBoxTitlesKey,
							   nil];
    
	passwordDialog = CFUserNotificationCreate(kCFAllocatorDefault,
											  0,
											  kCFUserNotificationPlainAlertLevel
											  | CFUserNotificationSecureTextField(0)
                                              | CFUserNotificationCheckBoxChecked(0),
											  &error,
											  (__bridge CFDictionaryRef)panelDict);
    
    
	if (error){
		// There was an error creating the password dialog
		CFRelease(passwordDialog);
        [returnArray replaceObjectAtIndex:1 withObject:@(error)];
		return returnArray;
	}
    
	error = CFUserNotificationReceiveResponse(passwordDialog,
											  0,
											  &responseFlags);
    
	if (error){
		CFRelease(passwordDialog);
        [returnArray replaceObjectAtIndex:1 withObject:@(error)];
		return returnArray;
	}
    
    
	button = responseFlags & 0x3;
	if (button == kCFUserNotificationAlternateResponse) {
		CFRelease(passwordDialog);
        [returnArray replaceObjectAtIndex:1 withObject:@1];
		return returnArray;
	}
    
	if ( responseFlags & CFUserNotificationCheckBoxChecked(0) ) {
        [returnArray replaceObjectAtIndex:2 withObject:@0];
	}
	passwordRef = CFUserNotificationGetResponseValue(passwordDialog,
													 kCFUserNotificationTextFieldValuesKey,
													 0);
    
    
    [returnArray replaceObjectAtIndex:0 withObject:(__bridge NSString*)passwordRef];
	CFRelease(passwordDialog); // Note that this will release the passwordRef as well
	return returnArray;	
}

@end

