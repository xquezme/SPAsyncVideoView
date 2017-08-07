//
//  SPAsyncVideoReader.m
//  Pods
//
//  Created by Sergey Pimenov on 20/10/2016.
//
//

#import "SPAsyncVideoReader.h"

#import <AVFoundation/AVFoundation.h>


@interface SPAsyncVideoReader ()

@property (atomic, strong) AVURLAsset *nativeAsset;
@property (atomic, strong) AVAssetReader *nativeAssetReader;
@property (atomic, strong) AVAssetReaderTrackOutput *nativeOutVideo;
@property (nonatomic, strong) NSURL *assetURL;
@property (nonatomic, copy) dispatch_block_t completion;

@end


@implementation SPAsyncVideoReader

- (instancetype)initWithAssetURL:(NSURL *)assetURL {
    self = [super init];

    if (self) {
        _assetURL = assetURL;
        _readingQueue = dispatch_queue_create("com.SPAsyncVideoReader", DISPATCH_QUEUE_SERIAL);
    }

    return self;
}

#pragma mark - Private API

- (void)startReadingNativeAsset:(AVURLAsset *)nativeAsset {
    NSError *error = nil;

    AVAssetReader *assetReader = [[AVAssetReader alloc] initWithAsset:(AVAsset *)nativeAsset error:&error];

    if (error != nil) {
        return;
    }

    NSArray<AVAssetTrack *> *videoTracks = [nativeAsset tracksWithMediaType:AVMediaTypeVideo];
    AVAssetTrack *videoTrack = videoTracks.firstObject;

    if (videoTrack == nil) {
        return;
    }

    NSDictionary *outputSettings = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)};

    AVAssetReaderTrackOutput *outVideo = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:videoTrack outputSettings:outputSettings];
    outVideo.supportsRandomAccess = YES;
    [assetReader addOutput:outVideo];

    if (![assetReader startReading]) {
        return;
    }

    CGSize assetVideoSize = videoTrack.naturalSize;

    dispatch_sync(dispatch_get_main_queue(), ^{
        self.nativeAssetReader = assetReader;
        self.nativeOutVideo = outVideo;
        self.nativeAsset = nativeAsset;
        self.assetNaturalSize = assetVideoSize;

        if (self.completion) {
            self.completion();
        }
    });
}

#pragma mark - Public API

- (void)startReadingWithCompletion:(dispatch_block_t)completion {
    self.completion = completion;

    __weak typeof (self) weakSelf = self;
    dispatch_async(self.readingQueue, ^{
        AVURLAsset *asset = [AVURLAsset assetWithURL:weakSelf.assetURL];

        NSArray<NSString *> *keys = @[ @"tracks", @"playable", @"duration" ];

        [asset loadValuesAsynchronouslyForKeys:keys completionHandler:^{
            if (weakSelf == nil) {
                return;
            }

            dispatch_async(weakSelf.readingQueue, ^{
                if (weakSelf == nil) {
                    return;
                }

                NSError *error = nil;

                AVKeyValueStatus status = [asset statusOfValueForKey:@"tracks" error:&error];
                if (error != nil || status != AVKeyValueStatusLoaded) {
                    return;
                }

                status = [asset statusOfValueForKey:@"playable" error:&error];

                if (error != nil || status != AVKeyValueStatusLoaded) {
                    return;
                }

                status = [asset statusOfValueForKey:@"duration" error:&error];

                if (error != nil || status != AVKeyValueStatusLoaded) {
                    return;
                }

                [weakSelf startReadingNativeAsset:asset];
            });
        }];
    });
}

- (void)cancelReading {
    [self.nativeAsset cancelLoading];
    [self.nativeAssetReader cancelReading];
    self.completion = nil;
}

- (void)resetToBegining {
    NSValue *beginingTimeRangeValue = [NSValue valueWithCMTimeRange:self.nativeOutVideo.track.timeRange];
    [self.nativeOutVideo resetForReadingTimeRanges:@[ beginingTimeRangeValue ]];
}

- (CMSampleBufferRef)copyNextSampleBuffer {
    return [self.nativeOutVideo copyNextSampleBuffer];
}

- (BOOL)isReadyForMoreMediaData {
    return self.nativeAssetReader.status == AVAssetReaderStatusReading;
}

- (void)dealloc {
    [self.nativeAsset cancelLoading];
    [self.nativeAssetReader cancelReading];
}

@end
