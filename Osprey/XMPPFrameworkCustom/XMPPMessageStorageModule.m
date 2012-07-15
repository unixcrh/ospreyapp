#import "XMPPMessageStorageModule.h"
#import "XMPP.h"
#import "XMPPLogging.h"


// Log levels: off, error, warn, info, verbose
// Log flags: trace
#if DEBUG
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // | XMPP_LOG_FLAG_TRACE;
#else
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

@implementation XMPPMessageStorageModule


- (id)init
{
	return [self initWithDispatchQueue:NULL];
}
- (id)initWithMessageStorage:(id <OSPMessageStorage>)storage
{
	return [self initWithMessageStorage:storage dispatchQueue:NULL];
}

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
	if ((self = [super initWithDispatchQueue:queue]))
	{
	}
	return self;
}




- (id)initWithMessageStorage:(id <OSPMessageStorage>)storage dispatchQueue:(dispatch_queue_t)queue
{
	NSParameterAssert(storage != nil);
	
	if ((self = [super initWithDispatchQueue:queue]))
	{
		if ([storage configureWithParent:self queue:moduleQueue])
		{
			messageStorage = storage;
		}
		else
		{
			XMPPLogError(@"%@: %@ - Unable to configure storage!", THIS_FILE, THIS_METHOD);
		}
	}
	return self;
}


- (BOOL)activate:(XMPPStream *)aXmppStream
{
	if ([super activate:aXmppStream])
	{
		return YES;
	}
	
	return NO;
}

- (void)deactivate
{
	[super deactivate];
}




- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
    if ([message isChatMessageWithBody]){
        [messageStorage handleIncomingMessage:message onStream:sender];        
    }
}

- (void)xmppStream:(XMPPStream *)sender didSendMessage:(XMPPMessage *)message {
    if ([message isChatMessageWithBody]){
        [messageStorage handleOutgoingMessage:message onStream:sender];        
    }
}





@end
