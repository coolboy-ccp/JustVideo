//
//  VideoToolBoxEncode.m
//  JustVideo
//
//  Created by 储诚鹏 on 2018/10/26.
//  Copyright © 2018 储诚鹏. All rights reserved.
//

#import "VideoToolBoxEncode.h"
#import "VideoToolBoxFileManager.h"
#import <VideoToolbox/VideoToolbox.h>

@implementation VideoToolBoxEncode
{
    dispatch_queue_t encodeQueue;
    VTCompressionSessionRef encodingSession;
    int frameId;
    int width, height;
    VideoToolBoxFileManager *VTFManager;
}


- (instancetype)initWithWidth:(int)w height:(int)h {
    if (self = [super init]) {
        encodeQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        width = w;
        height = h;
        VTFManager = [[VideoToolBoxFileManager alloc] initWithFileName:@"test.h264"];
        [VTFManager setUpFileHandler];
    }
    return self;
}

- (void)setUpToolBox {
    dispatch_sync(encodeQueue, ^{
        self->frameId = 0;
        OSStatus statuc = VTCompressionSessionCreate(NULL, self->width, self->height, kCMVideoCodecType_H264, NULL, NULL, NULL, didCompressH264, (__bridge void *)(self->VTFManager), &self->encodingSession);
        if (statuc != 0) {
            return ;
        }
        //设置实时编码输出（避免延迟）
        VTSessionSetProperty(self->encodingSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        VTSessionSetProperty(self->encodingSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel);
        // 设置关键帧（GOPsize)间隔
        int frameInterval = 10;
        CFNumberRef  frameIntervalRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &frameInterval);
        VTSessionSetProperty(self->encodingSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, frameIntervalRef);
        // 设置期望帧率
        int fps = 10;
        CFNumberRef  fpsRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &fps);
        VTSessionSetProperty(self->encodingSession, kVTCompressionPropertyKey_ExpectedFrameRate, fpsRef);
        //设置码率，均值，单位是byte
        int bitRate = self->width * self->height * 3 * 4 * 8;
        CFNumberRef bitRateRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bitRate);
        VTSessionSetProperty(self->encodingSession, kVTCompressionPropertyKey_AverageBitRate, bitRateRef);
        //设置码率，上限，单位是bps
        int bitRateLimit = self->width * self->height * 3 * 4;
        CFNumberRef bitRateLimitRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bitRateLimit);
        VTSessionSetProperty(self->encodingSession, kVTCompressionPropertyKey_DataRateLimits, bitRateLimitRef);
        // Tell the encoder to start encoding
        VTCompressionSessionPrepareToEncodeFrames(self->encodingSession);
        
    });
}

- (void)encode:(CMSampleBufferRef)sampleBUffer {
    CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBUffer);
    // 帧时间，如果不设置会导致时间轴过长。
    CMTime presentationTimeStamp = CMTimeMake(frameId++, 1000);
    VTEncodeInfoFlags flags;
    OSStatus statusCode = VTCompressionSessionEncodeFrame(encodingSession,
                                                          imageBuffer,
                                                          presentationTimeStamp,
                                                          kCMTimeInvalid,
                                                          NULL, NULL, &flags);
    if (statusCode != noErr) {
        NSLog(@"H264: VTCompressionSessionEncodeFrame failed with %d", (int)statusCode);
        VTCompressionSessionInvalidate(encodingSession);
        CFRelease(encodingSession);
        encodingSession = NULL;
    }
}

void encodeSpsPps(CMSampleBufferRef sampleBuffer, VideoToolBoxFileManager *fileHandle) {
    bool keyframe = !CFDictionaryContainsKey( (CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);
    // 判断当前帧是否为关键帧
    // 获取sps & pps数据
    if (keyframe) {
        CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
        size_t sparameterSetSize, sparameterSetCount, pparameterSetSize, pparameterSetCount;
        const uint8_t *sparameterSet, *pparameterSet;
        //码流的第一个NALU sps（序列参数集Sequence Parameter Set）
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescription, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0 );
        //码流的第二个NALU pps (图像参数集Picture Parameter Set)
        OSStatus statusCode1 = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescription, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0 );
        if (statusCode == noErr && statusCode1 == noErr) {
            NSData *sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
            NSData *pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
            [fileHandle writeSps:sps pps:pps];
        }
    }
}

void encodeOtherNALUs(CMSampleBufferRef sampleBuffer, VideoToolBoxFileManager *fileHandle) {
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCode = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCode == noErr) {
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4; // 返回的nalu数据前四个字节不是0001的startcode，而是大端模式的帧长度length
        //循环获取nalu数据
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            uint32_t naluLength = 0;
            //Read the nal unit length
            memcpy(&naluLength, dataPointer + bufferOffset, AVCCHeaderLength);
            // 从大端转系统端
            naluLength = CFSwapInt32BigToHost(naluLength);
            NSData* data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:naluLength];
            [fileHandle writeEncodeData:data];
            bufferOffset += AVCCHeaderLength + naluLength;
        }
    }
}

void didCompressH264(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer)  {
    if (status != 0) {
        return;
    }
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        return;
    }
    VideoToolBoxFileManager *fileHandle = (__bridge VideoToolBoxFileManager *)outputCallbackRefCon;
    if (!fileHandle) {
        return;
    }
    encodeSpsPps(sampleBuffer, fileHandle);
    encodeOtherNALUs(sampleBuffer, fileHandle);
}



@end
