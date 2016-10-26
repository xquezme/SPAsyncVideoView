//
//  SPAsyncVideoReader.m
//  Pods
//
//  Created by Sergey Pimenov on 20/10/2016.
//
//

#import "SPAsyncVideoReader.h"

#import <AVFoundation/AVFoundation.h>
#import "SPAsyncVideoAsset.h"


@interface SPAsyncVideoReader ()

@property (atomic, strong) AVURLAsset *nativeAsset;
@property (atomic, strong) AVAssetReader *nativeAssetReader;
@property (atomic, strong) AVAssetReaderTrackOutput *nativeOutVideo;

@end


@implementation SPAsyncVideoReader

- (instancetype)initWithAsset:(SPAsyncVideoAsset *)asset readingQueue:(dispatch_queue_t)readingQueue {
    self = [super init];

    if (self) {
        _asset = asset;
        _readingQueue = readingQueue;
    }

    return self;
}

- (void)startReadingNativeAsset {
    NSError *error = nil;

    AVAssetReader *assetReader = [[AVAssetReader alloc] initWithAsset:(AVAsset *)self.nativeAsset
                                                                error:&error];

    if (error != nil) {
        [self notifyAboutError:error];
        return;
    }

    NSArray<AVAssetTrack *> *videoTracks = [self.nativeAsset tracksWithMediaType:AVMediaTypeVideo];
    AVAssetTrack *videoTrack = videoTracks.firstObject;

    if (videoTrack == nil) {
        NSError *error = [NSError errorWithDomain:AVFoundationErrorDomain
                                             code:AVErrorOperationNotSupportedForAsset
                                         userInfo:nil];
        [self notifyAboutError:error];
        return;
    }

    AVAssetReaderTrackOutput *outVideo = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:videoTrack
                                                                                    outputSettings:self.asset.outputSettings];
    outVideo.supportsRandomAccess = YES;
    [assetReader addOutput:outVideo];

    if (![assetReader startReading]) {
        NSError *error = [NSError errorWithDomain:AVFoundationErrorDomain
                                             code:AVErrorOperationNotSupportedForAsset
                                         userInfo:nil];
        [self notifyAboutError:error];
        return;
    }

    _nativeAssetReader = assetReader;
    _nativeOutVideo = outVideo;

    CGSize assetVideoSize = videoTrack.naturalSize;

    __weak typeof (self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        weakSelf.assetNaturalSize = assetVideoSize;
        [weakSelf.delegate asyncVideoReaderReady:weakSelf];
    });
}

- (void)notifyAboutError:(NSError *)error {
    __weak typeof (self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf.delegate asyncVideoReaderDidFailWithError:error];
    });
}

#pragma mark - Public API

- (void)startReading {
    __weak typeof (self) weakSelf = self;
    dispatch_async(self.readingQueue, ^{
        weakSelf.nativeAsset = [AVURLAsset assetWithURL:weakSelf.asset.finalURL];

        NSArray<NSString *> *keys = @[ @"tracks", @"playable", @"duration" ];

        [weakSelf.nativeAsset loadValuesAsynchronouslyForKeys:keys completionHandler:^{
            if (weakSelf == nil) {
                return;
            }
            dispatch_async(weakSelf.readingQueue, ^{
                if (weakSelf == nil) {
                    return;
                }

                NSError *error = nil;

                AVKeyValueStatus status = [weakSelf.nativeAsset statusOfValueForKey:@"tracks" error:&error];
                if (error != nil || status != AVKeyValueStatusLoaded) {
                    [weakSelf notifyAboutError:error];
                    return;
                }

                status = [weakSelf.nativeAsset statusOfValueForKey:@"playable" error:&error];

                if (error != nil || status != AVKeyValueStatusLoaded) {
                    [weakSelf notifyAboutError:error];
                    return;
                }

                status = [weakSelf.nativeAsset statusOfValueForKey:@"duration" error:&error];

                if (error != nil || status != AVKeyValueStatusLoaded) {
                    [weakSelf notifyAboutError:error];
                    return;
                }
                
                [weakSelf startReadingNativeAsset];
            });
        }];
    });
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
