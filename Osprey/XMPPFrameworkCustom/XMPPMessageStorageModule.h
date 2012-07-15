#import "XMPPModule.h"


@protocol OSPMessageStorage
- (BOOL)configureWithParent:(XMPPModule *)aParent queue:(dispatch_queue_t)queue; 

// takes message and prepares for writing to storage
- (void)handleIncomingMessage:(XMPPMessage *)message onStream:(XMPPStream*)stream;
- (void)handleOutgoingMessage:(XMPPMessage *)message onStream:(XMPPStream*)stream;

// writes to storage
- (void)insertMessage:(XMPPMessage *)message outgoing:(BOOL)isOutgoing xmppStream:(XMPPStream*)stream;
@optional
@end


@interface XMPPMessageStorageModule : XMPPModule {
    __strong id <OSPMessageStorage> messageStorage;
}

- (id)init;
- (id)initWithMessageStorage:(id <OSPMessageStorage>)storage;
- (id)initWithDispatchQueue:(dispatch_queue_t)queue;
- (id)initWithMessageStorage:(id <OSPMessageStorage>)storage dispatchQueue:(dispatch_queue_t)queue;

@end

