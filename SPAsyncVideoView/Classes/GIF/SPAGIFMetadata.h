//
//  SPAGIFMetadata.h
//  Pods
//
//  Created by Sergey Pimenov on 14/08/2016.
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SPAGIFMetadata : NSObject

@property (nonatomic, assign) int32_t fps;
@property (nonatomic, assign) NSUInteger width;
@property (nonatomic, assign) NSUInteger height;
@property (nonatomic, assign) int64_t framesCount;
@property (nonatomic, assign) NSTimeInterval totalTime;

@end

NS_ASSUME_NONNULL_END