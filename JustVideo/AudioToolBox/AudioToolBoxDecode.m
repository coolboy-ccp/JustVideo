//
//  AudioToolBoxDecode.m
//  JustVideo
//
//  Created by 储诚鹏 on 2018/10/30.
//  Copyright © 2018 储诚鹏. All rights reserved.
//

#import "AudioToolBoxDecode.h"

const uint32_t buffer_count = 3;
const uint32_t buffer_size = 0x10000;

@implementation AudioToolBoxDecode
{
    AudioFileID audioFieldId; // An opaque data type that represents an audio file object.
    // An audio data format specification for a stream of audio
    AudioStreamBasicDescription basicDescription;
    // Describes one packet in a buffer of audio data where the sizes of the packets differ or where there is non-audio data between audio packets.
    AudioStreamPacketDescription *packetDescription;
    // Defines an opaque data type that represents an audio queue.
    AudioQueueRef audioQueue;
    AudioQueueBufferRef audioBuffers[buffer_count];
    SInt64 readedPacket;
    uint32_t packetNums;
    NSURL *fileUrl;
}

- (instancetype)init {
    if (self = [super init]) {
        [self customAudioConfig];
    }
    return self;
}

- (BOOL)fillBuffer:(AudioQueueBufferRef)buffer {
    BOOL isFull = false;
    uint32_t bytes = 0, packets = packetNums;
    OSStatus status = AudioFileReadPackets(audioFieldId, false, &bytes, packetDescription, readedPacket, &packets, buffer->mAudioData);
    assert(status == noErr);
    if (packets > 0) {
        buffer->mAudioDataByteSize = bytes;
        //把存有音频数据的buffer插入到audioqueue内置的buffer队列中
        AudioQueueEnqueueBuffer(audioQueue, buffer, packets, packetDescription);
        readedPacket += packets;
    }
    else {
        AudioQueueStop(audioQueue, false);
        isFull = true;
    }
    return isFull;
}

void bufferReady(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef buffer) {
    NSLog(@"refresh buffer");
    AudioToolBoxDecode *decoder = (__bridge AudioToolBoxDecode *)inUserData;
    if (!decoder) {
        NSLog(@"nil decoder");
        return;
    }
    if ([decoder fillBuffer:buffer]) {
        NSLog(@"decode end");
    }
}

- (void)customAudioConfig {
    OSStatus status = AudioFileOpenURL((__bridge CFURLRef)fileUrl, kAudioFileReadPermission, 0, &audioFieldId);
    if (status != noErr) {
        NSLog(@"failed to open file at %@", fileUrl);
        return;
    }
    uint32_t size = sizeof(basicDescription);
    //从file中获取
    status = AudioFileGetProperty(audioFieldId, kAudioFilePropertyDataFormat, &size, &basicDescription);
    assert(status == noErr);
    status = AudioQueueNewOutput(&basicDescription, bufferReady, (__bridge void * _Nullable)(self), NULL, NULL, 0, &audioQueue);// create a new playback audio queue
    assert(status == noErr);
    if (basicDescription.mBytesPerPacket == 0 || basicDescription.mFramesPerPacket == 0) {
        uint32_t maxSize;
        size = sizeof(maxSize);
        AudioFileGetProperty(audioFieldId, kAudioFilePropertyPacketSizeUpperBound, &size, &maxSize);
        if (maxSize > buffer_size) {
            maxSize = buffer_size;
        }
        packetNums = buffer_size / maxSize;
        packetDescription = malloc(sizeof(packetDescription) * packetNums);
    }
    else {
        packetNums = buffer_size / basicDescription.mBytesPerPacket;
        packetDescription = nil;
    }
    //
    void *cookie = NULL;
    AudioFileGetProperty(audioFieldId, kAudioFilePropertyMagicCookieData, &size, cookie);
    if (size > 0) {
        AudioQueueSetProperty(audioQueue, kAudioQueueProperty_MagicCookie, cookie, size);
    }
    readedPacket = 0;
    for (int i = 0; i < buffer_count; i++) {
        AudioQueueAllocateBuffer(audioQueue, buffer_size, &audioBuffers[i]);
        if ([self fillBuffer:audioBuffers[i]]) {
            break;
        }
    }
}

@end
