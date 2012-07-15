#import "OSPMessageCoreDataStorage.h"
#import "OSPMessageCoreDataStorageObject.h"
#import "XMPP.h"
#import "XMPPCoreDataStorageProtected.h"
#import "XMPPLogging.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
#if DEBUG
static const int xmppLogLevel = XMPP_LOG_LEVEL_VERBOSE; // | XMPP_LOG_FLAG_TRACE;
#else
static const int xmppLogLevel = XMPP_LOG_LEVEL_ERROR;
#endif

#define AssertPrivateQueue() \
NSAssert(dispatch_get_current_queue() == storageQueue, @"Private method: MUST run on storageQueue");


@implementation OSPMessageCoreDataStorage

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Setup
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)configureWithParent:(XMPPRoster *)aParent queue:(dispatch_queue_t)queue {
    return [super configureWithParent:aParent queue:queue];
}


// takes message and prepares for writing to storage
- (void)handleIncomingMessage:(XMPPMessage *)message onStream:(XMPPStream*)stream;
{
	[self scheduleBlock:^{
        [self insertMessage:message outgoing:NO xmppStream:stream];
	}];
}

- (void)handleOutgoingMessage:(XMPPMessage *)message onStream:(XMPPStream*)stream;
{
	[self scheduleBlock:^{
        [self insertMessage:message outgoing:YES xmppStream:stream];
	}];
}

// writes to storage
- (void)insertMessage:(XMPPMessage *)message outgoing:(BOOL)isOutgoing xmppStream:(XMPPStream*)stream;
{
    // Prepare attributes
    NSString *streamBareJidStr = [[self myJIDForXMPPStream:stream] bare];
    NSString *messageJID = isOutgoing ? [[message to] bare] : [[message from] bare];  // Jid of the remote 
	NSString *messageBody = [[message elementForName:@"body"] stringValue];
    NSDate *timestamp = [[NSDate alloc] init];	

    // Create entity
    NSManagedObjectContext *moc = [self managedObjectContext];
	NSEntityDescription *messageEntity = [NSEntityDescription entityForName:@"OSPMessageCoreDataStorageObject" inManagedObjectContext:moc];
	OSPMessageCoreDataStorageObject *messageObject = (OSPMessageCoreDataStorageObject *) [[NSManagedObject alloc] initWithEntity:messageEntity insertIntoManagedObjectContext:nil];
	
    // Set attributes
	messageObject.jid = messageJID;
	messageObject.body = messageBody;
	messageObject.timestamp = timestamp;
	messageObject.isFromMe = isOutgoing;
	messageObject.streamBareJidStr = streamBareJidStr;
	
    // Save entity
	//
    [moc insertObject:messageObject]; 
    DDLogVerbose(@"Message was saved (%@)", messageBody);
}


@end

