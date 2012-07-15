#import "OSPChatViewController.h"
#import "NSColor+HexAdditions.h"
#import "Types.h"
#import "XMPPMessage+XEP_0224.h"
#import "OSPMessageCoreDataStorageObject.h"

typedef enum {
    localToRemote = 1, 
    remoteToLocal = 2,
} EDirection;

@interface OSPChatViewController (PrivateAPI) 
- (NSImage*) _avatarForJid:(XMPPJID*)jid;
- (void) _writeToTextView:(NSString*)message forJid:(XMPPJID*)jid;
- (void) _displayPresenceMessage:(XMPPPresence*)presence;
- (void) _displayAttentionMessage:(XMPPMessage*)message;
- (void) _displayChatMessage:(XMPPMessage*)message;
- (void) _loadRecentHistory;

- (void)appendMessage:(NSString*)body streamBareJid:(NSString*)streamBareJid remoteJid:(NSString*)jid fromMe:(BOOL)isFromMe timestamp:(NSDate*)timestamp;
- (DOMHTMLElement *)createMessageElementFromStorage:(OSPMessageCoreDataStorageObject*)message;
- (DOMHTMLElement *)createMessageElementFrom:(NSDate*)timestamp body:(NSString*)body;
@end


@implementation OSPChatViewController

#pragma mark -  Accessors
- (XMPPStream *)xmppStream
{
	return [[NSApp delegate] xmppStream];
}

- (OSPRosterController *)rosterController
{
	return [[NSApp delegate] rosterController];
}

- (XMPPRoster *)xmppRoster
{
	return [[NSApp delegate] xmppRoster];
}

- (OSPRosterStorage *)xmppRosterStorage
{
	return [[NSApp delegate] xmppRosterStorage];
}

- (NSManagedObjectContext *)managedObjectContext
{
	return [[NSApp delegate] managedObjectContext];
}

#pragma mark - Intialization
- (id)initWithRemoteJid:(XMPPJID*)rjid
{
    self = [super initWithNibName:@"chatView" bundle:nil];
    if (self) {
        isLoadViewFinished = NO;
        isWebViewReady = NO;
        localJid = [[self xmppStream] myJID];
        remoteJid = rjid;
        messageQueue = [[NSMutableArray alloc] init];
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm:ss"];
        
        
        processingQueue = dispatch_queue_create(nil, DISPATCH_QUEUE_SERIAL);
        dispatch_suspend(processingQueue);
        processionQueueIsSuspended = YES;
        
                [self _loadRecentHistory];
    

    }
    return self;
    
}

- (void) dealloc {
    dispatch_release(processingQueue);


}

- (void) _loadRecentHistory {
	
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"OSPMessageCoreDataStorageObject" inManagedObjectContext:[self managedObjectContext]];
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"streamBareJidStr == %@ AND jid == %@",  [[[self xmppStream] myJID] bare], remoteJid];

    
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entity];
	[fetchRequest setPredicate:predicate];
	[fetchRequest setIncludesPendingChanges:YES];
	[fetchRequest setFetchLimit:2];

	NSArray *results = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
	
    for (OSPMessageCoreDataStorageObject* message in results) {
        [self dispatch:message toSelector:@selector(prependHistory:)];
    }
}

- (void) awakeFromNib {
    [inputField bind:@"hidden" toObject:[[NSApp delegate] statusController] withKeyPath:@"connectionState" options:[NSDictionary dictionaryWithObjectsAndKeys:@"OSPConnectionStateToNotAuthenticatedTransformer",NSValueTransformerNameBindingOption, nil]];
}



- (void)cstmviewWillLoad {
    
}

- (void)cstmviewDidLoad {
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"chat" withExtension:@"html"];
	[[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:url]];
}

- (void)loadView {
    if (!isLoadViewFinished) {
        [self cstmviewWillLoad];
        [super loadView];
        [self cstmviewDidLoad];
        isLoadViewFinished = YES;
    }
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
    isWebViewReady = YES;
    // There is no way to know if a queue is suspended and suspending a already suspended queue crashes 
    if (processionQueueIsSuspended) {
        dispatch_resume(processingQueue);
        processionQueueIsSuspended = NO;
    }
}









- (void) focusInputField {
    [inputField becomeFirstResponder];
}




# pragma mark - Message display 

// Convenience accessors to processing queue
- (void) displayChatMessage:(XMPPMessage*)message {
    [self dispatch:message toSelector:@selector(appendMessageFromXMPPMessage:)];

}
- (void) displayAttentionMessage:(XMPPMessage*)message {
    [self dispatch:message toSelector:@selector(_displayAttentionMessage:)];

}
- (void) displayPresenceMessage:(XMPPPresence*)message {
    [self dispatch:message toSelector:@selector(_displayPresenceMessage:)];
     
}


// Processing queue scheduler
- (void) dispatch:(id)object toSelector:(SEL)selector {
    dispatch_block_t block = ^{ @autoreleasepool {
            dispatch_async(dispatch_get_main_queue(), ^{  
                [self tryToPerform:selector with:object];
            });
        }
    };
	
	if (isWebViewReady == YES) {  block(); } 
    else { self.loadView; dispatch_async(processingQueue, block); }    
}







// This is just a wrapper for later, where regular chat and history might share the same backend. 
// Thus prependHistory and appendMessage share the same arguments, while in appendMessage this is just translated
- (DOMHTMLElement *)createMessageElementFromStorage:(OSPMessageCoreDataStorageObject*)message {
    return [self createMessageElementFrom:message.timestamp body:message.body];
}


// Returns the actual message that can be inserted into a streak
- (DOMHTMLElement *)createMessageElementFrom:(NSDate*)timestamp body:(NSString*)body {

    DOMHTMLElement *messageElement = (DOMHTMLElement*)[[[webView mainFrame] DOMDocument] createElement:@"div"];
    DOMHTMLElement *datetime = (DOMHTMLElement*)[[[webView mainFrame] DOMDocument] createElement:@"span"];
    [datetime setAttribute:@"class" value:@"datetime"];
    [datetime setInnerText:[formatter stringFromDate:timestamp]];
    
    
    [messageElement setInnerHTML:body];
    [messageElement setAttribute:@"class" value:@"message"];    
    [messageElement appendChild:datetime];
    return messageElement;
}

// Checks if the current user would continue a streak on the bottom
- (BOOL) isBottomStreak:(NSString*)fromJidStr {
    if ([fromJidStr isEqualToString:bottomLastMessageJidStr]) {
        return YES;
    } else {
        return NO;
    }
}

// Checks if the current user would continue a streak on the top
- (BOOL) isTopStreak:(NSString*)fromJidStr {    
    if ([fromJidStr isEqualToString:topFirstMessageJidStr]) {
        return YES;
    } else {
        return NO;
    }
}

// Wrapper that takes an XMPPMessage and prepares it for appending by the more general method
- (void)appendMessageFromXMPPMessage:(XMPPMessage*)message {
    BOOL fromMe;
    if ([[[message from] bare] isEqualToString:remoteJid.bare]) {
        fromMe = NO;
    } else {
        fromMe = YES;
    }
    
    [self appendMessage:[[message elementForName:@"body"] stringValue] 
          streamBareJid:localJid.bare 
              remoteJid:remoteJid.bare 
                 fromMe:fromMe 
              timestamp:[NSDate date]];
}

- (void)appendMessage:(NSString*)body streamBareJid:(NSString*)streamBareJid remoteJid:(NSString*)jid fromMe:(BOOL)isFromMe timestamp:(NSDate*)timestamp{
    DOMElement *chatElement = [[[webView mainFrame] DOMDocument] getElementById:@"chat"];
    
    NSString *fromJidStr;
    if (isFromMe) {
        fromJidStr = streamBareJid; 
    }else { 
        fromJidStr = jid;
    }
    DOMHTMLElement *messageElement = [self createMessageElementFrom:timestamp body:body];
    
    if (![self isBottomStreak:fromJidStr] || bottomLastStreak == nil ) {
        bottomLastStreak = (DOMHTMLElement*)[[[webView mainFrame] DOMDocument] createElement:@"div"];
        [bottomLastStreak setAttribute:@"class" value:[NSString stringWithFormat:@"streak %@", (isFromMe ? @"out" : @"in")]]; 
        [chatElement appendChild:bottomLastStreak];
        
    }
    
    [bottomLastStreak appendChild:messageElement];
     
    bottomLastMessageJidStr = fromJidStr;
}

- (void)prependHistory:(OSPMessageCoreDataStorageObject*)message {
DOMElement *chatElement = [[[webView mainFrame] DOMDocument] getElementById:@"chat"];

    NSString *fromJidStr;

    if (message.isFromMe) {
        
        fromJidStr = message.streamBareJidStr;
    } else { 
        fromJidStr = message.jid;
    }
    
    DOMHTMLElement *messageElement = [self createMessageElementFromStorage:message];

    if (![self isTopStreak:fromJidStr] || topFirstStreak == nil) {
        topFirstStreak = (DOMHTMLElement*)[[[webView mainFrame] DOMDocument] createElement:@"div"];
        [topFirstStreak setAttribute:@"class" value:[NSString stringWithFormat:@"streak %@", (message.isFromMe ? @"out" : @"in")]]; 
        [[[[webView mainFrame] DOMDocument] getElementById:@"history"] appendChild:topFirstStreak]; // this is wrong yet
    } else {

        [topFirstStreak insertBefore:messageElement refChild:topFirstMessage];
        topFirstMessage = messageElement;
    }
    topFirstMessageJidStr = fromJidStr;
}






// Private methods for actual display. 
// Never call from outside as corresponding webView might not be ready.
- (void) _displayChatMessage:(XMPPMessage*)message {
//    XMPPJID *fromJID = [[XMPPJID jidWithString:[message attributeStringValueForName:@"from"]] bareJID]; 
//    DOMHTMLElement *messageElement = (DOMHTMLElement*)[[[webView mainFrame] DOMDocument] createElement:@"div"];
//
//    
//    DOMHTMLElement *datetime = (DOMHTMLElement*)[[[webView mainFrame] DOMDocument] createElement:@"span"];
//    [datetime setAttribute:@"class" value:@"datetime"];
//    [datetime setInnerText:[formatter stringFromDate:[NSDate date]]];
//    
//    // Check if we have an inbound or outbound message
//    NSString *inOut = [fromJID isEqualToJID:remoteJid] ? @"in" : @"out";
//    
//    
//    // Check if message is in a streak
//    if ((![fromJID isEqualToJID:lastMessageFromJid]) || (streakElement == nil)) {
//        streakElement = (DOMHTMLElement*)[[[webView mainFrame] DOMDocument] createElement:@"div"];
//        [streakElement setAttribute:@"class" value:[NSString stringWithFormat:@"streak %@", inOut]]; 
//        [[[[webView mainFrame] DOMDocument] getElementById:@"chat"] appendChild:streakElement];
//    }
//    
//    [messageElement setAttribute:@"class" value:[NSString stringWithFormat:@"message %@", inOut]];    
//    [messageElement setInnerHTML:[NSString stringWithFormat:@"%@", [[message elementForName:@"body"] stringValue]]];
//    [messageElement appendChild:datetime];
//    lastMessageFromJid = fromJID;
//    
//    [streakElement appendChild:messageElement];
//    [messageElement scrollIntoView:YES];
}

- (void) _displayAttentionMessage:(XMPPMessage*)message {
//    DOMHTMLElement *messageElement = (DOMHTMLElement*)[[[webView mainFrame] DOMDocument] createElement:@"div"];
//
//    streakElement = (DOMHTMLElement*)[[[webView mainFrame] DOMDocument] createElement:@"div"];
//    [streakElement setAttribute:@"class" value:@"streak attention"]; 
//    [[[[webView mainFrame] DOMDocument] getElementById:@"chat"] appendChild:streakElement];
//    
//    [messageElement setAttribute:@"class" value:[NSString stringWithFormat:@"message"]];    
//    [messageElement setInnerHTML:[NSString stringWithFormat:@"Your contact %@", [[message elementForName:@"body"] stringValue]]];
//
//    lastMessageFromJid = nil;
//
//    [streakElement appendChild:messageElement];
//    [messageElement scrollIntoView:YES];
}

- (void) _displayPresenceMessage:(XMPPPresence*)presence {
    
}
// Takes input from the user, sends it and enques for display
- (IBAction) send:(id)sender {
    XMPPMessage *message = [[XMPPMessage alloc] initWithType:@"chat" to:remoteJid];
    NSXMLElement *body = [NSXMLElement elementWithName:@"body"];
    [body setStringValue:[sender stringValue]];
    [message addChild:body];
    
    [[self xmppStream] sendElement:message];
    [message addAttributeWithName:@"from" stringValue:[localJid full]];
    
    [self displayChatMessage:message];
    
    [sender setStringValue:@""];
}



- (NSImage*) _avatarForJid:(XMPPJID*)jid {
    OSPUserStorageObject *user = [[self xmppRosterStorage] userForJID:jid xmppStream:[self xmppStream] managedObjectContext:[self managedObjectContext]];
    
    NSImage *avatar;
    
    assert(user); // Not sure if the own user is always contained in the roster
    
    // If the photo is cached in the roster, use that, otherwise get it from vCardAvatarModule
    if (user.photo != nil)
	{
		avatar = user.photo;
	} 
	else
	{
        NSData *photoData = [[[NSApp delegate] xmppvCardAvatarModule] photoDataForJID:jid];
        if (photoData != nil) {
            avatar = [[NSImage alloc] initWithData:photoData];
            user.photo = avatar; // Cache it in roster while we're at it
        } else { 
            avatar = [NSImage imageNamed:@"Account"];
        }
    }
    
    [avatar setSize:NSMakeSize(38.0, 38.0)];
    return avatar;
}

@end
