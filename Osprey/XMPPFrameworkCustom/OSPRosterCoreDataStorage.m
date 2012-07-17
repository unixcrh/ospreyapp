#import "OSPRosterCoreDataStorage.h"
#import "XMPPCoreDataStorageProtected.h"

@implementation OSPRosterCoreDataStorage 

- (void)beginRosterPopulationForXMPPStream:(XMPPStream *)stream {
    // Overwritten to prevent nuking of roster database on every startup
}

- (void)incrementUnreadCountForJid:(XMPPJID*)jid {
    
}

- (void)

@end
