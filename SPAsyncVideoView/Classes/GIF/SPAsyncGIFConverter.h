//
//  SPAsyncGIFConverter.h
//  Pods
//
//  Created by Sergey Pimenov on 14/08/2016.
//
//

#import <Foundation/Foundation.h>

typedef void (^SPAsyncGifConverterCompletion)(NSURL * _Nullable url,  NSError * _Nullable error);

NS_ASSUME_NONNULL_BEGIN

@interface SPAsyncGIFConverter : NSObject

@property (nonatomic, strong, readonly) NSURL *url;

- (instancetype)initWithGifURL:(NSURL *)url;
- (void)startWithOutputURL:(NSURL *)outputURL completion:(nonnull SPAsyncGifConverterCompletion)completion;

@end

NS_ASSUME_NONNULL_END