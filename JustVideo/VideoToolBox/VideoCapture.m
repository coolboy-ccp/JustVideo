//
//  VideoCapture.m
//  JustVideo
//
//  Created by 储诚鹏 on 2018/10/29.
//  Copyright © 2018 储诚鹏. All rights reserved.
//

#import "VideoCapture.h"


@implementation VideoCapture
{
    AVCaptureSession *session;
    AVCaptureVideoPreviewLayer *previewLayer;
    CALayer *superLayer;
    CaptureCallback captureCallback;
}

- (instancetype)initWithSuperLayer:(CALayer *)layer {
    if (self = [super init]) {
        superLayer = layer;
        [self setup];
    }
    return self;
}

- (void)setup {
    session = [[AVCaptureSession alloc] init];
    session.sessionPreset = AVCaptureSessionPreset640x480;
    [self setupInput];
    [self setupOutput];
    [self setupPreviewLayer];
}

- (void)setupPreviewLayer {
    previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
    [previewLayer setFrame:superLayer.bounds];
    [superLayer addSublayer:previewLayer];
}

- (void)setupInput {
    AVCaptureDevice *device = nil;
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *d in devices) {
        if ([d position] == AVCaptureDevicePositionBack) {
            device = d;
        }
    }
    AVCaptureDeviceInput *deviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:device error:nil];
    if ([session canAddInput:deviceInput]) {
        [session addInput:deviceInput];
    }
}

- (void)setupOutput {
    dispatch_queue_t outputQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    AVCaptureVideoDataOutput *outPut = [[AVCaptureVideoDataOutput alloc] init];
    [outPut setAlwaysDiscardsLateVideoFrames:false];
    [outPut setVideoSettings:@{(id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8PlanarFullRange)}];
    [outPut setSampleBufferDelegate:self queue:outputQueue];
    if ([session canAddOutput:outPut]) {
        [session addOutput:outPut];
    }
}

- (void)startWithCallback:(CaptureCallback)callback {
    captureCallback = callback;
    [session startRunning];
}

- (void)stop {
    [session stopRunning];
    [previewLayer removeFromSuperlayer];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (captureCallback) {
        captureCallback(sampleBuffer);
    }
}
@end
