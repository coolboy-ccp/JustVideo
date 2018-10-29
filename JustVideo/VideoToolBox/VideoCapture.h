//
//  VideoCapture.h
//  JustVideo
//
//  Created by 储诚鹏 on 2018/10/29.
//  Copyright © 2018 储诚鹏. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef void (^CaptureCallback)(CMSampleBufferRef sampleBuffer);
@interface VideoCapture : NSObject<AVCaptureVideoDataOutputSampleBufferDelegate>
- (instancetype)initWithSuperLayer:(CALayer *)layer;
- (void)startWithCallback:(CaptureCallback)callback;
- (void)stop;
@end

NS_ASSUME_NONNULL_END
