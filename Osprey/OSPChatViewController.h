#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <WebKit/WebResourceLoadDelegate.h>
#import <WebKit/WebFrameLoadDelegate.h>

@interface OSPChatViewController : NSViewController {
    IBOutlet NSTextField    *inputField;
    IBOutlet WebView        *webView;
    IBOutlet NSWindow       *window;
    
    XMPPJID *localJid;
    XMPPJID *remoteJid;
    
    
    XMPPJID *lastMessageFromJid;
    NSString *previousHistoryMessageFromJidStr;

    
    
    
    DOMHTMLElement *topFirstStreak;    //top insertion pointer
    DOMNode     *topFirstMessage;
    NSString* topFirstMessageJidStr;   
    DOMHTMLElement *bottomLastStreak;    //bottom insertion pointer
    NSString *bottomLastMessageJidStr;
    
    
    
    
    DOMHTMLElement *streakElement;          //Last streak element at the bottom where new messages are appended
    DOMHTMLElement *backwardStreakElement;  //Fist streak element at the top, where history messages are prepended

    
    NSMutableArray *messageQueue;
    
    BOOL isLoadViewFinished;
    BOOL isWebViewReady;
    
    dispatch_queue_t processingQueue;
    BOOL processionQueueIsSuspended;
    
    NSDateFormatter *formatter;

}

- (id)initWithRemoteJid:(XMPPJID*)rjid;
- (void) focusInputField;
- (IBAction) send:(id)sender;


- (void) displayChatMessage:(XMPPMessage*)message;
- (void) displayAttentionMessage:(XMPPMessage*)message;
- (void) displayPresenceMessage:(XMPPPresence*)message;
- (void) dispatch:(id)object toSelector:(SEL)selector;

@end
