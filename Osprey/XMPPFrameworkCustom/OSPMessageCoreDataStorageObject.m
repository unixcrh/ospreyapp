#import "OSPMessageCoreDataStorageObject.h"
#import "OSPUserCoreDataStorageObject.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

@implementation OSPMessageCoreDataStorageObject

@dynamic jid;
@dynamic body;
@dynamic timestamp;
@dynamic isFromMe;
@dynamic streamBareJidStr;


// Messages are ordered chronologically
- (NSComparisonResult)compare:(OSPMessageCoreDataStorageObject*)another {
    NSDate *myTimestamp = [self timestamp];
	NSDate *otherTimestamp = [another timestamp];
	
    return [myTimestamp compare:otherTimestamp];
}
@end
