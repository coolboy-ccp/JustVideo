//
//  AudioUnitAUGraph.m
//  JustVideo
//
//  Created by 储诚鹏 on 2018/11/2.
//  Copyright © 2018 储诚鹏. All rights reserved.
//

#import "AudioUnitAUGraph.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioUnit/AudioUnit.h>

#define REMOTE_IO_INPUT_BUS 1
#define REMOTE_IO_OUTPUT_BUS 0
#define MIX_OUTPUT_BUS 0
#define MIX_INPUT_BUS0 0
#define MIX_INPUT_BUS1 1

#define BUFFER_SIZE 1024 * 4 * 10
#define STATR_TAG 10
#define STOP_TAG 20

@implementation AudioUnitAUGraph
{
    AudioUnit outputUnit;
    AudioUnit mixUnit;
    AudioBufferList *bufferList;
    NSInputStream *inputStream;
    Byte *buffer;
    AUGraph augraph;
    AudioStreamBasicDescription audioFormat;
    NSURL *fileURL;
}

+ (instancetype)defaultAU {
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"test" withExtension:@"pcm"];
    return [[AudioUnitAUGraph alloc] initWithUrl:url];
}

- (instancetype)initWithUrl:(NSURL *)url
{
    self = [super init];
    if (self) {
        fileURL = url;
    }
    return self;
}

- (void)start {
    [self setup];
}

- (void)stop {
    keepNoError(AUGraphStop(augraph));
    keepNoError(AUGraphUninitialize(augraph));
    if (bufferList != NULL) {
        if (bufferList->mBuffers[0].mData) {
            free(bufferList->mBuffers[0].mData);
            bufferList->mBuffers[0].mData = NULL;
        }
        free(bufferList);
        bufferList = NULL;
    }
    [inputStream close];
    keepNoError(DisposeAUGraph(augraph));
}

void keepNoError(OSStatus status) {
    NSLog(@"%d", status);
    assert(status == noErr);
}

- (void)setup {
    [self openFile];
    [self setupSession];
    [self setupBuffer];
    [self setupFormat];
    [self openAugraph];
    AUNode outputNode = [self setupOutputUnit];
    AUNode mixNode = [self setMixUnit];
    keepNoError(AUGraphConnectNodeInput(augraph, mixNode, MIX_OUTPUT_BUS, outputNode, REMOTE_IO_OUTPUT_BUS));
    [self setupPropertys];
    [self setupCallbacks];
    keepNoError(AUGraphInitialize(augraph));
    keepNoError(AUGraphStart(augraph));
}

- (void)setupCallbacks {
    void *refcon = (__bridge void *)self;
    AURenderCallbackStruct recordCB, mix0CB, mix1CB;
    recordCB.inputProc = recordCallback;
    recordCB.inputProcRefCon = refcon;
    mix0CB.inputProc = mixCallback0;
    mix0CB.inputProcRefCon = refcon;
    mix1CB.inputProc = mixCallback1;
    mix1CB.inputProcRefCon = refcon;
    UInt32 descSize = sizeof(AudioStreamBasicDescription);
    UInt32 cbSize = sizeof(AURenderCallbackStruct);
    keepNoError(AudioUnitSetProperty(mixUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, MIX_INPUT_BUS0, &mix0CB, cbSize));
    keepNoError(AudioUnitSetProperty(mixUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, MIX_INPUT_BUS0, &audioFormat, descSize));
    keepNoError(AudioUnitSetProperty(mixUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, MIX_INPUT_BUS1, &mix1CB, cbSize));
    keepNoError(AudioUnitSetProperty(mixUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, MIX_INPUT_BUS1, &audioFormat, descSize));
    keepNoError(AudioUnitSetProperty(outputUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Output, REMOTE_IO_INPUT_BUS, &recordCB, cbSize));
   
}

- (void)setupPropertys {
    //output
    keepNoError(AudioUnitSetProperty(outputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, REMOTE_IO_INPUT_BUS, &audioFormat, sizeof(audioFormat)));
    keepNoError(AudioUnitSetProperty(outputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, REMOTE_IO_OUTPUT_BUS, &audioFormat, sizeof(audioFormat)));
    uint32_t flag = 1;
    keepNoError(AudioUnitSetProperty(outputUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, REMOTE_IO_INPUT_BUS, &flag, sizeof(flag)));
    //mix
    UInt32 busCount = 2;
    UInt32 size = sizeof(UInt32);
    keepNoError(AudioUnitSetProperty(mixUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, MIX_INPUT_BUS0, &busCount, size));
    keepNoError(AudioUnitGetProperty(mixUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, MIX_INPUT_BUS0, &busCount, &size));
    keepNoError(AudioUnitGetProperty(outputUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Global, REMOTE_IO_INPUT_BUS, &busCount, &size));
}

- (AUNode)setupOutputUnit {
    AudioComponentDescription outputDesc;
    outputDesc.componentType = kAudioUnitType_Output;
    outputDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    outputDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    outputDesc.componentFlags = 0;
    outputDesc.componentFlagsMask = 0;
    AUNode outputNode;
    keepNoError(AUGraphAddNode(augraph, &outputDesc, &outputNode));
    keepNoError(AUGraphNodeInfo(augraph, outputNode, NULL, &outputUnit));
    return outputNode;
}

- (AUNode)setMixUnit {
    AudioComponentDescription mixDesc;
    mixDesc.componentType = kAudioUnitType_Mixer;
    mixDesc.componentSubType = kAudioUnitSubType_MultiChannelMixer;
    mixDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    mixDesc.componentFlags = 0;
    mixDesc.componentFlagsMask = 0;
    AUNode mixNode;
    keepNoError(AUGraphAddNode(augraph, &mixDesc, &mixNode));
    keepNoError(AUGraphNodeInfo(augraph, mixNode, NULL, &mixUnit));
    return mixNode;
}

- (void)openFile {
    inputStream = [NSInputStream inputStreamWithURL:fileURL];
    assert(inputStream);
    [inputStream open];
}

- (void)setupSession {
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:0.02 error:nil];
}

- (void)setupBuffer {
    bufferList = malloc(sizeof(AudioBufferList));
    bufferList->mNumberBuffers = 1;
    bufferList->mBuffers[0].mNumberChannels = 1;
    bufferList->mBuffers[0].mDataByteSize = BUFFER_SIZE;
    bufferList->mBuffers[0].mData = malloc(BUFFER_SIZE);
    buffer = malloc(BUFFER_SIZE);
}

- (void)setupFormat {
    audioFormat.mSampleRate = 44100;
    audioFormat.mFormatID = kAudioFormatLinearPCM;
    audioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsNonInterleaved;
    audioFormat.mFramesPerPacket = 1;
    audioFormat.mChannelsPerFrame = 1;
    audioFormat.mBytesPerPacket = 2;
    audioFormat.mBytesPerFrame = 2;
    audioFormat.mBitsPerChannel = 16;
}

- (void)openAugraph {
    OSStatus status = NewAUGraph(&augraph);
    assert(status == noErr);
    status = AUGraphOpen(augraph);
    assert(status == noErr);
}

#pragma mark -- callbacks
static OSStatus mixCallback0(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
    AudioUnitAUGraph *au = (__bridge AudioUnitAUGraph *)inRefCon;
    NSInteger size = (BUFFER_SIZE < ioData->mBuffers[0].mDataByteSize * 2) ? BUFFER_SIZE : ioData->mBuffers[0].mDataByteSize * 2;
    size = [au->inputStream read:au->buffer maxLength:size];
    for (int i = 0; i < size; i++) {
        ((Byte *)ioData->mBuffers[0].mData)[i / 2] = au->buffer[i];
    }
    ioData->mBuffers[1].mDataByteSize = (uint32_t)size / 2;
    return noErr;
}

static OSStatus mixCallback1(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
    AudioUnitAUGraph *au = (__bridge AudioUnitAUGraph *)inRefCon;
    AudioBuffer srcBuffer = au->bufferList->mBuffers[0];
    memcpy(ioData->mBuffers[0].mData, srcBuffer.mData, srcBuffer.mDataByteSize);
    ioData->mBuffers[0].mDataByteSize = srcBuffer.mDataByteSize;
    return noErr;
}

static OSStatus recordCallback(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData) {
    AudioUnitAUGraph *au = (__bridge AudioUnitAUGraph *)inRefCon;
    au->bufferList->mNumberBuffers = 1;
    OSStatus status = AudioUnitRender(au->outputUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, au->bufferList);
    if (status == noErr) {
        [au writePCM:au->bufferList->mBuffers[0].mData size:au->bufferList->mBuffers[0].mDataByteSize];
    }
    return status;
}

- (void)writePCM:(Byte *)buffer size:(int)size {
    static FILE *file = NULL;
    NSString *path = [NSTemporaryDirectory() stringByAppendingString:@"/record.pcm"];
    if (!file) {
        file = fopen(path.UTF8String, "w");
    }
    fwrite(buffer, size, 1, file);
}
@end
