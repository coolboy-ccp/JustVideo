//
//  AudioUnitPlayPCM.m
//  JustVideo
//
//  Created by 储诚鹏 on 2018/11/1.
//  Copyright © 2018 储诚鹏. All rights reserved.
//

#import "AudioUnitPlayPCM.h"


static const UInt32 buffer_size = 0x10000;

#define INPUT_BUS 1
#define OUTPUT_BUS 0

@implementation AudioUnitPlayPCM
{
    AudioUnit audioUnit;
    AudioBufferList *bufferList;
    NSInputStream *inputStream;
}

- (void)start {
    [self setup];
}

- (void)setup {
    [self openFile];
    [self setupAVSession];
    [self setupAudioComponent];
    [self enableIO];
    [self setupOutput];
    [self setupCallback];
    [self play];
}

- (void)enableIO {
    UInt32 flag = 1;
    OSStatus status = AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, OUTPUT_BUS, &flag, sizeof(flag));
    assert(status == noErr);
}

- (void)openFile {
    inputStream = [NSInputStream inputStreamWithURL:self.fileURL];
    assert(inputStream);
    [inputStream open];
}

- (void)setupAVSession {
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:0.02 error:nil];
}

- (void)setupAudioComponent {
    AudioComponentDescription componentDesc;
    componentDesc.componentType = kAudioUnitType_Output;
    componentDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    componentDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    componentDesc.componentFlags = 0;
    componentDesc.componentFlagsMask = 0;
    AudioComponent component = AudioComponentFindNext(NULL, &componentDesc);
    AudioComponentInstanceNew(component, &audioUnit);
}

- (void)setupBuffer {
    bufferList = malloc(sizeof(AudioBufferList));
    bufferList->mNumberBuffers = 1;
    bufferList->mBuffers[0].mNumberChannels = 1;
    bufferList->mBuffers[0].mDataByteSize = buffer_size;
    bufferList->mBuffers[0].mData = malloc(buffer_size);
}

- (void)setupOutput {
    AudioStreamBasicDescription desc;
    memset(&desc, 0, sizeof(desc));
    desc.mSampleRate = 44100;
    desc.mFormatID = kAudioFormatLinearPCM;
    desc.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger;
    desc.mFramesPerPacket = 1;
    desc.mChannelsPerFrame = 1;
    desc.mBytesPerFrame = 2;
    desc.mBytesPerPacket = 2;
    desc.mBitsPerChannel = 16;
    OSStatus status = AudioUnitSetProperty(audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, OUTPUT_BUS, &desc, sizeof(desc));
    assert(status == noErr);
}

- (void)setupCallback {
    AURenderCallbackStruct cb;
    cb.inputProc = callback;
    cb.inputProcRefCon = (__bridge void *)self;
    AudioUnitSetProperty(audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, OUTPUT_BUS, &cb, sizeof(cb));
}

- (void)play {
    AudioUnitInitialize(audioUnit);
    AudioOutputUnitStart(audioUnit);
}

static OSStatus callback(void *inRefCon,
                         AudioUnitRenderActionFlags *ioActionFlags,
                         const AudioTimeStamp *inTimeStamp,
                         UInt32 inBusNumber,
                         UInt32 inNumberFrames,
                         AudioBufferList *ioData) {
    AudioUnitPlayPCM *ppcm = (__bridge AudioUnitPlayPCM *)inRefCon;
    ioData->mBuffers[0].mDataByteSize = [ppcm->inputStream read:ioData->mBuffers[0].mData maxLength:ioData->mBuffers[0].mDataByteSize];
    if (ioData->mBuffers[0].mDataByteSize <= 0) {
        [ppcm stop];
    }
    return noErr;
}

- (void)stop {
    [self disposeOutputUnit];
    [self freeBufferList];
    [inputStream close];
}

- (void)disposeOutputUnit {
    AudioOutputUnitStop(audioUnit);
    AudioUnitUninitialize(audioUnit);
    AudioComponentInstanceDispose(audioUnit);
}

- (void)freeBufferList {
    if (bufferList != NULL) {
        if (bufferList->mBuffers[0].mData) {
            free(bufferList->mBuffers[0].mData);
            bufferList->mBuffers[0].mData = NULL;
        }
        free(bufferList);
        bufferList = NULL;
    }
}

@end
