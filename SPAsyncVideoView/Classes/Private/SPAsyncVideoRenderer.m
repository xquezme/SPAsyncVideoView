//
//  SPAsyncVideoRenderer.m
//  Pods
//
//  Created by Sergey Pimenov on 04/08/2017.
//
//

#import "SPAsyncVideoRenderer.h"

#import "SPAsyncVideoReader.h"

@interface SPAsyncVideoRenderer ()

@property (nonatomic, strong) dispatch_queue_t queue;
@property (atomic, strong) SPAsyncVideoReader *assetReader;
@property (atomic, assign) BOOL started;

@end


@implementation SPAsyncVideoRenderer

- (instancetype)initWithAssetReader:(SPAsyncVideoReader *)assetReader displayLayer:(AVSampleBufferDisplayLayer *)displayLayer {
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("com.SPAsyncVideoRenderer", DISPATCH_QUEUE_SERIAL);
        _displayLayer = displayLayer;
        _assetReader = assetReader;
    }
    return self;
}

- (void)setCurrentControlTimebaseWithTime:(CMTime)time {
    CMTimebaseRef controlTimebase;
    CMTimebaseCreateWithMasterClock(CFAllocatorGetDefault(), CMClockGetHostTimeClock(), &controlTimebase);
    CMTimebaseSetTime(controlTimebase, time);
    CMTimebaseSetRate(controlTimebase, 1.);

    self.displayLayer.controlTimebase = controlTimebase;

    if (controlTimebase != NULL) {
        CFRelease(controlTimebase);
    }
}

- (void)resetToBegining {
    [self setCurrentControlTimebaseWithTime:CMTimeMake(0., 1.)];
}

- (void)startRendering {
    NSAssert([NSThread isMainThread], @"Thread checker");
    self.started = YES;

    [self setCurrentControlTimebaseWithTime:CMTimeMake(0., 1.)];

    __weak typeof (self) weakSelf = self;
    [self.displayLayer requestMediaDataWhenReadyOnQueue:self.queue usingBlock:^{
        __strong typeof (weakSelf) strongSelf = weakSelf;

        if (strongSelf == nil) {
            return;
        }

        if ([strongSelf.assetReader isReadyForMoreMediaData] == NO) {
            return;
        }

        if ([strongSelf.displayLayer isReadyForMoreMediaData] == NO) {
            return;
        }

        CMSampleBufferRef sampleBuffer = [strongSelf.assetReader copyNextSampleBuffer];

        if (sampleBuffer != NULL) {
            [strongSelf.displayLayer enqueueSampleBuffer:sampleBuffer];
            CFRelease(sampleBuffer);
            return;
        }

        [strongSelf.displayLayer flush];
        [strongSelf.assetReader resetToBegining];
        [strongSelf resetToBegining];
    }];
}

- (void)dealloc {
    [self cancelRendering];

    self.assetReader = nil;
}

- (void)cancelRendering {
    if (self.started) {
        [self.displayLayer stopRequestingMediaData];
        [self.displayLayer flushAndRemoveImage];
    }
}

@end
