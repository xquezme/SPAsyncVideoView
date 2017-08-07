//
//  SPAsyncVideoReader.h
//  Pods
//
//  Created by Sergey Pimenov on 20/10/2016.
//
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

@class SPAsyncVideoReader;

NS_ASSUME_NONNULL_BEGIN

@interface SPAsyncVideoReader : NSObject

@property (nonatomic, assign) CGSize assetNaturalSize;
@property (atomic, strong, readonly) dispatch_queue_t readingQueue;
@property (readonly, getter=isReadyForMoreMediaData) BOOL readyForMoreMediaData;

- (instancetype)initWithAssetURL:(NSURL *)assetURL;

- (void)startReadingWithCompletion:(dispatch_block_t)completion;
- (void)cancelReading;

- (void)resetToBegining;
- (CMSampleBufferRef)copyNextSampleBuffer;

@end

NS_ASSUME_NONNULL_END
