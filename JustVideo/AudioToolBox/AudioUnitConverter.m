//
//  AudioUnitConverter.m
//  JustVideo
//
//  Created by 储诚鹏 on 2018/11/1.
//  Copyright © 2018 储诚鹏. All rights reserved.
//

#import "AudioUnitConverter.h"

#define INPUT_BUS 1
#define OUTPUT_BUS 0

static const UInt32 buffer_size = 0x10000;

@implementation AudioUnitConverter
{
    AudioFileID audioFileID;
    AudioStreamBasicDescription sourceDesc;
    AudioStreamPacketDescription *packetDesc;
    
    SInt64 readPacket;
    UInt64 packetNums;
    UInt64 packetNumsInBuffer;
    
    AudioUnit audioUnit;
    AudioBufferList *bufferList;
    Byte *buffer;
    
    AudioConverterRef audioConverter;
}

+ (instancetype)selfWithType:(NSString *)type {
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"abc" withExtension:type];
    return [[AudioUnitConverter alloc] initWithUrl:url];
}

+ (instancetype)mp3 {
    return [self selfWithType:@"mp3"];
}

+ (instancetype)m4a {
    return [self selfWithType:@"m4a"];
}

+ (instancetype)aac {
    return [self selfWithType:@"aac"];
}

- (void)start {
    [self setup];
}

- (void)stop {
    if (audioUnit) {
        [self disposeUnit];
        [self freeBuffer];
    }
}

- (void)freeBuffer {
    if (bufferList != NULL) {
        if (bufferList->mBuffers[0].mData) {
            free(bufferList->mBuffers[0].mData);
            bufferList->mBuffers[0].mData = NULL;
        }
        free(bufferList);
        bufferList = NULL;
    }
    if (buffer != NULL) {
        free(buffer);
        buffer = NULL;
    }
}

- (void)disposeUnit {
    AudioOutputUnitStop(audioUnit);
    AudioUnitUninitialize(audioUnit);
    AudioComponentInstanceDispose(audioUnit);
    AudioConverterDispose(audioConverter);
}

- (void)setup {
    [self sourcePropertys];
    [self setupAVSession];
    [self setupAudioComponent];
    [self setupBuffer];
    [self setupOutput];
    [self setupCallback];
    [self play];
}

- (void)sourcePropertys {
    OSStatus status = AudioFileOpenURL((__bridge CFURLRef)self.fileURL, kAudioFileReadPermission, 0/*指明音频格式，若不知道就传0*/, &audioFileID);
    assert(status==noErr);
    UInt32 size = sizeof(sourceDesc);
    status = AudioFileGetProperty(audioFileID, kAudioFilePropertyDataFormat, &size, &sourceDesc);
    assert(status==noErr);
    size = sizeof(packetNums);
    status = AudioFileGetProperty(audioFileID, kAudioFilePropertyAudioDataPacketCount, &size, &packetNums);
    assert(status==noErr);
    readPacket = 0;
    UInt32 frames = sourceDesc.mFramesPerPacket;
    if (frames == 0) {
        status = AudioFileGetProperty(audioFileID, kAudioFilePropertyMaximumPacketSize, &size, &frames);
        assert(status == noErr && frames != 0);
    }
    packetDesc = malloc(sizeof(AudioStreamPacketDescription) * (buffer_size / frames + 1));
}

- (void)setupAVSession {
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
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
    buffer = malloc(buffer_size);
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
    OSStatus status = AudioConverterNew(&sourceDesc, &desc, &audioConverter);
    assert(status == noErr);
    UInt32 flag = 1;
    status = AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, OUTPUT_BUS, &flag, sizeof(flag));
    assert(status == noErr);
    status = AudioUnitSetProperty(audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, OUTPUT_BUS, &desc, sizeof(desc));
    assert(status==noErr);
    
}

- (void)setupCallback {
    AURenderCallbackStruct cb;
    cb.inputProc = playCallback;
    cb.inputProcRefCon = (__bridge void *)self;
    OSStatus status = AudioUnitSetProperty(audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, OUTPUT_BUS, &cb, sizeof(cb));
    assert(status==noErr);
}

- (void)play {
    OSStatus status = AudioUnitInitialize(audioUnit);
    assert(status==noErr);
    status = AudioOutputUnitStart(audioUnit);
    assert(status==noErr);
}


OSStatus converCallback(AudioConverterRef inAudioConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription **outDataPacketDescription, void *inUserData) {
    AudioUnitConverter *ac = (__bridge AudioUnitConverter *)inUserData;
    UInt32 size = buffer_size;
    OSStatus status = AudioFileReadPacketData(ac->audioFileID, false, &size, ac->packetDesc, ac->readPacket, ioNumberDataPackets, ac->buffer);
    assert(status == noErr);
    if (outDataPacketDescription) {
        *outDataPacketDescription = ac->packetDesc;
    }
    if (!status && ioNumberDataPackets > 0) {
        ioData->mBuffers[0].mDataByteSize = size;
        ioData->mBuffers[0].mData = ac->buffer;
        ac->readPacket += *ioNumberDataPackets;
        return noErr;
    }
    else {
        return -10001;
    }
    
}

OSStatus playCallback(void *inRefCon,
                      AudioUnitRenderActionFlags *ioActionFlags,
                      const AudioTimeStamp *inTimeStamp,
                      UInt32 inBusNumber,
                      UInt32 inNumberFrames,
                      AudioBufferList *ioData) {
    AudioUnitConverter *ac = (__bridge AudioUnitConverter *)inRefCon;
    ac->bufferList->mBuffers[0].mDataByteSize = buffer_size;
    OSStatus status = AudioConverterFillComplexBuffer(ac->audioConverter, converCallback, inRefCon, &inNumberFrames, ac->bufferList, NULL);
    assert(status == noErr);
    memcpy(ioData->mBuffers[0].mData, ac->bufferList->mBuffers[0].mData, ac->bufferList->mBuffers[0].mDataByteSize);
    ioData->mBuffers[0].mDataByteSize = ac->bufferList->mBuffers[0].mDataByteSize;
    writePCM(ac->bufferList->mBuffers[0].mData, ac->bufferList->mBuffers[0].mDataByteSize);
    if (ac->bufferList->mBuffers[0].mDataByteSize <= 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [ac stop];
        });
    }
    return noErr;
}

static void writePCM(const void *data, size_t size) {
    static FILE *file;
    if (!file) {
        NSString *filePath = [NSTemporaryDirectory() stringByAppendingString:@"converter.pcm"];
        file = fopen(filePath.UTF8String, "w");
    }
    fwrite(data, size, 1, file);
}

@end
