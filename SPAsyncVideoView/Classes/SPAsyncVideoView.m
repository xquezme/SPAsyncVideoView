//
//  SPAsyncVideoView.m
//  Pods
//
//  Created by Sergey Pimenov on 14/07/16.
//
//

#import "SPAsyncVideoView.h"

#import "SPAsyncVideoAsset.h"

#import <AVFoundation/AVFoundation.h>

@interface SPAsyncVideoView ()

@property (nonatomic, strong) dispatch_queue_t workingQueue;
@property (nonatomic, strong) AVAssetReader *assetReader;

@end

@implementation SPAsyncVideoView

#pragma mark - Public API

- (instancetype)init {
    self = [super init];

    if (self) {
        [self commonInit];
    }

    return self;
}

- (void)awakeFromNib {
    [self commonInit];
}

- (void)setAsset:(nullable SPAsyncVideoAsset *)asset {
    if ([_asset isEqual:asset]) {
        return;
    }

    if (asset == nil) {
        _asset = nil;
        [self stopVideo];
        return;
    }

    _asset = asset;

    if (self.autoPlay) {
        [self playVideo];
    }
}

- (void)setVideoGravity:(SPAsyncVideoViewVideoGravity)videoGravity {
    if (_videoGravity == videoGravity) {
        return;
    }

    _videoGravity = videoGravity;

    AVSampleBufferDisplayLayer *displayLayer = [self displayLayer];

    switch (videoGravity) {
        case SPAsyncVideoViewVideoGravityResize:
            displayLayer.videoGravity = AVLayerVideoGravityResize;
            break;
        case SPAsyncVideoViewVideoGravityResizeAspect:
            displayLayer.videoGravity = AVLayerVideoGravityResizeAspect;
            break;
        case SPAsyncVideoViewVideoGravityResizeAspectFill:
            displayLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
            break;
        default:
            break;
    }
}

- (void)playVideo {
    __weak typeof (self) weakSelf = self;
    dispatch_async(self.workingQueue, ^{
        [weakSelf setupWithAsset:weakSelf.asset];
    });
}

- (void)stopVideo {
    __weak typeof (self) weakSelf = self;
    dispatch_async(self.workingQueue, ^{
        [weakSelf flushSync];
    });
}

#pragma mark - Private API

- (void)flushSync {
    AVSampleBufferDisplayLayer *displayLayer = [self displayLayer];
    [displayLayer flushAndRemoveImage];
    [displayLayer stopRequestingMediaData];
    if (self.assetReader.status == AVAssetReaderStatusReading) {
        [self.assetReader cancelReading];
        self.assetReader = nil;
    }
}

- (void)commonInit {
    self.workingQueue = dispatch_queue_create("com.com.SPAsyncVideoViewQueue", NULL);
    self.actionAtItemEnd = SPAsyncVideoViewActionAtItemEndRepeat;
    self.videoGravity = SPAsyncVideoViewVideoGravityResizeAspectFill;
    self.backgroundColor = [UIColor blackColor];
    self.autoPlay = YES;
}

+ (Class)layerClass {
    return [AVSampleBufferDisplayLayer class];
}

- (AVSampleBufferDisplayLayer *)displayLayer {
    return (AVSampleBufferDisplayLayer *)self.layer;
}

- (void)setupWithAsset:(SPAsyncVideoAsset *)asset {
    if (asset.asset == nil) {
        NSParameterAssert(asset.url);
        asset.asset = [AVURLAsset assetWithURL:asset.url];
    }
    
    NSArray<NSString *> *keys = @[@"tracks", @"playable", @"duration"];

    __weak typeof (self) weakSelf = self;
    [self.asset.asset loadValuesAsynchronouslyForKeys:keys completionHandler:^{
        @synchronized (self.workingQueue) {
            if (weakSelf.workingQueue == NULL) {
                return;
            }

            dispatch_async(weakSelf.workingQueue, ^{
                AVAsset *currentAVAsset = weakSelf.asset.asset;
                NSDictionary *outputSettings = weakSelf.asset.outputSettings;

                if (currentAVAsset == nil || ![weakSelf.asset isEqual:asset]) {
                    return;
                }

                NSError *error = nil;
                AVAssetReader *assetReader = [[AVAssetReader alloc] initWithAsset:currentAVAsset
                                                                            error:&error];

                if (error != nil) {
                    [weakSelf notifyDelegateAboutError:error];
                    return;
                }

                NSArray<AVAssetTrack *> *videoTracks = [currentAVAsset tracksWithMediaType:AVMediaTypeVideo];
                AVAssetTrack *videoTrack = videoTracks.firstObject;
                AVAssetReaderTrackOutput *outVideo = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:videoTrack
                                                                                                outputSettings:outputSettings];

                [assetReader addOutput:outVideo];

                [weakSelf startReadingWithReader:assetReader];
            });
        }
    }];
}

- (void)resetControlTimeWithLayer:(AVSampleBufferDisplayLayer *)displayLayer {
    CMTimebaseRef controlTimebase;
    CMTimebaseCreateWithMasterClock(CFAllocatorGetDefault(),
                                    CMClockGetHostTimeClock(),
                                    &controlTimebase);

    displayLayer.controlTimebase = controlTimebase;

    CMTimebaseSetTime(displayLayer.controlTimebase, CMTimeMake(0., 1.));
    CMTimebaseSetRate(displayLayer.controlTimebase, 1.);
}

- (void)startReadingWithReader:(AVAssetReader *)assetReader {
    AVAssetReaderTrackOutput *outVideo = (AVAssetReaderTrackOutput *)assetReader.outputs.firstObject;
    outVideo.supportsRandomAccess = YES;

    if (![assetReader startReading]) {
        NSError *error = [NSError errorWithDomain:AVFoundationErrorDomain
                                             code:AVErrorOperationNotSupportedForAsset
                                         userInfo:nil];
        [self notifyDelegateAboutError:error];
        return;
    }

    _assetReader = assetReader;

    AVSampleBufferDisplayLayer *displayLayer = [self displayLayer];
    [self resetControlTimeWithLayer:displayLayer];

    __weak typeof (self) weakSelf = self;
    [displayLayer requestMediaDataWhenReadyOnQueue:self.workingQueue usingBlock:^{
        __strong typeof (weakSelf) strongSelf = weakSelf;

        @synchronized (strongSelf) {
            if (!displayLayer.isReadyForMoreMediaData) {
                return;
            }

            if (assetReader.status != AVAssetReaderStatusReading) {
                return;
            }

            CMSampleBufferRef sampleBuffer = [outVideo copyNextSampleBuffer];
            if (sampleBuffer != NULL) {
                [displayLayer enqueueSampleBuffer:sampleBuffer];
                CFRelease(sampleBuffer);
                return;
            }

            if ([weakSelf.delegate respondsToSelector:@selector(asyncVideoViewDidPlayToEnd:)]) {
                [weakSelf.delegate asyncVideoViewDidPlayToEnd:weakSelf];
            }

            switch (strongSelf.actionAtItemEnd) {
                case SPAsyncVideoViewActionAtItemEndNone: {
                    [displayLayer flushAndRemoveImage];
                    [displayLayer stopRequestingMediaData];
                    weakSelf.assetReader = nil;
                    break;
                }
                case SPAsyncVideoViewActionAtItemEndRepeat: {
                    [displayLayer flushAndRemoveImage];
                    [strongSelf resetControlTimeWithLayer:displayLayer];
                    NSValue *beginingTimeRangeValue = [NSValue valueWithCMTimeRange:outVideo.track.timeRange];
                    [outVideo resetForReadingTimeRanges:@[beginingTimeRangeValue]];
                    sampleBuffer = [outVideo copyNextSampleBuffer];
                    [displayLayer enqueueSampleBuffer:sampleBuffer];
                    CFRelease(sampleBuffer);
                    break;
                }
                default:
                    break;
            }
        }
    }];
}

- (void)notifyDelegateAboutError:(nonnull NSError *)error {
    if ([self.delegate respondsToSelector:@selector(asyncVideoView:didOccurError:)]) {
        [self.delegate asyncVideoView:self didOccurError:error];
    }
}

- (void)dealloc {
    @synchronized (self) {
        [self flushSync];
    }
}

@end
