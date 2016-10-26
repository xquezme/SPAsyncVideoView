//
//  SPAsyncVideoView+Internal.m
//  Pods
//
//  Created by Sergey Pimenov on 26/10/2016.
//
//

#import "SPAsyncVideoView+Internal.h"

#import "SPAsyncVideoAsset.h"
#import "SPAsyncVideoReader.h"
#import "SPAsyncGIFConverter.h"

#import <AVFoundation/AVFoundation.h>
#import <CommonCrypto/CommonDigest.h>

NS_INLINE NSString * cachedFilePathWithGifURL(NSURL *gifURL) {
    if (gifURL == nil) {
        return nil;
    }

    const char *cstr = [gifURL.path UTF8String];
    unsigned char result[16];
    CC_MD5(cstr, (CC_LONG)strlen(cstr), result);

    return [NSString stringWithFormat:
            @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X.mp4",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]];
}

@interface SPAsyncVideoView () <SPAsyncVideoReaderDelegate>

@property (atomic, assign) BOOL canRenderAsset;
@property (atomic, strong) dispatch_queue_t workingQueue;
@property (nonatomic, strong) SPAsyncVideoReader *assetReader;
@property (atomic, strong) AVSampleBufferDisplayLayer *displayLayer;

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
    [super awakeFromNib];

    [self commonInit];
}

- (void)setAsset:(nullable SPAsyncVideoAsset *)asset {
    NSAssert([NSThread isMainThread], @"Thread Checker");

    if (asset == nil) {
        [self setOverlayHidden:NO];
    }

    if ([_asset isEqual:asset]) {
        return;
    }

    BOOL needToFlush = asset == nil || _asset != nil;

    _asset = asset;

    __weak typeof (self) weakSelf = self;
    dispatch_async(self.workingQueue, ^{
        if (needToFlush) {
            [weakSelf flushAndStopReading];
        }

        if (weakSelf.autoPlay) {
            [weakSelf setupWithAsset:asset];
        }
    });
}

- (void)setVideoGravity:(SPAsyncVideoViewVideoGravity)videoGravity {
    if (_videoGravity == videoGravity) {
        return;
    }

    _videoGravity = videoGravity;

    AVSampleBufferDisplayLayer *displayLayer = self.displayLayer;

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
    NSAssert([NSThread mainThread] == [NSThread mainThread], @"Thread checker");
    NSParameterAssert(self.asset);

    __weak typeof (self) weakSelf = self;
    dispatch_async(self.workingQueue, ^{
        [weakSelf setupWithAsset:weakSelf.asset];
    });
}

- (void)stopVideo {
    NSAssert([NSThread isMainThread], @"Thread Checker");

    __weak typeof (self) weakSelf = self;
    dispatch_async(self.workingQueue, ^{
        [weakSelf flushAndStopReading];
    });
}

- (void)layoutSubviews {
    [super layoutSubviews];

    self.displayLayer.frame = self.bounds;
    self.overlayView.frame = self.bounds;
}

#pragma mark - Private API

- (void)setOverlayHidden:(BOOL)hidden {
    if ([NSThread mainThread] == [NSThread currentThread]) {
        self.overlayView.hidden = hidden;
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            self.overlayView.hidden = hidden;
        });
    }
}

- (void)internalFlush {
    if ([self.delegate respondsToSelector:@selector(asyncVideoViewWillFlush:)]) {
        [self.delegate asyncVideoViewWillFlush:self];
    }

    AVSampleBufferDisplayLayer *displayLayer = [self displayLayer];

    [displayLayer stopRequestingMediaData];
    [displayLayer flushAndRemoveImage];

    if ([self.delegate respondsToSelector:@selector(asyncVideoViewDidFlush:)]) {
        [self.delegate asyncVideoViewDidFlush:self];
    }
}

- (void)flushAndStopReading {
    [self internalFlush];
    self.assetReader.delegate = nil;
    self.assetReader = nil;
    [self setOverlayHidden:NO];
}

- (void)forceRestart {
    SPAsyncVideoAsset *asset = self.asset;
    __weak typeof (self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        weakSelf.asset = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.asset = asset;
        });
    });
}

- (void)commonInit {
    _displayLayer = [AVSampleBufferDisplayLayer layer];
    [self.layer addSublayer:self.displayLayer];

    _overlayView = [UIView new];
    self.overlayView.backgroundColor = [UIColor blackColor];
    [self addSubview:self.overlayView];

    self.workingQueue = dispatch_queue_create("com.com.SPAsyncVideoViewQueue", DISPATCH_QUEUE_SERIAL);
    self.backgroundColor = [UIColor blackColor];

    self.actionAtItemEnd = SPAsyncVideoViewActionAtItemEndRepeat;
    self.videoGravity = SPAsyncVideoViewVideoGravityResizeAspectFill;
    self.autoPlay = YES;
    self.canRenderAsset = [UIApplication sharedApplication].applicationState != UIApplicationStateBackground;
    self.restartPlaybackOnEnteringForeground = YES;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
}

- (void)setupWithAsset:(SPAsyncVideoAsset *)asset {
    if (asset == nil) {
        return;
    }

    if (asset.type == SPAsyncVideoAssetTypeGIF && asset.finalURL == nil) {
        __weak typeof (self) weakSelf = self;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            NSURL *outputURL = [weakSelf cachedMP4FileURLWithGifURL:asset.originalURL];
            @synchronized ([NSFileManager class]) {
                if ([[NSFileManager defaultManager] fileExistsAtPath:outputURL.path]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        asset.finalURL = outputURL;
                        if ([weakSelf.asset isEqual:asset]) {
                            [weakSelf setupWithAsset:asset];
                        }
                    });
                } else {
                    SPAsyncGIFConverter *converter = [[SPAsyncGIFConverter alloc] initWithGifURL:asset.originalURL];
                    [converter startWithOutputURL:outputURL completion:^(NSURL * _Nullable url,
                                                                         NSError * _Nullable error) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            asset.finalURL = outputURL;
                            if ([weakSelf.asset isEqual:asset]) {
                                [weakSelf setupWithAsset:asset];
                            }
                        });
                    }];
                }
            }
        });
    }

    if (asset.finalURL == nil) {
        return;
    }

    __weak typeof (self) weakSelf = self;
    dispatch_async(self.workingQueue, ^{
        weakSelf.assetReader = [[SPAsyncVideoReader alloc] initWithAsset:weakSelf.asset
                                                            readingQueue:weakSelf.workingQueue];
        weakSelf.assetReader.delegate = weakSelf;
        [weakSelf.assetReader startReading];
    });
}

- (void)setCurrentControlTimebaseWithTime:(CMTime)time {
    AVSampleBufferDisplayLayer *displayLayer = self.displayLayer;

    CMTimebaseRef controlTimebase;
    CMTimebaseCreateWithMasterClock(CFAllocatorGetDefault(),
                                    CMClockGetHostTimeClock(),
                                    &controlTimebase);

    displayLayer.controlTimebase = controlTimebase;

    CMTimebaseSetTime(displayLayer.controlTimebase, time);
    CMTimebaseSetRate(displayLayer.controlTimebase, 1.);
}

- (void)startReading {
    __weak typeof (self) weakSelf = self;
    __block BOOL isFirstFrame = YES;
    dispatch_queue_t readingQueue = self.workingQueue;

    dispatch_async(readingQueue, ^{
        [weakSelf setCurrentControlTimebaseWithTime:CMTimeMake(0., 1.)];
        [weakSelf.displayLayer requestMediaDataWhenReadyOnQueue:readingQueue usingBlock:^{
            AVSampleBufferDisplayLayer *displayLayer = weakSelf.displayLayer;
            SPAsyncVideoReader *assetReader = weakSelf.assetReader;

            if (![assetReader isReadyForMoreMediaData]) {
                return;
            }

            if (!displayLayer.isReadyForMoreMediaData
                || displayLayer.status == AVQueuedSampleBufferRenderingStatusFailed) {
                return;
            }

            if (!weakSelf.canRenderAsset) {
                return;
            }

            CMSampleBufferRef sampleBuffer = [assetReader copyNextSampleBuffer];

            if (sampleBuffer != NULL) {
                if (isFirstFrame && [weakSelf.delegate respondsToSelector:@selector(asyncVideoViewWillRenderFirstFrame:)]) {
                    [weakSelf.delegate asyncVideoViewWillRenderFirstFrame:weakSelf];
                }

                [displayLayer enqueueSampleBuffer:sampleBuffer];

                CFRelease(sampleBuffer);

                if (isFirstFrame && [weakSelf.delegate respondsToSelector:@selector(asyncVideoViewDidRenderFirstFrame:)]) {
                    [weakSelf.delegate asyncVideoViewDidRenderFirstFrame:weakSelf];
                }

                if (isFirstFrame) {
                    [weakSelf setOverlayHidden:YES];
                }

                isFirstFrame = NO;

                return;
            }

            if ([weakSelf.delegate respondsToSelector:@selector(asyncVideoViewDidPlayToEnd:)]) {
                [weakSelf.delegate asyncVideoViewDidPlayToEnd:weakSelf];
            }

            switch (weakSelf.actionAtItemEnd) {
                case SPAsyncVideoViewActionAtItemEndNone: {
                    [weakSelf flushAndStopReading];
                    break;
                }
                case SPAsyncVideoViewActionAtItemEndRepeat: {
                    [displayLayer flush];
                    [weakSelf setCurrentControlTimebaseWithTime:CMTimeMake(0., 1.)];
                    [assetReader resetToBegining];
                    break;
                }
                default:
                    break;
            }
        }];
    });
}

- (void)notifyDelegateAboutError:(nonnull NSError *)error {
    if ([self.delegate respondsToSelector:@selector(asyncVideoView:didOccurError:)]) {
        [self.delegate asyncVideoView:self didOccurError:error];
    }
}

- (void)applicationDidEnterBackground:(NSNotification *)notificaiton {
    self.canRenderAsset = NO;

    [self stopVideo];
}

- (void)applicationWillEnterForeground:(NSNotification *)notification {
    self.canRenderAsset = YES;

    if (self.restartPlaybackOnEnteringForeground) {
        [self forceRestart];
    }
}

- (NSURL *)cachedMP4FileURLWithGifURL:(NSURL *)url {
    NSString *outputPath = NSTemporaryDirectory();

    outputPath = [outputPath stringByAppendingString:@"SPAsyncVideoView/"];
    outputPath = [outputPath stringByAppendingString:cachedFilePathWithGifURL(url)];

    return [NSURL fileURLWithPath:outputPath];
}

#pragma mark - SPAsyncVideoReaderDelegate

- (void)asyncVideoReaderReady:(SPAsyncVideoReader *)asyncVideoReader {
    if ([self.delegate respondsToSelector:@selector(asyncVideoView:didReceiveAssetNaturalSize:)]) {
        [self.delegate asyncVideoView:self didReceiveAssetNaturalSize:asyncVideoReader.assetNaturalSize];
    }

    [self startReading];
}

- (void)asyncVideoReaderDidFailWithError:(NSError *)error {
    self.assetReader.delegate = nil;
    self.assetReader = nil;

    if ([self.delegate respondsToSelector:@selector(asyncVideoView:didOccurError:)]) {
        [self.delegate asyncVideoView:self didOccurError:error];
    }
}

- (void)dealloc {
    self.delegate = nil;

    dispatch_sync(self.workingQueue, ^{
        [self internalFlush];
        self.assetReader = nil;
    });

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidEnterBackgroundNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillEnterForegroundNotification
                                                  object:nil];
}

@end
