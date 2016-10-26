//
//  SPAsyncVideoView+Internal.h
//  Pods
//
//  Created by Sergey Pimenov on 26/10/2016.
//
//
#import <UIKit/UIKit.h>

@class SPAsyncVideoView;
@class SPAsyncVideoAsset;

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

- (void)asyncVideoView:(SPAsyncVideoView *)asyncVideoView didReceiveAssetNaturalSize:(CGSize)assetNaturalSize;

@end

IB_DESIGNABLE
@interface SPAsyncVideoView : UIView

@property (nonatomic, weak) id<SPAsyncVideoViewDelegate> delegate;
@property (nullable, nonatomic, strong) SPAsyncVideoAsset *asset;
@property (nonatomic, assign) SPAsyncVideoViewVideoGravity videoGravity;
@property (nonatomic, assign) SPAsyncVideoViewActionAtItemEnd actionAtItemEnd;
@property (nonatomic, assign) IBInspectable BOOL autoPlay;
@property (nonatomic, assign) IBInspectable BOOL restartPlaybackOnEnteringForeground;
@property (nonatomic, strong, readonly) UIView *overlayView;

- (void)playVideo;
- (void)stopVideo;

@end

NS_ASSUME_NONNULL_END
