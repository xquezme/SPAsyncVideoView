//
//  SPAsyncVideoView.h
//  Pods
//
//  Created by Sergey Pimenov on 14/07/16.
//
//

#import <UIKit/UIKit.h>
#import "SPAsyncVideoAsset.h"

@class SPAsyncVideoView;

typedef NS_ENUM(NSInteger, SPAsyncVideoViewActionAtItemEnd) {
    SPAsyncVideoViewActionAtItemEndNone,
    SPAsyncVideoViewActionAtItemEndRepeat
};

typedef NS_ENUM(NSInteger, SPAsyncVideoViewVideoGravity) {
    SPAsyncVideoViewVideoGravityResizeAspect,
    SPAsyncVideoViewVideoGravityResizeAspectFill,
    SPAsyncVideoViewVideoGravityResize
};

NS_ASSUME_NONNULL_BEGIN

@protocol SPAsyncVideoViewDelegate <NSObject>

@optional
- (void)asyncVideoView:(SPAsyncVideoView *)asyncVideoView didOccurError:(NSError *)error;
- (void)asyncVideoViewDidPlayToEnd:(SPAsyncVideoView *)asyncVideoView;

- (void)asyncVideoViewWillRenderFirstFrame:(SPAsyncVideoView *)asyncVideoView;
- (void)asyncVideoViewDidRenderFirstFrame:(SPAsyncVideoView *)asyncVideoView;

- (void)asyncVideoViewWillFlush:(SPAsyncVideoView *)asyncVideoView;
- (void)asyncVideoViewDidFlush:(SPAsyncVideoView *)asyncVideoView;

@end

IB_DESIGNABLE
@interface SPAsyncVideoView : UIView

@property (nonatomic, weak) id<SPAsyncVideoViewDelegate> delegate;
@property (nullable, nonatomic, strong) SPAsyncVideoAsset *asset;
@property (nonatomic, assign) SPAsyncVideoViewVideoGravity videoGravity;
@property (nonatomic, assign) SPAsyncVideoViewActionAtItemEnd actionAtItemEnd;
@property (nonatomic, assign) IBInspectable BOOL autoPlay;
@property (nonatomic, assign) IBInspectable BOOL restartPlaybackOnEnteringForeground;

- (void)playVideo;
- (void)stopVideo;

@end

NS_ASSUME_NONNULL_END