//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "DebugUISyncMessages.h"
#import "DebugUIContacts.h"
#import "OWSTableViewController.h"
#import "Signal-Swift.h"
#import "ThreadUtil.h"
#import <AxolotlKit/PreKeyBundle.h>
#import <SignalCoreKit/Randomness.h>
#import <SignalMessaging/Environment.h>
#import <SignalServiceKit/OWSBatchMessageProcessor.h>
#import <SignalServiceKit/OWSBlockingManager.h>
#import <SignalServiceKit/OWSDisappearingConfigurationUpdateInfoMessage.h>
#import <SignalServiceKit/OWSDisappearingMessagesConfiguration.h>
#import <SignalServiceKit/OWSPrimaryStorage+SessionStore.h>
#import <SignalServiceKit/OWSPrimaryStorage.h>
#import <SignalServiceKit/OWSReadReceiptManager.h>
#import <SignalServiceKit/OWSSyncGroupsMessage.h>
#import <SignalServiceKit/OWSSyncGroupsRequestMessage.h>
#import <SignalServiceKit/OWSVerificationStateChangeMessage.h>
#import <SignalServiceKit/TSCall.h>
#import <SignalServiceKit/TSDatabaseView.h>
#import <SignalServiceKit/TSIncomingMessage.h>
#import <SignalServiceKit/TSInvalidIdentityKeyReceivingErrorMessage.h>
#import <SignalServiceKit/TSThread.h>

NS_ASSUME_NONNULL_BEGIN

@implementation DebugUISyncMessages

#pragma mark - Factory Methods

- (NSString *)name
{
    return @"Sync Messages";
}

- (nullable OWSTableSection *)sectionForThread:(nullable TSThread *)thread
{
    NSArray<OWSTableItem *> *items = @[
        [OWSTableItem itemWithTitle:@"Send Contacts Sync Message"
                        actionBlock:^{
                            [DebugUISyncMessages sendContactsSyncMessage];
                        }],
        [OWSTableItem itemWithTitle:@"Send Groups Sync Message"
                        actionBlock:^{
                            [DebugUISyncMessages sendGroupSyncMessage];
                        }],
        [OWSTableItem itemWithTitle:@"Send Blocklist Sync Message"
                        actionBlock:^{
                            [DebugUISyncMessages sendBlockListSyncMessage];
                        }],
        [OWSTableItem itemWithTitle:@"Send Configuration Sync Message"
                        actionBlock:^{
                            [DebugUISyncMessages sendConfigurationSyncMessage];
                        }],
    ];
    return [OWSTableSection sectionWithTitle:self.name items:items];
}

+ (OWSMessageSender *)messageSender
{
    return SSKEnvironment.shared.messageSender;
}

+ (OWSContactsManager *)contactsManager
{
    return Environment.shared.contactsManager;
}

+ (OWSIdentityManager *)identityManager
{
    return [OWSIdentityManager sharedManager];
}

+ (OWSBlockingManager *)blockingManager
{
    return [OWSBlockingManager sharedManager];
}

+ (OWSProfileManager *)profileManager
{
    return [OWSProfileManager sharedManager];
}

+ (YapDatabaseConnection *)dbConnection
{
    return [OWSPrimaryStorage.sharedManager newDatabaseConnection];
}

+ (id<OWSSyncManagerProtocol>)syncManager
{
    OWSAssertDebug(SSKEnvironment.shared.syncManager);

    return SSKEnvironment.shared.syncManager;
}

+ (void)sendContactsSyncMessage
{
    [self.syncManager syncAllContacts];
}

+ (void)sendGroupSyncMessage
{
    OWSSyncGroupsMessage *syncGroupsMessage = [[OWSSyncGroupsMessage alloc] init];
    __block DataSource *dataSource;
    [self.dbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        dataSource = [DataSourceValue
            dataSourceWithSyncMessageData:[syncGroupsMessage buildPlainTextAttachmentDataWithTransaction:transaction]];
    }];
    [self.messageSender enqueueTemporaryAttachment:dataSource
        contentType:OWSMimeTypeApplicationOctetStream
        inMessage:syncGroupsMessage
        success:^{
            OWSLogInfo(@"Successfully sent Groups response syncMessage.");
        }
        failure:^(NSError *error) {
            OWSLogError(@"Failed to send Groups response syncMessage with error: %@", error);
        }];
}

+ (void)sendBlockListSyncMessage
{
    [self.blockingManager syncBlockList];
}

+ (void)sendConfigurationSyncMessage
{
    [SSKEnvironment.shared.syncManager sendConfigurationSyncMessage];
}

@end

NS_ASSUME_NONNULL_END
