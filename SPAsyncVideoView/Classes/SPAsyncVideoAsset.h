//
//  SPAsyncVideoAsset.h
//  Pods
//
//  Created by Sergey Pimenov on 14/07/16.
//
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, SPAsyncVideoAssetType) {
    SPAsyncVideoAssetTypeVideo,
    SPAsyncVideoAssetTypeGIF
};

NS_ASSUME_NONNULL_BEGIN

@interface SPAsyncVideoAsset : NSObject

@property (nonatomic, assign) SPAsyncVideoAssetType type;
@property (nonatomic, strong, readonly) NSURL *originalURL;
@property (nullable, nonatomic, strong) NSURL *finalURL;
@property (nonatomic, strong) NSDictionary *outputSettings;

- (instancetype)initWithURL:(NSURL *)url;
- (instancetype)initWithURL:(NSURL *)url type:(SPAsyncVideoAssetType)type;

@end

NS_ASSUME_NONNULL_END