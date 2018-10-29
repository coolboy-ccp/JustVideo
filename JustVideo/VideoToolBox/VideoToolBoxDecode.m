//
//  VideoToolBoxDecode.m
//  JustVideo
//
//  Created by 储诚鹏 on 2018/10/29.
//  Copyright © 2018 储诚鹏. All rights reserved.
//

#import "VideoToolBoxDecode.h"
#import "VideoToolBoxFileManager.h"
#import <VideoToolbox/VideoToolbox.h>
#import <QuartzCore/QuartzCore.h>

@implementation VideoToolBoxDecode
{
    dispatch_queue_t decodeQueue;
    VTDecompressionSessionRef decodeSession;
    CMFormatDescriptionRef formatDescription;
    CADisplayLink *displayLink;
    uint8_t *pps, *sps;
    long spsSize, ppsSize;
    int width, height;
    
    NSInputStream *inputStream;
    uint8_t *packetBuffer, *inputBuffer;
    long packetSize, inputSize, inputMaxSize;
}

- (instancetype)initWithWidth:(int)w height:(int)h {
    if (self = [super init]) {
        decodeQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        width = w;
        height = h;
        displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayFrame)];
    }
    return self;
}

- (void)inputStart {
    VideoToolBoxFileManager *fileHandle = [[VideoToolBoxFileManager alloc] initWithFileName:@"test.h264"];
    inputStream = [fileHandle read];
    if (!inputStream) {
        return;
    }
    [inputStream open];
    inputSize = 0;
    inputMaxSize = width * height * 3 * 4;
    inputBuffer = malloc(inputMaxSize);
    [displayLink setPaused:false];
}

- (void)inputEnd {
    if (inputStream) {
        [inputStream close];
    }
    inputStream = nil;
    if (inputBuffer) {
        free(inputBuffer);
        inputBuffer = NULL;
    }
    [displayLink setPaused:YES];
}

- (void)readPacket {
    const uint8_t lyStartCode[4] = {0, 0, 0, 1};
    if (packetSize && packetBuffer) {
        packetSize = 0;
        free(packetBuffer);
        packetBuffer = NULL;
    }
    if (inputSize < inputMaxSize && inputStream.hasBytesAvailable) {
        inputSize += [inputStream read:inputBuffer + inputSize maxLength:inputMaxSize - inputSize];
    }
    if (memcmp(inputBuffer, lyStartCode, 4) == 0) {
        if (inputSize > 4) { // 除了开始码还有内容
            uint8_t *pStart = inputBuffer + 4;
            uint8_t *pEnd = inputBuffer + inputSize;
            while (pStart != pEnd) { //这里使用一种简略的方式来获取这一帧的长度：通过查找下一个0x00000001来确定。
                if(memcmp(pStart - 3, lyStartCode, 4) == 0) {
                    packetSize = pStart - inputBuffer - 3;
                    if (packetBuffer) {
                        free(packetBuffer);
                        packetBuffer = NULL;
                    }
                    packetBuffer = malloc(packetSize);
                    memcpy(packetBuffer, inputBuffer, packetSize); //复制packet内容到新的缓冲区
                    memmove(inputBuffer, inputBuffer + packetSize, inputSize - packetSize); //把缓冲区前移
                    inputSize -= packetSize;
                    break;
                }
                else {
                    ++pStart;
                }
            }
        }
    }
}

- (void)setupVideoToolBox {
    if (decodeSession) {
        const uint8_t *parameterSetPointers[2] = {sps, pps};
        const size_t parameterSetSizes[2] = {spsSize, ppsSize};
        OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, 2, parameterSetPointers, parameterSetSizes, 4, &formatDescription);
        if (status == noErr) {
            CFDictionaryRef attrs = NULL;
            const void *keys[] = { kCVPixelBufferPixelFormatTypeKey };
            uint32_t v = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
            const void *values[] = { CFNumberCreate(NULL, kCFNumberSInt32Type, &v) };
            attrs = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
            VTDecompressionOutputCallbackRecord callBackRecord;
            callBackRecord.decompressionOutputCallback = didDecompress;
            callBackRecord.decompressionOutputRefCon = NULL;
            status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                                  formatDescription,
                                                  NULL, attrs,
                                                  &callBackRecord,
                                                  &decodeSession);
            CFRelease(attrs);
        }
        else {
            NSLog(@"IOS8VT: reset decoder session failed status=%d", status);
        }
    }
}

void didDecompress(void *decompressionOutputRefCon, void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef pixelBuffer, CMTime presentationTimeStamp, CMTime presentationDuration ){
    CVPixelBufferRef *outputPixelBuffer = (CVPixelBufferRef *)sourceFrameRefCon;
    *outputPixelBuffer = CVPixelBufferRetain(pixelBuffer);
}

- (CVPixelBufferRef)decode {
    CVPixelBufferRef outputPixelBuffer = NULL;
    if (decodeSession) {
        CMBlockBufferRef blockBuffer = NULL;
        OSStatus status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, (void *)packetBuffer, packetSize, kCFAllocatorNull, NULL, 0, packetSize, 0, &blockBuffer);
        if (status == kCMBlockBufferNoErr) {
            CMSampleBufferRef sampleBuffer = NULL;
            const size_t sampleSizes[] = {packetSize};
            status = CMSampleBufferCreateReady(kCFAllocatorDefault, blockBuffer, formatDescription, 1, 0, NULL, 1, sampleSizes, &sampleBuffer);
            if (status == kCMBlockBufferNoErr && sampleBuffer) {
                VTDecodeFrameFlags flags = 0;
                VTDecodeInfoFlags flagOut = 0;
                // 默认是同步操作。
                // 调用didDecompress，返回后再回调
                OSStatus decodeStatus = VTDecompressionSessionDecodeFrame(decodeSession,
                                                                          sampleBuffer,
                                                                          flags,
                                                                          &outputPixelBuffer,
                                                                          &flagOut);
                if(decodeStatus == kVTInvalidSessionErr) {
                    NSLog(@"IOS8VT: Invalid session, reset decoder session");
                } else if(decodeStatus == kVTVideoDecoderBadDataErr) {
                    NSLog(@"IOS8VT: decode failed status=%d(Bad data)", decodeStatus);
                } else if(decodeStatus != noErr) {
                    NSLog(@"IOS8VT: decode failed status=%d", decodeStatus);
                }
                CFRelease(sampleBuffer);
            }
            CFRelease(blockBuffer);
        }
    }
    return outputPixelBuffer;
}

- (void)displayFrame {
    if (inputStream){
        dispatch_sync(decodeQueue, ^{
            [self readPacket];
            if(self->packetBuffer == NULL || self->packetSize == 0) {
                [self inputEnd];
                return ;
            }
            uint32_t nalSize = (uint32_t)(self->packetSize - 4);
            uint32_t *pNalSize = (uint32_t *)self->packetBuffer;
            *pNalSize = CFSwapInt32HostToBig(nalSize);
            
            // 在buffer的前面填入代表长度的int
            CVPixelBufferRef pixelBuffer = NULL;
            int nalType = self->packetBuffer[4] & 0x1F;
            switch (nalType) {
                case 0x05:
                    NSLog(@"Nal type is IDR frame");
                    [self setupVideoToolBox];
                    pixelBuffer = [self decode];
                    break;
                case 0x07:
                    NSLog(@"Nal type is SPS");
                    self->spsSize = self->packetSize - 4;
                    self->sps = malloc(self->spsSize);
                    memcpy(self->sps, self->packetBuffer + 4, self->spsSize);
                    break;
                case 0x08:
                    NSLog(@"Nal type is PPS");
                    self->ppsSize = self->packetSize - 4;
                    self->pps = malloc(self->ppsSize);
                    memcpy(self->pps, self->packetBuffer + 4, self->ppsSize);
                    break;
                default:
                    NSLog(@"Nal type is B/P frame");
                    pixelBuffer = [self decode];
                    break;
            }
            
            if(pixelBuffer) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    // [self.mOpenGLView displayPixelBuffer:pixelBuffer];
                    CVPixelBufferRelease(pixelBuffer);
                });
            }
            NSLog(@"Read Nalu size %ld", self->packetSize);
        });
    }
}
    
- (void)EndVideoToolBox
{
    if(decodeSession) {
        VTDecompressionSessionInvalidate(decodeSession);
        CFRelease(decodeSession);
        decodeSession = NULL;
    }
    
    if(formatDescription) {
        CFRelease(formatDescription);
        formatDescription = NULL;
    }
    
    free(pps);
    free(sps);
    spsSize = ppsSize = 0;
}

@end
