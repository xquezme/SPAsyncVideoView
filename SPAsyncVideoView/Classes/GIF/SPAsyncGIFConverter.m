//
//  SPAsyncGIFConverter.m
//  Pods
//
//  Created by Sergey Pimenov on 14/08/2016.
//
//

#import "SPAsyncGifConverter.h"

#import "SPAGIFMetadata.h"
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>

NS_INLINE SPAGIFMetadata *gifMetaDataFromData(NSData *data) {
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    unsigned char *bytes = (unsigned char *)data.bytes;

    if (CGImageSourceGetStatus(source) != kCGImageStatusComplete) {
        CFRelease(source);
        return nil;
    }

    SPAGIFMetadata *metaData = [SPAGIFMetadata new];

    metaData.framesCount = (int64_t)CGImageSourceGetCount(source);
    metaData.width = (NSUInteger)(bytes[6] + (bytes[7] << 8));
    metaData.height = (NSUInteger)(bytes[8] + (bytes[9] << 8));

    NSTimeInterval totalTime = 0.0;
    int64_t currentFrameNumber = 0;

    while (YES) {
        CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(source,
                                                                        (size_t)currentFrameNumber,
                                                                        NULL);

        if (properties != NULL) {
            CFDictionaryRef gifProperties = CFDictionaryGetValue(properties, kCGImagePropertyGIFDictionary);

            if (gifProperties != NULL) {
                NSNumber *delayTime = CFDictionaryGetValue(gifProperties, kCGImagePropertyGIFDelayTime);
                totalTime += delayTime.doubleValue;
            }
            CFRelease(properties);
        } else {
            break;
        }

        currentFrameNumber++;
    }

    metaData.totalTime = totalTime;
    metaData.fps = (int32_t)(ceil((double)metaData.framesCount / metaData.totalTime));

    CFRelease(source);

    return metaData;
}

NS_INLINE CVPixelBufferRef pixelBufferFromCGImage(CGImageRef image,
                                                  CVPixelBufferPoolRef pixelBufferPool,
                                                  NSDictionary *attributes) {
    if (image == nil) {
        return NULL;
    }

    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    size_t bpc = 8;

    CGColorSpaceRef colorSpace =  CGColorSpaceCreateDeviceRGB();

    CVPixelBufferRef pxBuffer = NULL;
    CVReturn status = kCVReturnSuccess;

    if (pixelBufferPool != NULL) {
        status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault,
                                                    pixelBufferPool,
                                                    &pxBuffer);
    } else {
        status = CVPixelBufferCreate(kCFAllocatorDefault,
                                     width,
                                     height,
                                     kCVPixelFormatType_32ARGB,
                                     (__bridge CFDictionaryRef)attributes,
                                     &pxBuffer);
    }

    if (status != kCVReturnSuccess) {
        return NULL;
    }

    CVPixelBufferLockBaseAddress(pxBuffer, 0);
    void *pxData = CVPixelBufferGetBaseAddress(pxBuffer);

    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pxBuffer);

    CGContextRef context = CGBitmapContextCreate(pxData,
                                                 width,
                                                 height,
                                                 bpc,
                                                 bytesPerRow,
                                                 colorSpace,
                                                 kCGImageAlphaNoneSkipFirst);
    if (context == NULL) {
        return NULL;
    }

    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);

    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    CVPixelBufferUnlockBaseAddress(pxBuffer, 0);

    return pxBuffer;
}


@interface SPAsyncGIFConverter ()

@property (nonatomic, copy) SPAsyncGifConverterCompletion completion;

@end


@implementation SPAsyncGIFConverter

- (instancetype)initWithGifURL:(NSURL *)url {
    self = [super init];

    if (self) {
        _url = url;
    }

    return self;
}

- (void)startWithOutputURL:(NSURL *)outputURL completion:(nonnull SPAsyncGifConverterCompletion)completion {
    _completion = completion;
    [self convertGifFromURL:self.url
                   toMP4URL:outputURL];
}

- (void)convertGifFromURL:(NSURL *)gifURL
                 toMP4URL:(NSURL *)mp4URL {

    NSError *error = nil;

    @synchronized ([NSFileManager class]) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:mp4URL.path]) {
            self.completion(nil, nil);
            return;
        }

        [[NSFileManager defaultManager] createDirectoryAtURL:[mp4URL URLByDeletingLastPathComponent]
                                 withIntermediateDirectories:YES
                                                  attributes:nil
                                                       error:&error];
    }

    if (error != nil) {
        self.completion(nil, nil);
        return;
    }

    NSData *data = [NSData dataWithContentsOfURL:gifURL];

    SPAGIFMetadata *metaData = gifMetaDataFromData(data);

    if (metaData == nil) {
        self.completion(nil, nil);
        return;
    }

    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);

    if (CGImageSourceGetStatus(source) != kCGImageStatusComplete) {
        CFRelease(source);
        self.completion(nil, nil);
        return;
    }

    AVAssetWriter *videoWriter = [[AVAssetWriter alloc] initWithURL:mp4URL
                                                           fileType:AVFileTypeMPEG4
                                                              error:&error];
    if (error != nil) {
        CFRelease(source);
        self.completion(nil, nil);
        return;
    }

    if (metaData.framesCount <= 0) {
        CFRelease(source);
        self.completion(nil, nil);
        return;
    }

    NSDictionary *outputSettings = @{AVVideoCodecKey : AVVideoCodecH264,
                                     AVVideoWidthKey : @(metaData.width),
                                     AVVideoHeightKey : @(metaData.height)};

    AVAssetWriterInput *videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                                              outputSettings:outputSettings];
    videoWriterInput.expectsMediaDataInRealTime = YES;

    NSDictionary *sourcePixelBufferAttributes =
    @{(NSString *)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32ARGB),
      (NSString *)kCVPixelBufferWidthKey: @(metaData.width),
      (NSString *)kCVPixelBufferHeightKey: @(metaData.height),
      (NSString *)kCVPixelBufferCGImageCompatibilityKey : @(YES),
      (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey : @(YES)};

    AVAssetWriterInputPixelBufferAdaptor *adaptor =
    [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:videoWriterInput
                                                                     sourcePixelBufferAttributes:sourcePixelBufferAttributes];

    if (![videoWriter canAddInput:videoWriterInput]) {
        self.completion(nil, nil);
        return;
    }

    [videoWriter addInput:videoWriterInput];
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:CMTimeMakeWithSeconds(0, metaData.fps)];

    int64_t currentFrameNumber = 0;
    NSTimeInterval currentTime = 0.0;

    while (YES) {
        while (!adaptor.assetWriterInput.readyForMoreMediaData) {}

        NSDictionary *options = @{(NSString *)kCGImageSourceTypeIdentifierHint:(id)kUTTypeGIF};
        CGImageRef imgRef = CGImageSourceCreateImageAtIndex(source,
                                                            currentFrameNumber,
                                                            (__bridge CFDictionaryRef)options);

        if (imgRef != NULL) {
            CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(source, currentFrameNumber, NULL);
            CFDictionaryRef gifProperties = CFDictionaryGetValue(properties, kCGImagePropertyGIFDictionary);

            if (gifProperties != NULL) {
                CVPixelBufferRef pxBuffer = pixelBufferFromCGImage(imgRef,
                                                                   adaptor.pixelBufferPool,
                                                                   adaptor.sourcePixelBufferAttributes);
                if (pxBuffer != NULL) {
                    NSNumber *delayTime = CFDictionaryGetValue(gifProperties, kCGImagePropertyGIFDelayTime);
                    currentTime += delayTime.floatValue;
                    CMTime time = CMTimeMakeWithSeconds(currentTime, metaData.fps);

                    if (![adaptor appendPixelBuffer:pxBuffer withPresentationTime:time]) {
                        CFRelease(properties);
                        CGImageRelease(imgRef);
                        CVBufferRelease(pxBuffer);
                        CFRelease(source);
                        self.completion(nil, videoWriter.error);
                        return;
                    }

                    CVBufferRelease(pxBuffer);
                }
            }

            if (properties != NULL) {
                CFRelease(properties);
            }

            CGImageRelease(imgRef);

            currentFrameNumber++;

            continue;
        }

        CFRelease(source);

        [videoWriterInput markAsFinished];
        [videoWriter finishWritingWithCompletionHandler:^{
            self.completion(mp4URL, nil);
        }];

        return;
    }
};

@end
