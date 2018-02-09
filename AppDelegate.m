//
//  AppDelegate.m
//  TCPIP测试
//
//  Created by Dongyuan Li on 2017/2/15.
//  Copyright © 2017年 Dongyuan Li. All rights reserved.
//

#import "AppDelegate.h"

#import "NSData+Hex.h"

#import <sys/socket.h>
#import <netinet/in.h>
#import <sys/types.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <net/if.h>
#import "netdb.h"

#import <stdbool.h>        // true/false
#import <stdint.h>         // UINT8_MAX
#import <stdio.h>          // fprintf
#import <stdlib.h>         // EXIT_SUCCESS
#import <string.h>         // strerror()

#import <errno.h>          // errno
#import <fcntl.h>          // fcntl()
#import <mach/vm_param.h>  // PAGE_SIZE
#import <signal.h>         // sigaction()
#import <sys/uio.h>        // iovec
#import <syslog.h>         // syslog() and friends
#import <unistd.h>         // close()

#import <netinet6/in6.h>   // struct sockaddr_in6


// --------------------------------------------------
// Message protocol

// A message is length + data. The length is a single byte.
// The first message sent by a user has a max length of 8 and sets the user's name.

#define MAX(x, y) (((x) > (y)) ? (x) : (y))
#define MAX_MESSAGE_SIZE  (UINT8_MAX)
#define READ_BUFFER_SIZE  (PAGE_SIZE)

// Paranoia check that the read buffer is large enough to hold a full message.
typedef uint8_t READ_BUFFER_SIZE_not_less_than_MAX_MESSAGE_SIZE
[!(READ_BUFFER_SIZE < MAX_MESSAGE_SIZE) ? 0 : -1];

// There is one of these for each connected user
typedef struct ChatterUser_ {
    int      fd;       // zero fd == no user
    char     name[9];  // 8 character name plus trailing zero byte
    bool     gotName;  // have we gotten the username packet?
    
    /* incoming data workspace */
    ssize_t  bytesRead;
    char     buffer[READ_BUFFER_SIZE];
} ChatterUser;

#define MAX_USERS 50
static ChatterUser s_Users[MAX_USERS];



#define SERVER_PORT 9000

static const int kAcceptQueueSizeHint = 8;

@interface AppDelegate (){
    NSData *addressClient;
    NSString *ipFromClient;
}

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate
@synthesize window;
@synthesize tabView;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
//    [[self tabView] setDelegate:self];
//    [self.tabView setMenu:[[NSMenu alloc] initWithTitle:@"Test"]];
//    [self.tabView setFrame:NSMakeRect(100, 100, 100, 100)];
//    [self.window.contentView addSubview: self.tabView];
    localIPAddr = [self localIPAddress];
    if (!localIPAddr) {
        localIPAddr = @"空 - 没有找到！";
    }else{
        [NSThread detachNewThreadSelector:@selector(tcpServerMulti) toTarget:self withObject:nil];
        [startServer setTitle:@"停止"];
    }
    [localIPAddress setStringValue:[NSString stringWithFormat:@"本地IP：%@ - 用户名: %@", localIPAddr, NSUserName()]];
    [serverAddressInput setStringValue:localIPAddr];
    [serverAddressInputUDP setStringValue:localIPAddr];
    sendClient.enabled = NO;
    stopUDP.enabled = NO;
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem {
    
    NSViewController *aController = [[NSViewController alloc] init];
                                 //   initWithNibName: @"MyView" bundle: [NSBundle mainBundle]];
    [tabViewItem setView: [aController view]];
    
}

- (IBAction)startUDPServer:(id)sender{
    if ([startServerUDP.title isEqualToString:@"停止"]) {
        return;
    }
  //  flagUDP = 0;
    socketServerUDP = socket(AF_INET, SOCK_DGRAM,0);
    if (socketServerUDP == -1) {
 //       flagUDP |= kCreateSocketError;
        return;
    }
    //flagUDP |= kDidCreateSockets;
    
    //self.delegate = d;
    
//    portNumber = portNumberGiven;

    //确定服务器要监控的服务器端口
    NSInteger server_port = [portMonitorServerUDP.stringValue integerValue];
    //   server_port? :(server_port = SERVER_PORT);
    if (!server_port) {
        server_port = SERVER_PORT;
    }
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [portMonitorServerUDP setStringValue:[NSString stringWithFormat:@"%ld", (long)server_port]];
    }];
    struct sockaddr_in addr;
    bzero(&addr, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(server_port);
    bind(socketServerUDP, (struct sockaddr*) &addr, sizeof(addr));
    //flagUDP |= kDidBind;
    [NSThread detachNewThreadSelector:@selector(listenFromClient) toTarget:self withObject:nil];
    //   NSButton *startStop = (NSButton *) sender;
    NSButton *startStopButton = (NSButton *)sender;
    [startStopButton setTitle:@"停止"];
}

-(void)listenFromClient {
    struct sockaddr_in addr;

    while (1) {
        char packet[100]= {0};
        socklen_t socklen = sizeof(addr);
     //   flagUDP |= kConnecting;
        ssize_t len = recvfrom(socketServerUDP, &packet, sizeof(packet), 0, (struct sockaddr *)&addr, &socklen);
        if(len == -1){
            continue; //似乎这个不对，因为等于－1时，说明这个端口关闭了；？？？
   //         flagUDP |= kConnectError;
        }
        
    //    flagUDP |= kReceived;
        
        NSString *receiveString = [NSString stringWithUTF8String:packet];
     //   NSData * data = [[NSData alloc] initWithBytes:packet length:len];
        //messageReceivedFromClient = data;
        addressClient = [[NSData alloc] initWithBytes:&addr length:sizeof(addr)];
//        NSArray *arguments= [NSArray arrayWithObjects:address, data, nil];
//        [self performSelectorOnMainThread:@selector(UDPServer:)
//                               withObject:arguments
//                            waitUntilDone:YES];
        
        const char *ipAddress = inet_ntoa(addr.sin_addr);
        NSString *ip = [NSString stringWithUTF8String: ipAddress];
        if (![ip isEqualToString:ipFromClient]) {
            ipFromClient = ip;
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                NSTextStorage *ts = [clientAddressViewServerUDP textStorage];
                [ts replaceCharactersInRange:NSMakeRange([ts length], 0) withString:[NSString stringWithFormat:@"%@\n", ipFromClient]];
                NSSize area = clientAddressViewServerUDP.maxSize;
                [clientAddressViewServerUDP scrollRectToVisible:NSMakeRect(0, area.height-20, area.width, 1)];
            }];
        }

        
        //portNumberFromClient = ntohs(addr.sin_port);
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            NSTextStorage *ts = [receiveTextViewByServerUDP textStorage];
            [ts replaceCharactersInRange:NSMakeRange([ts length], 0) withString:[NSString stringWithFormat:@"\n%@:%@",ipFromClient,receiveString]];
            [receiveTextViewByServerUDP scrollRectToVisible:NSMakeRect(0, receiveTextViewByServerUDP.maxSize.height-20, receiveTextViewByServerUDP.maxSize.width, 20)];
        }];
    }
}



-(IBAction)sendToUDPClient:(id)sender{
    //    NSData *address = [arguments objectAtIndex:0];
    //    NSData *data = [arguments objectAtIndex:1];
    //    messageNeedToSend = data;
    //
    //    flagUDP |= kSendStarting;
    
    NSString *string = sendTextViewByServerUDP.textStorage.string;
    if (![string length]) {
        string = @"Test Words From Server!";
    }
    sendClientUDP.enabled = NO;
    const char *buffer = nil;
    buffer = [string UTF8String];
    int sendLength = [string length];
    NSLog(@"%s, write string is\n %@, size is %d", __func__, string, sendLength);
    
    //    NSString *address = serverAddressInputUDP.stringValue;
    //    if([address componentsSeparatedByString:@"."].count != 4)
    //        address = serverAddressInputUDP.stringValue = localIPAddr;
    
    //确定客户端要联系的服务器端口
    NSInteger server_port = [portMonitorServer.stringValue integerValue];
    //   server_port? :(server_port = SERVER_PORT);
    if (!server_port) {
        server_port = SERVER_PORT;
    }
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [portMonitorServer setStringValue:[NSString stringWithFormat:@"%ld", (long)server_port]];
    }];
    
    
    struct sockaddr_in addr;
    memcpy(&addr, [addressClient bytes], [addressClient length]);
    sendto(socketServerUDP, buffer, sendLength, 0, (const struct sockaddr *) &addr, sizeof(addr));
    //   flagUDP |= kSocketBytesSent;
    sendClientUDP.enabled = YES;
    //也有返回值，说明服务器自动关闭
}

-(IBAction)sendToUDPServer:(id)sender{
    socketClientUDP = socket(AF_INET, SOCK_DGRAM,0);
    
    if (socketClientUDP == -1) {
        //        flagUDP |= kCreateSocketError;
        return;
    }
    struct sockaddr_in addr;
    
    NSString *string = sendTextViewByClientUDP.textStorage.string;
    if (![string length]) {
        string = @"Test Words From Client!";
    }
    sendClient.enabled = NO;
    const char *buffer = nil;
    buffer = [string UTF8String];
    int sendLength = [string length];
    NSLog(@"%s, write string is\n %@, size is %d", __func__, string, sendLength);
    
    NSString *address = serverAddressInputUDP.stringValue;
    if([address componentsSeparatedByString:@"."].count != 4)
        address = serverAddressInputUDP.stringValue = localIPAddr;
    
    //确定客户端要联系的服务器端口
    NSInteger server_port = [serverPortInputUDP.stringValue integerValue];
    //   server_port? :(server_port = SERVER_PORT);
    if (!server_port) {
        server_port = SERVER_PORT;
    }
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [serverPortInputUDP setStringValue:[NSString stringWithFormat:@"%ld", (long)server_port]];
    }];
    
    addr.sin_addr.s_addr = inet_addr([address UTF8String]);
    addr.sin_family = AF_INET;
    addr.sin_port = htons(server_port);
    sendto(socketClientUDP, buffer, sendLength, 0, (const struct sockaddr *) &addr, sizeof(addr));

 //   NSButton *startStop = (NSButton *) sender;
    //这个有重复发送的嫌疑，需要优化。。。发一次即可，要判断socketClientUDP是否为0；
    [NSThread detachNewThreadSelector:@selector(receiveFromServer) toTarget:self withObject:nil];
    stopUDP.enabled =YES;
    sendClientUDP.enabled = YES;
    
}

-(IBAction)stopUDPReceiveFromServer:(id)sender{
    close(socketClientUDP);
    socketClientUDP = 0;//?
    stopUDP.enabled = NO;
    
}


-(void)receiveFromServer {
    
    struct sockaddr_in addr;
    // bzero(&addr, sizeof(addr));
    // addr.sin_family = AF_INET;
    // addr.sin_addr.s_addr = INADDR_ANY;
    //   addr.sin_port = htons(portNumber);
    //    bind(socketServerUDP, (struct sockaddr*) &addr, sizeof(addr));
    // flagUDP |= kDidBind;
    char packet[1000];
    while (socketClientUDP != 0) {
        socklen_t socklen = sizeof(addr);
     //   flagUDP |= kConnecting;
        ssize_t len = recvfrom(socketClientUDP, &packet, sizeof(packet), 0, (struct sockaddr *)&addr, &socklen);
        if(len == -1){
            continue; //似乎这个不对，因为等于－1时，说明这个端口关闭了；？？？
       //     flagUDP |= kConnectError;
        }
        
     //   flagUDP |= kReceived;
    //    NSData * data = [[NSData alloc] initWithBytes:packet length:len];
    //    messageReceivedFromServer = data;
     //   NSData *address = [[NSData alloc] initWithBytes:&addr length:sizeof(addr)];
       // NSArray *arguments= [NSArray arrayWithObjects:address, data, nil];
//        [self performSelectorOnMainThread:@selector(mainThreadReceiveTCPPacket:)
//                               withObject:arguments
//                            waitUntilDone:NO];
        
        const char *ipAddress = inet_ntoa(addr.sin_addr);
        NSString *ipFromServer = [NSString stringWithUTF8String: ipAddress];
        //portNumberToConnect = ntohs(addr.sin_port);
        
        NSString *receiveString = [NSString stringWithUTF8String:packet];
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            NSTextStorage *ts = [receiveTextViewByClientUDP textStorage];
            [ts replaceCharactersInRange:NSMakeRange([ts length], 0) withString:[NSString stringWithFormat:@"\n%@:%@",ipFromServer,receiveString]];
            [receiveTextViewByClientUDP scrollRectToVisible:NSMakeRect(0, receiveTextViewByClient.maxSize.height-20, receiveTextViewByClient.maxSize.width, 20)];
        }];
    }
}



-(IBAction)startTCPServer:(id)sender{
    NSButton *startStop = (NSButton *) sender;
    if ([startStop.title isEqualToString:@"启动"]) {
        [NSThread detachNewThreadSelector:@selector(tcpServerMulti) toTarget:self withObject:nil];
        [startStop setTitle:@"停止"];
    }else{
        close(clientfd);
        clientfd = 0;//?
        [startStop setTitle:@"启动"];
    }
}

-(void)tcpServerMulti{
    int exit_status = EXIT_FAILURE;

    int listenFd = [self startListening];
    
    if (listenFd == -1) {
        fprintf (stderr, "*** Could not open listening socket.\n");
        goto bailout;
    }
    
    // Block SIGPIPE so a dropped connection won't signal us.
    struct sigaction act;
    act.sa_handler = SIG_IGN;
    struct sigaction oact;
    int err = sigaction (SIGPIPE, &act, &oact);
    if (err == -1) perror ("sigaction(SIGPIPE, SIG_IGN)");
    
    // wait for activity
    while (true) {
        fd_set readfds;
        FD_ZERO(&readfds);
        
        // Add the listen socket
        FD_SET(listenFd, &readfds);
        int max_fd = MAX(max_fd, listenFd);
        
        // Add the users.
        for (int i = 0; i < MAX_USERS; i++) {
            const int user_fd = s_Users[i].fd;
            if (user_fd <= 0) continue;
            
            FD_SET (user_fd, &readfds);
            max_fd = MAX (max_fd, user_fd);
        }
        
        // Wait until something interesting happens.
        int nready = select (max_fd + 1, &readfds, NULL, NULL, NULL);
        
        if (nready == -1) {
            perror("select");
            continue;
        }
        
        // See if a new user is knocking on our door.
        if (FD_ISSET(listenFd, &readfds)) {
            [self acceptConnection:listenFd];
        }
        
        // Handle any new incoming data from the users.
        // Closes appear here too.
        for (int i = 0; i < MAX_USERS; i++) {
            ChatterUser *const user = &s_Users[i];
            if (user->fd >= 0 && FD_ISSET(user->fd, &readfds)) {
                [self handleRead:(ChatterUser *const)user];
            }
        }
    }
    exit_status = EXIT_SUCCESS;
    
bailout:
    return;// exit_status;

}

-(int)startListening  {
    // get a socket
    int useIPv6 = 0;
    int fd;
    if (useIPv6) fd = socket (AF_INET6, SOCK_STREAM, 0);
    else fd = socket (AF_INET, SOCK_STREAM, 0);
    
    if (fd == -1) {
        perror ("*** socket");
        if (fd != -1) {
            close(fd);
            fd = -1;
        }
        return fd;
    }
    
    // Reuse the address so stale sockets won't kill us.
    int yes = 1;
    int result = setsockopt (fd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
    if (result == -1) {
        perror("*** setsockopt(SO_REUSEADDR)");
        if (fd != -1) {
            close(fd);
            fd = -1;
        }
        return fd;
    }
    
    // Bind to an address and port
    
    // Glom both kinds of addresses into a union to avoid casting.
    union {
        struct sockaddr sa;       // avoids casting
        struct sockaddr_in in;    // IPv4 support
        struct sockaddr_in6 in6;  // IPv6 support
    } address;
    
    NSInteger server_port = [portMonitorServer.stringValue integerValue];
    //   server_port? :(server_port = SERVER_PORT);
    if (!server_port) {
        server_port = SERVER_PORT;
    }
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [portMonitorServer setStringValue:[NSString stringWithFormat:@"%ld", (long)server_port]];
    }];
    
    if (useIPv6) {
        address.in6.sin6_len = sizeof (address.in6);
        address.in6.sin6_family = AF_INET6;
        address.in6.sin6_port = htons (server_port);
        address.in6.sin6_flowinfo = 0;
        address.in6.sin6_addr = in6addr_any;
        address.in6.sin6_scope_id = 0;
    } else {
        address.in.sin_len = sizeof (address.in);
        address.in.sin_family = AF_INET;
        address.in.sin_port = htons (server_port);
        address.in.sin_addr.s_addr = htonl (INADDR_ANY);
        memset (address.in.sin_zero, 0, sizeof (address.in.sin_zero));
    }
    
    result = bind (fd, &address.sa, address.sa.sa_len);
    if (result == -1) {
        perror("*** bind");
        goto bailout1;
    }
    
    result = listen (fd, kAcceptQueueSizeHint);
    if (result == -1) {
        perror("*** listen");
        goto bailout1;
    }
    NSLog(@"listening on port %d\n", (int)server_port);
    return fd;
    
bailout1:
    if (fd != -1) {
        close(fd);
        fd = -1;
    }
    return fd;
}  // StartListening

// Called when select() indicates the listening socket is ready to be read,
// which means there is a connection waiting to be accepted.
-(void)acceptConnection:(int) listen_fd {
    struct sockaddr_storage addr;
    socklen_t addr_len = sizeof(addr);
    
    int clientFd = accept (listen_fd, (struct sockaddr *)&addr, &addr_len);
    
    if (clientFd == -1) {
        perror("*** accept");
        if (clientFd != -1) close(clientFd);
        return;
    }
    
    // Set to non-blocking
    int err = fcntl (clientFd, F_SETFL, O_NONBLOCK);
    if (err == -1) {
        perror("*** fcntl(clientFd O_NONBLOCK)");
        if (clientFd != -1) close(clientFd);
        return;
    }
    
    // Find the next free spot in the users array
    ChatterUser *newUser = NULL;
    for (int i = 0; i < MAX_USERS; i++) {
        if (s_Users[i].fd == 0) {
            newUser = &s_Users[i];
            break;
        }
    }
    
    if (newUser == NULL) {
        const char gripe[] = "Too many users - try again later.\n";
        write (clientFd, gripe, sizeof(gripe));
        if (clientFd != -1) close(clientFd);
        return;
    }
    
    // ok, clear out the structure, and get it set up
    memset (newUser, 0, sizeof(ChatterUser));
    
    newUser->fd = clientFd;
    clientFd = -1; // Don't let function cleanup close the fd.
    
    // log where the connection is from
    void *net_addr = NULL;
    
    in_port_t port = 0;
    //这里原来是 addr.ss_family == AF_INET
    if (addr.ss_family == AF_INET6) {
        struct sockaddr_in6 *sin6 = (struct sockaddr_in6 *)&addr;
        net_addr = &sin6->sin6_addr;
        port = sin6->sin6_port;
    } else {
        struct sockaddr_in *sin = (struct sockaddr_in *)&addr;
        net_addr = &sin->sin_addr;
        port = sin->sin_port;
    }
    
    // Make it somewhat human readable.
    char buffer[INET6_ADDRSTRLEN];
    const char *name = inet_ntop (addr.ss_family, net_addr,
                                  buffer, sizeof(buffer));
    
    syslog (LOG_NOTICE, "Accepted connection from %s port %d as fd %d.",
            name, port, clientFd);
    NSString *cliaddr = [[NSString alloc] initWithUTF8String:name];
    NSLog(@"%@", cliaddr);
    // [cv setClientAddr:cv.clientAddr string:cliaddr];
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        NSTextStorage *ts = [clientAddressViewServer textStorage];
        [ts replaceCharactersInRange:NSMakeRange([ts length], 0) withString:[NSString stringWithFormat:@"%@ : %d\n", cliaddr, newUser->fd]];
        NSSize area = clientAddressViewServer.maxSize;
        [clientAddressViewServer scrollRectToVisible:NSMakeRect(0, area.height-20, area.width, 1)];
    }];
    
bailout3:
    if (clientFd != -1) close(clientFd);
    return;
}  // AcceptConnection


// we got read activity for a user
-(void) handleRead: (ChatterUser *)user {
   // if (!user->gotName)
    [self readUsername:(ChatterUser *)user];
  //  else ReadMessage(user);
}  // HandleRead

// the first packet is the user's name.  Get it.
-(void) readUsername:(ChatterUser *)user {
    // see if we have read anything yet
    bzero(user->buffer, sizeof(user->buffer));
    if (user->bytesRead == 0) {
        // Read the length byte.
        const size_t toread = sizeof (user->buffer);
        ssize_t nread = read (user->fd, user->buffer, toread);
        NSLog(@"%s,receiveCount is %ld, chars are \"%s\"", __func__, nread, user->buffer);
        if (nread == 0) {
            // end of file
            [self disconnectUser:(ChatterUser *)user];
            
        } else if (nread == -1) {
            perror("read");
            [self disconnectUser:(ChatterUser *)user];
            
        } else {
            NSString *str = [[NSString alloc] initWithUTF8String:user->buffer];
            //  str = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if(str.length != 0){
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    NSTextStorage *ts = [receiveTextViewByServer textStorage];
                    [ts replaceCharactersInRange:NSMakeRange([ts length], 0) withString:[NSString stringWithFormat:@"%d : %@\n", user->fd, str]];
                    [receiveTextViewByServer scrollRectToVisible:NSMakeRect(0, receiveTextViewByServer.maxSize.height-20, receiveTextViewByServer.maxSize.width, 20)];
            //        NSLog(@"%s, maxSize is %@", __func__, NSStringFromSize(receiveTextViewByServer.maxSize));
                }];
                
                
            }
        }
        
    } else {
        // ok, try to read just the rest of the username
//        const uint8_t namelen = (uint8_t)user->buffer[0];
//        const size_t packetlen = sizeof(namelen) + namelen;
//        const size_t nleft = packetlen - user->bytesRead;
        ssize_t nread = read (user->fd, user->buffer, sizeof(user->buffer));
         NSLog(@"%s,receiveCount2 is %ld, chars are \"%s\"", __func__, nread, user->buffer);
        NSString *str = [[NSString alloc] initWithUTF8String:user->buffer];
        user->gotName = true;
        //  str = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if(str.length != 0){
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                NSTextStorage *ts = [receiveTextViewByServer textStorage];
                [ts replaceCharactersInRange:NSMakeRange([ts length], 0) withString:[NSString stringWithFormat:@"%d : %@\n", user->fd, str]];
                
//                NSRect insertionRect=[[receiveTextViewByServer layoutManager] boundingRectForGlyphRange:[receiveTextViewByServer selectedRange] inTextContainer:[receiveTextViewByServer textContainer]];
//                NSPoint scrollPoint=NSMakePoint(0,insertionRect.origin.y+insertionRect.size.height);
//                [receiveTextViewByServer scrollPoint:scrollPoint];
            }];
            
            
        }
        switch (nread) {
            default:
                user->bytesRead += nread;
                break;
                
            case 0:  // peer closed the connection
                [self disconnectUser:(ChatterUser *)user];
                break;
                
            case -1:
                perror ("ReadName: read");
                [self disconnectUser:(ChatterUser *)user];
                break;
        }
        
        // Do we have the name?
//        if (user->bytesRead > namelen) {
//            user->gotName = true;
//            
//            // Copy username into the User structure.
//            memcpy (user->name, &user->buffer[1], namelen);
//            user->name[namelen] = '\0';
//            printf("Received username: %s\n", user->name);
//            
//            // no current message, so clear it out
//            user->buffer[0] = 0;
//            user->bytesRead -= packetlen;
//            
//            syslog(LOG_NOTICE, "Username for fd %d is %s.", user->fd, user->name);
//            BroadcastMessageFromUser("has joined the channel.\n", user);
//        }
    }
}  // ReadUsername

// user disconnected.  Do any mop-up
-(void) disconnectUser:(ChatterUser *)user {
    if (user->fd > 0) {
        close (user->fd);
        user->fd = 0;
        syslog (LOG_NOTICE, "Disconnected user \"%s\" on fd %d\n",
                user->gotName? user->name : "(unknown)", user->fd);
        
        // broadcast 'user disconnected' message
      //  if (user->gotName) BroadcastMessageFromUser("has left the channel.\n", user);
        //这个是否应该补充一个显示界面，显示关闭了某个用户？
    }
    
    user->gotName = false;
    user->bytesRead = 0;
    user->buffer[0] = 0;
    
} // DisconnectUser


// send a message to all the signed-in users
-(void)broadcastMessage {
 //   if (!user->gotName) return;
    
//    static const char separator[] = ": ";
    
    // All messages are expected to have a terminating newline.
 //   printf ("Broadcast message: %s%s%s", user->name, separator, message);
    
    // use scattered writes just for fun. Because We Can.
//    const struct iovec iovector[] = {
//        { (char *)user->name, strlen(user->name)    },
//        { (char *)separator,  sizeof(separator) - 1 }, // omit terminator
//        { (char *)message,    strlen(message)       }
//    };
//    const int iovector_len = sizeof(iovector) / sizeof(*iovector);
    
    // Scan through the users and send the mesage.

    NSString *string = sendTextViewByServer.textStorage.string;
    if (![string length]) {
        string = @"Test Words From Server!";
    }
    sendByServer.enabled = NO;
    
    const char *buffer = nil;
    buffer = [string UTF8String];
    int sendLength = sizeof(buffer)*2;
    NSLog(@"%s, write string is\n %@, size is %d", __func__, string, sendLength);
//    ssize_t write_count = write(clientfd, buffer, sendLength);
    const ChatterUser *stop = &s_Users[MAX_USERS];
    for (ChatterUser *u = s_Users; u < stop; u++) {
        if (u->fd > 0) {
            ssize_t nwrite = write (u->fd, buffer, sendLength);
            NSLog(@"%s, send Date with fd:%ld", __func__, u->fd);
            if (nwrite == -1) perror ("writev");
            else fprintf(stderr, "\tSent \"%s\" %zd bytes\n", u->name, nwrite);
        }
    }
//    
//    if (write_count == -1) {
//        NSLog(@"%s, write error", __func__);
//    }else{
//        //增加一个send successful的弹出显示语句，然后消失
//    }
    
    sendByServer.enabled = YES;
    
    
}  // BroadcastMessageFromUser

-(void)tcpServer{
    int listenfd;
    //    pid_t childpid;
    //    socklen_t chilen;
    struct sockaddr_in servaddr;
    
    listenfd = socket(AF_INET, SOCK_STREAM, 0); //IPv4协议
    
    if (listenfd == -1) {
        perror ("*** socket");
        return;
    }
    
    // Reuse the address so stale sockets won't kill us.
    int yes = 1;
    int result = setsockopt (listenfd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
    if (result == -1) {
        perror("*** setsockopt(SO_REUSEADDR)");
        return;
    }
    
    NSInteger server_port = [portMonitorServer.stringValue integerValue];
 //   server_port? :(server_port = SERVER_PORT);
    if (!server_port) {
        server_port = SERVER_PORT;
    }
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [portMonitorServer setStringValue:[NSString stringWithFormat:@"%ld", (long)server_port]];
    }];

    
    bzero(&servaddr, sizeof(servaddr));
    servaddr.sin_len = sizeof (servaddr);
    servaddr.sin_family = AF_INET;
    servaddr.sin_addr.s_addr = htonl(INADDR_ANY);
    servaddr.sin_port = htons(server_port);
    //memset (servaddr.sin_zero, 0, sizeof (servaddr.sin_zero));
    
    if (bind(listenfd, (struct sockaddr *)&servaddr, sizeof(servaddr)) == -1) {
        NSLog(@"bind error; listenfd: %d", listenfd);
        close(listenfd);
        listenfd = -1;
        return;
    }
    
    if(listen(listenfd, kAcceptQueueSizeHint) == -1) {
        NSLog(@"listen error");
        close(listenfd);
        listenfd = -1;
        return;
    }
    printf("listening on port %d\n", (int)server_port);
    
    struct sockaddr_in addr; //IPv4套接字
    socklen_t addr_len = sizeof(addr);
    clientfd = accept(listenfd, (struct sockaddr *)&addr, &addr_len);

    if (clientfd == -1) {
        NSLog(@"accept error");
        close(listenfd);
        return;
    }
    NSString *cliaddr = [[NSString alloc] initWithUTF8String:inet_ntoa(addr.sin_addr)];
    NSLog(@"%@", cliaddr);
    // [cv setClientAddr:cv.clientAddr string:cliaddr];
   [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        NSTextStorage *ts = [clientAddressViewServer textStorage];
        [ts replaceCharactersInRange:NSMakeRange([ts length], 0) withString:[NSString stringWithFormat:@"%@ : %d", cliaddr, clientfd]];
    }];
    

    //  int err = fcntl (clientfd, F_SETFL, O_NONBLOCK); //这里将服务器设置成非阻塞式，会清除其他文件描述符
    //if (err == -1) {
    //  perror("*** fcntl(clientFd O_NONBLOCK)");
    //goto bailout;
    //}
    
    void *net_addr = NULL;
    in_port_t port = 0;
    struct sockaddr_in *sin = (struct sockaddr_in *) &addr;
    //提取客户端的网络端口和地址
    net_addr = &sin->sin_addr;
    port = sin->sin_port;
    
    //    char buffer[INET6_ADDRSTRLEN];
    const char *name = inet_ntoa(addr.sin_addr);
  //希望在这里增加一个主机IP地址对应到的主机名的打印模块：  char *hostname  = gethostbyname()
    //这个好像没有什么用处
    struct hostent *hptr = gethostbyname(name);
    if (hptr == NULL) {
        NSLog(@"%s, gethostbyname error", __func__);
    }else{
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            NSTextStorage *ts = [clientAddressViewServer textStorage];
            [ts replaceCharactersInRange:NSMakeRange([ts length], 0) withString:[NSString stringWithFormat:@" : %s\n", hptr->h_name]];
        }];
    }
    NSLog(@"Accepted connection from: %s port: %d, as fd: %d.", name, port, clientfd);
    int null = 0;
    while([startServer.title isEqualToString:@"停止"]){
        NSLog(@"%s, clientfd is %d", __func__, clientfd);
        char buffer[1024]={0};
        //        NSLog(@"*****************%s***************", buffer);
        ssize_t receiveCount = read(clientfd,(void *) buffer, sizeof(buffer));
        NSLog(@"%s,receiveCount is %ld, chars are \"%s\"", __func__, receiveCount, buffer);
        //        for (int i = 0; i<receiveCount; i++) {
        //            NSLog(@"%c", buffer[i]);
        //        }
        
        if (receiveCount == -1) {
            break;
        }
        if (receiveCount == 0) {
            break;
        }
        if (!strcmp(buffer, "")) {
            null++;
            if (null == 2) {
                close(clientfd);
                null = 0;
                return;
            }
        }
        NSString *str = [[NSString alloc] initWithUTF8String:buffer];
      //  str = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if(str.length != 0){
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                NSTextStorage *ts = [receiveTextViewByServer textStorage];
                [ts replaceCharactersInRange:NSMakeRange([ts length], 0) withString:[NSString stringWithFormat:@"%d : %@\n", clientfd, str]];
                [receiveTextViewByServer scrollRectToVisible:NSMakeRect(0, receiveTextViewByServer.maxSize.height-20, receiveTextViewByServer.maxSize.width, 20)];
            }];
            

        }
            
//
//            cv.receivedText.stringValue = str;
//        NSLog(@"%@", str);
//        if ([str isEqualToString:@"quit"]) {
//            NSLog(@"%s, this is end", __func__);
//            break;
//        }
//        if ([str isEqualToString:@"*#*#7426#*#*"]) {
//            NSLog(@"transport start!");
//            [pv.paths newPath];
//            continue;
//        }
//        if ([str isEqualToString:@"#*#*8879*#*#"]) {
//            NSLog(@"transport point end!");
//            continue;
//        }
//        [pv.paths addNewPointAtLastPath:[NSValue valueWithPoint:[self dataFormater:str]]];
//        //        [pv reflashView];
//        //     AppDelegate *appdelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
//        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
//            [pv setNeedsDisplay:YES];
//        }];
//        
//        //        NSLog(@"********path: %@", pv.paths.pathArray);
    }
    
bailout:
    if (clientfd != -1) {
        close(clientfd);
        listenfd = -1;
    }
    NSLog(@"%s, stopTCPServer!", __func__);
}

-(IBAction)sendToClient:(id)sender{
    [self broadcastMessage];
//    NSString *string = sendTextViewByServer.textStorage.string;
//    if (![string length]) {
//        string = @"Test Words From Server!";
//    }
//    sendByServer.enabled = NO;
//    const char *buffer = nil;
//    buffer = [string UTF8String];
//    int sendLength = [string length];
//    NSLog(@"%s, write string is\n %@, size is %d", __func__, string, sendLength);
//    ssize_t write_count = write(clientfd, buffer, sendLength);
//    if (write_count == -1) {
//        NSLog(@"%s, write error", __func__);
//    }else{
//        //增加一个send successful的弹出显示语句，然后消失
//    }
//    
//    sendByServer.enabled = YES;
}


- (IBAction)startTCPClient:(id)sender{
    NSButton *startStopClient = (NSButton *)sender;
    if ([startStopClient.title isEqualToString:@"启动"]) {
        if ([self tcpClient]) {
            sendClient.enabled = YES;
            [NSThread detachNewThreadSelector:@selector(receiveData) toTarget:self withObject:nil];
            [startClient setTitle:@"停止"];
        }
    }else{
        close(socketClientTCP);
        socketClientTCP = 0;//?
        [startStopClient setTitle:@"启动"];
    }

}

-(IBAction)sendToServer:(id)sender{
    [self sendDataToServer];
}

-(BOOL)tcpClient {
    //确定客户端要联系的服务器端口
    NSInteger server_port = [serverPortInput.stringValue integerValue];
    //   server_port? :(server_port = SERVER_PORT);
    if (!server_port) {
        server_port = SERVER_PORT;
    }
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [serverPortInput setStringValue:[NSString stringWithFormat:@"%ld", (long)server_port]];
    }];
    
    NSString *address = serverAddressInput.stringValue;
    if([address componentsSeparatedByString:@"."].count != 4)
        address = serverAddressInput.stringValue = localIPAddr;
    
    socketClientTCP = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in servaddr;
    bzero(&servaddr, sizeof(servaddr));
    inet_pton(AF_INET, [address UTF8String], &servaddr.sin_addr);
    servaddr.sin_family = AF_INET;
    servaddr.sin_port = htons(server_port);

    int returnCode = connect(socketClientTCP, (const struct sockaddr *)&servaddr, sizeof(servaddr));
    if (returnCode != 0) {
        [self closeSocket:socketClientTCP];
        return false;
    }
//    flagTCP |= kDidConnect;
    
    int set = 1;
    setsockopt(socketClientTCP, SOL_SOCKET,SO_REUSEADDR, &set, sizeof(set));
    return true;
}

-(void)sendDataToServer{
    NSString *sendData = sendTextViewByClient.textStorage.string;
    if (![sendData length]) {
        sendData = @"Test Words From Client!";
    }
    sendClient.enabled = NO;
    const char *buffer = nil;
    buffer = [sendData UTF8String];
    int sendLength = sizeof(buffer)*2;
    NSLog(@"%s, write string is\n %@, size is %d", __func__, sendData, sendLength);
    ssize_t write_count = write(socketClientTCP, buffer, sendLength);
    if (write_count == -1) {
        NSLog(@"%s, write error", __func__);
        [self closeSocket:socketClientTCP];
        [startClient setTitle:@"启动"];
    }else{
        //增加一个send successful的弹出显示语句，然后消失
    }
    
    sendClient.enabled = YES;
}

-(void)receiveData {
    while (socketClientTCP != -1) {
        char receivedPacket[1000] = {0};
        ssize_t nread = read(socketClientTCP, &receivedPacket, sizeof(receivedPacket));
        if (nread == 0) {  //有没有可能nread小于0？
           // flagTCP |= kConnectError;
            [self closeSocket:socketClientTCP];
            [startClient setTitle:@"启动"];
            return;
        }
        NSData *data = [NSData dataWithBytes:receivedPacket length:nread];
        NSString *receiveString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"%s, receivedString is %@， nread is %ld", __func__, receiveString, nread);
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            NSTextStorage *ts = [receiveTextViewByClient textStorage];
            [ts replaceCharactersInRange:NSMakeRange([ts length], 0) withString:[NSString stringWithFormat:@"%@",receiveString]];
            [receiveTextViewByClient scrollRectToVisible:NSMakeRect(0, receiveTextViewByClient.maxSize.height-20, receiveTextViewByClient.maxSize.width, 20)];
        }];

    }
    
}

-(void)closeSocket:(int)fd {
    close(fd);
    fd = -1;
//    NSString *cmdReceive = [NSString stringWithFormat:@"SERVER:SHARE:CLOSE"];
//    NSArray *arguments = [NSArray arrayWithObjects:cmdReceive, nil];
//    [self performSelectorOnMainThread:@selector(mainThreadReceiveTCPPacket:)
//                           withObject:arguments
//                        waitUntilDone:YES];
}

-(IBAction)changeSendToServerDataFormat:(id)sender{
    NSButton *radio = (NSButton *) sender;
    NSLog(@"%s, radioButton's type is %ld,  title is %@", __func__, radio.state, radio.title);
    if ([radio.title isEqualToString:@"HEX"]) {
        NSData *data = [sendTextViewByClient.string dataUsingEncoding:NSUTF8StringEncoding];
        sendTextViewByClient.string = [data hexadecimalString];
    }else{
        NSData *data = [NSData dataWithHexString: sendTextViewByClient.string];
        sendTextViewByClient.string = [NSString stringWithUTF8String:[data bytes]];
    }
    
}

-(IBAction)changeReceiveFromServerDataFormat:(id)sender{
    NSButton *radio = (NSButton *) sender;
    NSLog(@"%s, radioButton's type is %ld,  title is %@", __func__, radio.state, radio.title);
    if ([radio.title isEqualToString:@"HEX"]) {
        NSData *data = [receiveTextViewByClient.string dataUsingEncoding:NSUTF8StringEncoding];
        receiveTextViewByClient.string = [data hexadecimalString];
    }else{
        NSData *data = [NSData dataWithHexString: receiveTextViewByClient.string];
        receiveTextViewByClient.string = [NSString stringWithUTF8String:[data bytes]];
    }

}

-(IBAction)changeSendToClientDataFormat:(id)sender{
    NSButton *radio = (NSButton *) sender;
    NSLog(@"%s, radioButton's type is %ld,  title is %@", __func__, radio.state, radio.title);
    if ([radio.title isEqualToString:@"HEX"]) {
        NSData *data = [sendTextViewByServer.string dataUsingEncoding:NSUTF8StringEncoding];
        sendTextViewByServer.string = [data hexadecimalString];
    }else{
        NSData *data = [NSData dataWithHexString: sendTextViewByServer.string];
        sendTextViewByServer.string = [NSString stringWithUTF8String:[data bytes]];
    }
}

-(IBAction)changeReceiveFromClientDataFormat:(id)sender{
    NSButton *radio = (NSButton *) sender;
    NSLog(@"%s, radioButton's type is %ld,  title is %@", __func__, radio.state, radio.title);
    if ([radio.title isEqualToString:@"HEX"]) {
        NSData *data = [receiveTextViewByServer.string dataUsingEncoding:NSUTF8StringEncoding];
        receiveTextViewByServer.string = [data hexadecimalString];
    }else{
        NSData *data = [NSData dataWithHexString: receiveTextViewByServer.string];
        receiveTextViewByServer.string = [NSString stringWithUTF8String:[data bytes]];
    }
}

-(NSString *)localIPAddress
{
    NSString *localIP = nil;
    struct ifaddrs *addrs;
    if (getifaddrs(&addrs)==0) {
        const struct ifaddrs *cursor = addrs;
        while (cursor != NULL) {
            if (cursor->ifa_addr->sa_family == AF_INET && (cursor->ifa_flags & IFF_LOOPBACK) == 0)
            {
                //NSString *name = [NSString stringWithUTF8String:cursor->ifa_name];
                //if ([name isEqualToString:@"en0"]) // Wi-Fi adapter
                {
                    localIP = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)cursor->ifa_addr)->sin_addr)];
                    break;
                }
            }
            cursor = cursor->ifa_next;
        }
        freeifaddrs(addrs);
    }
    return localIP;
}

//-(void)textDidChange:(NSNotification *)notification{
//    NSTextView *textView = notification.object;
//    NSString *send = textView.textStorage.string;
//    if([[send substringWithRange:NSMakeRange([send length] - 1, 1)] isEqualToString:@"\n"]){
//       [self sendToClient:sendByServer]; 
//    }
//}
//-(BOOL)textShouldEndEditing:(NSText *)textObject{
//    [self sendToClient:sendByServer];
//    return NO;
//}
@end
