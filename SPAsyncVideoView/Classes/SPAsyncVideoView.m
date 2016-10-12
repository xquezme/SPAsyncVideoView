//
//  SPAsyncVideoView.m
//  Pods
//
//  Created by Sergey Pimenov on 14/07/16.
//
//

#import "SPAsyncVideoView.h"

#import "SPAsyncVideoAsset.h"
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

@interface SPAsyncVideoView ()

@property (atomic, strong) dispatch_queue_t workingQueue;
@property (atomic, strong) AVAssetReader *assetReader;
@property (nonatomic, strong) AVURLAsset *nativeAsset;
@property (atomic, assign) BOOL canRenderAsset;
@property (nonatomic, assign) CGSize assetNaturalSize;

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
    if (asset == nil) {
        [self setOverlayHidden:NO];
    }

    __weak typeof (self) weakSelf = self;
    dispatch_async(self.workingQueue, ^{
        __strong typeof (weakSelf) strongSelf = weakSelf;

        if (strongSelf == nil) {
            return;
        }

        if ([strongSelf->_asset isEqual:asset]) {
            return;
        }

        dispatch_sync(dispatch_get_main_queue(), ^{
            strongSelf.assetNaturalSize = CGSizeMake(UIViewNoIntrinsicMetric, UIViewNoIntrinsicMetric);
        });
        
        if (asset == nil) {
            strongSelf->_asset = nil;
            [strongSelf flushAndStopReading];
            return;
        }

        if (strongSelf->_asset != nil) {
            [strongSelf flushAndStopReading];
        }

        strongSelf->_asset = asset;
        
        if (strongSelf.autoPlay) {
            [strongSelf setupWithAsset:asset];
        }
    });
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
    NSAssert([NSThread mainThread] == [NSThread mainThread], @"Thread checker");

    __weak typeof (self) weakSelf = self;
    dispatch_async(self.workingQueue, ^{
        __strong typeof (self) strongSelf = weakSelf;

        if (strongSelf == nil) {
            return;
        }

        [strongSelf setupWithAsset:strongSelf.asset];
    });
}

- (void)stopVideo {
    NSAssert([NSThread mainThread] == [NSThread mainThread], @"Thread checker");

    __weak typeof (self) weakSelf = self;
    dispatch_async(self.workingQueue, ^{
        [weakSelf flushAndStopReading];
    });
}

- (void)layoutSubviews {
    [super layoutSubviews];

    self.overlayView.frame = self.bounds;
}

- (CGSize)intrinsicContentSize {
    return self.assetNaturalSize;
}

#pragma mark - Private API

- (void)setAssetNaturalSize:(CGSize)assetNaturalSize {
    _assetNaturalSize = assetNaturalSize;
    [self invalidateIntrinsicContentSize];
}

- (void)setOverlayHidden:(BOOL)hidden {
    if ([NSThread mainThread] == [NSThread currentThread]) {
        self.overlayView.hidden = hidden;
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            self.overlayView.hidden = hidden;
        });
    }
}

- (void)flush {
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
    [self.nativeAsset cancelLoading];

    if (self.assetReader.status == AVAssetReaderStatusReading) {
        [self.assetReader cancelReading];
        self.assetReader = nil;
    }

    [self flush];

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
    _overlayView = [UIView new];
    self.overlayView.backgroundColor = [UIColor blackColor];
    [self addSubview:self.overlayView];

    _assetNaturalSize = CGSizeMake(UIViewNoIntrinsicMetric, UIViewNoIntrinsicMetric);

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

+ (Class)layerClass {
    return [AVSampleBufferDisplayLayer class];
}

- (AVSampleBufferDisplayLayer *)displayLayer {
    @synchronized (self.layer) {
        return (AVSampleBufferDisplayLayer *)self.layer;
    }
}

- (void)setupWithAsset:(SPAsyncVideoAsset *)asset {
    if (asset == nil) {
        return;
    }

    NSURL *url = asset.finalURL;

    if (asset.type == SPAsyncVideoAssetTypeGIF && url == nil) {
        NSURL *outputURL = [self cachedMP4FileURLWithGifURL:asset.originalURL];

        @synchronized ([NSFileManager class]) {
            if ([[NSFileManager defaultManager] fileExistsAtPath:outputURL.path]) {
                asset.finalURL = outputURL;
                url = outputURL;
            } else {
                SPAsyncGIFConverter *converter = [[SPAsyncGIFConverter alloc] initWithGifURL:asset.originalURL];

                __weak typeof (self) weakSelf = self;
                [converter startWithOutputURL:outputURL completion:^(NSURL * _Nullable url,
                                                                     NSError * _Nullable error) {
                    if (weakSelf.workingQueue == NULL) {
                        return;
                    }

                    dispatch_async(weakSelf.workingQueue, ^{
                        asset.finalURL = outputURL;
                        if ([weakSelf.asset isEqual:asset]) {
                            [weakSelf setupWithAsset:asset];
                        }
                    });
                }];

                return;
            }
        }
    }

    if (url == nil) {
        return;
    }

    self.nativeAsset = [AVURLAsset assetWithURL:url];

    NSArray<NSString *> *keys = @[@"tracks", @"playable", @"duration"];

    __weak typeof (self) weakSelf = self;
    [self.nativeAsset loadValuesAsynchronouslyForKeys:keys completionHandler:^{
        if (weakSelf.workingQueue == NULL) {
            return;
        }

        dispatch_async(weakSelf.workingQueue, ^{
            __strong typeof (self) strongSelf = weakSelf;

            if (strongSelf == nil) {
                return;
            }

            SPAsyncVideoAsset *currentAsset = strongSelf.asset;
            AVURLAsset *currentAVAsset = strongSelf.nativeAsset;
            NSError *error = nil;

            AVKeyValueStatus status = [currentAVAsset statusOfValueForKey:@"tracks" error:&error];
            if (error != nil || status != AVKeyValueStatusLoaded) {
                [strongSelf notifyDelegateAboutError:error];
                return;
            }

            status = [currentAVAsset statusOfValueForKey:@"playable" error:&error];

            if (error != nil || status != AVKeyValueStatusLoaded) {
                [strongSelf notifyDelegateAboutError:error];
                return;
            }

            status = [currentAVAsset statusOfValueForKey:@"duration" error:&error];

            if (error != nil || status != AVKeyValueStatusLoaded) {
                [strongSelf notifyDelegateAboutError:error];
                return;
            }

            NSDictionary *outputSettings = currentAsset.outputSettings;

            if (currentAVAsset == nil || ![currentAsset.finalURL isEqual:url]) {
                return;
            }

            [strongSelf setupWithAVURLAsset:currentAVAsset
                             outputSettings:outputSettings];
        });
    }];
}

- (void)setupWithAVURLAsset:(AVURLAsset *)asset outputSettings:(NSDictionary *)outputSettings {
    NSError *error = nil;

    AVAssetReader *assetReader = [[AVAssetReader alloc] initWithAsset:(AVAsset *)asset
                                                                error:&error];

    if (error != nil) {
        [self notifyDelegateAboutError:error];
        return;
    }

    NSArray<AVAssetTrack *> *videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    AVAssetTrack *videoTrack = videoTracks.firstObject;

    if (videoTrack == nil) {
        NSError *error = [NSError errorWithDomain:AVFoundationErrorDomain
                                             code:AVErrorOperationNotSupportedForAsset
                                         userInfo:nil];
        [self notifyDelegateAboutError:error];
        return;
    }

    CGSize assetNatualSize = videoTrack.naturalSize;

    if ([self.delegate respondsToSelector:@selector(asyncVideoView:didReceiveAssetNaturalSize:)]) {
        [self.delegate asyncVideoView:self didReceiveAssetNaturalSize:assetNatualSize];
    }

    dispatch_sync(dispatch_get_main_queue(), ^{
        self.assetNaturalSize = assetNatualSize;
    });

    AVAssetReaderTrackOutput *outVideo = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:videoTrack
                                                                                    outputSettings:outputSettings];

    [assetReader addOutput:outVideo];

    [self startReadingWithReader:assetReader];
}

- (void)setCurrentControlTimebaseWithTime:(CMTime)time {
    AVSampleBufferDisplayLayer *displayLayer = [self displayLayer];

    CMTimebaseRef controlTimebase;
    CMTimebaseCreateWithMasterClock(CFAllocatorGetDefault(),
                                    CMClockGetHostTimeClock(),
                                    &controlTimebase);

    displayLayer.controlTimebase = controlTimebase;

    CMTimebaseSetTime(displayLayer.controlTimebase, time);
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

    [self setCurrentControlTimebaseWithTime:CMTimeMake(0., 1.)];

    __weak typeof (self) weakSelf = self;

    __block BOOL isFirstFrame = YES;
    [[self displayLayer] requestMediaDataWhenReadyOnQueue:self.workingQueue usingBlock:^{
        __strong typeof (weakSelf) strongSelf = weakSelf;

        if (strongSelf == nil) {
            return;
        }

        @synchronized (strongSelf) {
            AVSampleBufferDisplayLayer *displayLayer = [strongSelf displayLayer];

            if (!displayLayer.isReadyForMoreMediaData || displayLayer.status == AVQueuedSampleBufferRenderingStatusFailed) {
                return;
            }

            if (assetReader.status != AVAssetReaderStatusReading) {
                return;
            }

            if (!strongSelf.canRenderAsset) {
                return;
            }

            CMSampleBufferRef sampleBuffer = [outVideo copyNextSampleBuffer];
            if (sampleBuffer != NULL) {
                if (isFirstFrame && [strongSelf.delegate respondsToSelector:@selector(asyncVideoViewWillRenderFirstFrame:)]) {
                    [strongSelf.delegate asyncVideoViewWillRenderFirstFrame:strongSelf];
                }

                dispatch_sync(dispatch_get_main_queue(), ^{
                    [displayLayer enqueueSampleBuffer:sampleBuffer];
                });

                CFRelease(sampleBuffer);

                if (isFirstFrame && [strongSelf.delegate respondsToSelector:@selector(asyncVideoViewDidRenderFirstFrame:)]) {
                    [strongSelf.delegate asyncVideoViewDidRenderFirstFrame:strongSelf];
                }

                if (isFirstFrame) {
                    [strongSelf setOverlayHidden:YES];
                }

                isFirstFrame = NO;

                return;
            }

            if ([strongSelf.delegate respondsToSelector:@selector(asyncVideoViewDidPlayToEnd:)]) {
                [strongSelf.delegate asyncVideoViewDidPlayToEnd:strongSelf];
            }

            switch (strongSelf.actionAtItemEnd) {
                case SPAsyncVideoViewActionAtItemEndNone: {
                    [strongSelf flush];
                    strongSelf.assetReader = nil;
                    break;
                }
                case SPAsyncVideoViewActionAtItemEndRepeat: {
                    CMTimeRange timeRange = outVideo.track.timeRange;

                    if (!CMTimeRangeEqual(timeRange, kCMTimeRangeInvalid)) {
                        [displayLayer flush];
                        [strongSelf setCurrentControlTimebaseWithTime:CMTimeMake(0., 1.)];
                        NSValue *beginingTimeRangeValue = [NSValue valueWithCMTimeRange:outVideo.track.timeRange];
                        [outVideo resetForReadingTimeRanges:@[beginingTimeRangeValue]];
                    } else {
                        [strongSelf forceRestart];
                    }
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

- (void)dealloc {
    @synchronized (self) {
        [self.nativeAsset cancelLoading];

        if (self.assetReader.status == AVAssetReaderStatusReading) {
            [self.assetReader cancelReading];
        }

        [[self displayLayer] stopRequestingMediaData];
    }

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidEnterBackgroundNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillEnterForegroundNotification
                                                  object:nil];
}

@end
