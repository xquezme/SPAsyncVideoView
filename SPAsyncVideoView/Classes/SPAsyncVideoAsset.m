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

+ (NSDictionary *)defaultOutputSettings {
    return @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
             (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
}

- (instancetype)initWithURL:(NSURL *)url {
    self = [super init];

    if (self) {
        _url = url;
        _outputSettings = [[self class] defaultOutputSettings];
    }

    return self;
}

- (instancetype)initWithAVAsset:(AVURLAsset *)asset outputSettings:(nullable NSDictionary *)outputSettings {
    self = [super init];

    if (self) {
        _asset = asset;
        _url = asset.URL;
        _outputSettings = outputSettings != nil ? outputSettings : [[self class] defaultOutputSettings];
    }

    return self;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[SPAsyncVideoAsset class]]) {
        return NO;
    }

    return [self.url isEqual:[object url]];
}

- (NSUInteger)hash {
    return self.url.hash;
}

@end
