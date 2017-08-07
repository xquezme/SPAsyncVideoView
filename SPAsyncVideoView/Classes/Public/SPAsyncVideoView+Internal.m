//
//  SPAsyncVideoView+Internal.m
//  Pods
//
//  Created by Sergey Pimenov on 26/10/2016.
//
//

#import "SPAsyncVideoView+Internal.h"

#import "SPAsyncVideoReader.h"
#import "SPAsyncVideoRenderer.h"

#import <AVFoundation/AVFoundation.h>

@interface SPAsyncVideoView ()

@property (nonatomic, strong, nullable) SPAsyncVideoReader *assetReader;
@property (nonatomic, strong, nullable) SPAsyncVideoRenderer *renderer;
@property (nonatomic, strong) AVSampleBufferDisplayLayer *displayLayer;

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

- (void)setAssetURL:(NSURL *)assetURL {
    NSAssert([NSThread isMainThread], @"Thread Checker");

    if ((assetURL == nil && _assetURL == nil) || [_assetURL isEqual:assetURL]) {
        return;
    }

    BOOL needToFlush = assetURL == nil || _assetURL != nil;

    _assetURL = assetURL;

    if (needToFlush) {
        [self flushAndStopReading];
    }

    if (self.autoPlay) {
        [self setupWithAsset:assetURL];
    }
}

- (void)setVideoGravity:(SPAsyncVideoViewVideoGravity)videoGravity {
    NSAssert([NSThread isMainThread], @"Thread Checker");

    if (_videoGravity == videoGravity) {
        return;
    }

    _videoGravity = videoGravity;

    switch (videoGravity) {
        case SPAsyncVideoViewVideoGravityResize:
            self.displayLayer.videoGravity = AVLayerVideoGravityResize;
            break;
        case SPAsyncVideoViewVideoGravityResizeAspect:
            self.displayLayer.videoGravity = AVLayerVideoGravityResizeAspect;
            break;
        case SPAsyncVideoViewVideoGravityResizeAspectFill:
            self.displayLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
            break;
        default:
            break;
    }
}

- (void)playVideo {
    NSAssert([NSThread isMainThread], @"Thread Checker");
    NSParameterAssert(self.assetURL);

    [self setupWithAsset:self.assetURL];
}

- (void)stopVideo {
    NSAssert([NSThread isMainThread], @"Thread Checker");

    [self flushAndStopReading];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    self.displayLayer.frame = self.bounds;
}

#pragma mark - Private API

- (void)flushAndStopReading {
    [self.assetReader cancelReading];
    self.assetReader = nil;

    [self.renderer cancelRendering];
    self.renderer = nil;
}

- (void)forceRestart {
    if (self.assetURL != nil) {
        [self setupWithAsset:self.assetURL];
    }
}

- (void)commonInit {
    _displayLayer = [AVSampleBufferDisplayLayer layer];
    [self.layer addSublayer:self.displayLayer];
    self.backgroundColor = [UIColor blackColor];

    self.videoGravity = SPAsyncVideoViewVideoGravityResizeAspectFill;
    self.autoPlay = YES;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
}

- (void)setupWithAsset:(NSURL *)assetURL {
    NSAssert([NSThread isMainThread], @"Thread checker");

    if (assetURL == nil) {
        return;
    }

    SPAsyncVideoReader *assetReader = [[SPAsyncVideoReader alloc] initWithAssetURL:self.assetURL];

    __weak typeof (self) weakSelf = self;
    [assetReader startReadingWithCompletion:^{
        NSAssert([assetURL isEqual:weakSelf.assetURL], @"Asset url inconsistency");

        SPAsyncVideoReader *assetReader = weakSelf.assetReader;
        weakSelf.assetReader = nil;
        [weakSelf.renderer cancelRendering];
        weakSelf.renderer = nil;

        weakSelf.renderer = [[SPAsyncVideoRenderer alloc] initWithAssetReader:assetReader displayLayer:weakSelf.displayLayer];

        if ([weakSelf.delegate respondsToSelector:@selector(asyncVideoViewWillBeginPlaying:assetNaturalSize:)]) {
            [weakSelf.delegate asyncVideoViewWillBeginPlaying:weakSelf assetNaturalSize:weakSelf.assetReader.assetNaturalSize];
        }

        [weakSelf.renderer startRendering];
    }];

    self.assetReader = assetReader;
}

- (void)notifyDelegateAboutError:(nonnull NSError *)error {
    if ([self.delegate respondsToSelector:@selector(asyncVideoView:didOccurError:)]) {
        [self.delegate asyncVideoView:self didOccurError:error];
    }
}

- (void)applicationDidEnterBackground:(NSNotification *)notificaiton {
    [self stopVideo];
}

- (void)applicationWillEnterForeground:(NSNotification *)notification {
    [self forceRestart];
}

- (void)dealloc {
    [self.assetReader cancelReading];
    [self.renderer cancelRendering];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidEnterBackgroundNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillEnterForegroundNotification
                                                  object:nil];
}

@end
