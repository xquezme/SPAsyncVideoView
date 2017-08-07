//
//  SPAsyncVideoRenderer.h
//  Pods
//
//  Created by Sergey Pimenov on 04/08/2017.
//
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class SPAsyncVideoReader;

@interface SPAsyncVideoRenderer : NSObject

@property (atomic, weak) AVSampleBufferDisplayLayer *displayLayer;

- (instancetype)initWithAssetReader:(SPAsyncVideoReader *)assetReader displayLayer:(AVSampleBufferDisplayLayer *)displayLayer;

- (void)startRendering;
- (void)cancelRendering;

@end
