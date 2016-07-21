//
//  SPAsyncVideoAsset.h
//  Pods
//
//  Created by Sergey Pimenov on 14/07/16.
//
//

#import <Foundation/Foundation.h>

@class AVURLAsset;

NS_ASSUME_NONNULL_BEGIN

@interface SPAsyncVideoAsset : NSObject

@property (nullable, nonatomic, strong) NSURL *url;
@property (nullable, atomic, strong) AVURLAsset *asset;
@property (nonatomic, strong) NSDictionary *outputSettings;

+ (NSDictionary *)defaultOutputSettings;

- (instancetype)initWithURL:(NSURL *)url;

- (instancetype)initWithAVAsset:(AVURLAsset *)asset outputSettings:(nullable NSDictionary *)outputSettings;

@end

NS_ASSUME_NONNULL_END