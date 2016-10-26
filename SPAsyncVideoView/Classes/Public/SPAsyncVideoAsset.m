//
//  SPAsyncVideoAsset.m
//  Pods
//
//  Created by Sergey Pimenov on 14/07/16.
//
//

#import "SPAsyncVideoAsset.h"

#import <AVFoundation/AVFoundation.h>

@implementation SPAsyncVideoAsset

- (instancetype)initWithURL:(NSURL *)url {
    return [self initWithURL:url type:SPAsyncVideoAssetTypeVideo];
}

- (instancetype)initWithURL:(NSURL *)url type:(SPAsyncVideoAssetType)type {
    self = [super init];

    if (self) {
        _originalURL = url;
        _type = type;
        
        switch (type) {
            case SPAsyncVideoAssetTypeGIF:
                _outputSettings = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32ARGB)};
                break;
            case SPAsyncVideoAssetTypeVideo:
                _outputSettings = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)};
                _finalURL = url;
                break;
            default:
                break;
        }
    }

    return self;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[SPAsyncVideoAsset class]]) {
        return NO;
    }

    return [self.originalURL isEqual:[object originalURL]];
}

- (NSUInteger)hash {
    return self.originalURL.hash;
}

@end
