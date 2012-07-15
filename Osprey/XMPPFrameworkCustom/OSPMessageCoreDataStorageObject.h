#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class OSPUserCoreDataStorageObject;

@interface OSPMessageCoreDataStorageObject : NSManagedObject

@property (nonatomic, retain) NSString * jid;
@property (nonatomic, retain) NSString * body;
@property (nonatomic, retain) NSDate * timestamp;
@property (nonatomic, assign) BOOL isFromMe;
@property (nonatomic, retain) NSString * streamBareJidStr;



- (NSComparisonResult)compare:(OSPMessageCoreDataStorageObject*)another;

@end
