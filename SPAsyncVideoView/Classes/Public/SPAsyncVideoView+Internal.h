//
//  SPAsyncVideoView+Internal.h
//  Pods
//
//  Created by Sergey Pimenov on 26/10/2016.
//
//
#import <UIKit/UIKit.h>

@class SPAsyncVideoView;

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
- (void)asyncVideoViewWillBeginPlaying:(SPAsyncVideoView *)asyncVideoView assetNaturalSize:(CGSize)assetNaturalSize;

@end

IB_DESIGNABLE
@interface SPAsyncVideoView : UIView

@property (nonatomic, weak) id<SPAsyncVideoViewDelegate> delegate;
@property (nonatomic, assign) SPAsyncVideoViewVideoGravity videoGravity;
@property (nonatomic, assign) IBInspectable BOOL autoPlay;

@property (nonatomic, strong, nullable) NSURL *assetURL;

- (void)playVideo;
- (void)stopVideo;

@end

NS_ASSUME_NONNULL_END
