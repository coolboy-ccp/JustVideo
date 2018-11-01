//
//  AudioUnitRecordAndPlay.m
//  JustVideo
//
//  Created by 储诚鹏 on 2018/10/31.
//  Copyright © 2018 储诚鹏. All rights reserved.
//

#import "AudioUnitRecordAndPlay.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioUnit/AudioUnit.h>

#define INPUT_BUS 1
#define OUTPUT_BUS 0
#define CONST_BUFFER_SIZE 2048*2*10

#define startTag 10
#define stopTag 20
@implementation AudioUnitRecordAndPlay
{
    AudioUnit audioUnit;
    AudioBufferList *bufferList;
    NSInputStream *inputStream;
    Byte *buffer;
    NSURL *fileURL;
}

- (instancetype)initWithURL:(NSString *)url {
    if (self = [super init]) {
        fileURL = [NSURL URLWithString:url];
        [self setup];
    }
    return self;
}

- (void)start {
    AudioOutputUnitStart(audioUnit);
}

- (void)stop {
    AudioOutputUnitStop(audioUnit);
    AudioUnitUninitialize(audioUnit);
    if (bufferList != NULL) {
        if (bufferList->mBuffers[0].mData) {
            free(bufferList->mBuffers[0].mData);
            bufferList->mBuffers[0].mData = NULL;
        }
        free(bufferList);
        bufferList = NULL;
    }
    
    [inputStream close];
    AudioComponentInstanceDispose(audioUnit);
}

- (void)setup {
    [self openStream];
    [self setupAVAudio];
    [self setupInputFormat];
    [self setupOutputFormat];
    [self enableIO];
    [self setupRecoderCallback];
    [self setupPlayCallback];
}

- (void)openStream {
    inputStream = [NSInputStream inputStreamWithURL:fileURL];
    if (!inputStream) {
        NSLog(@"failed to open file at %@", fileURL);
    }
    else {
        [inputStream open];
    }
}

- (void)setupAVAudio {
    NSError *error = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    assert(error == nil);
    [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:0.05 error:&error];
    assert(error == nil);
}

- (void)setupBufferList {
    uint32_t numberBuffers = 1;
    bufferList = malloc(sizeof(AudioBufferList)) + (numberBuffers - 1) * sizeof(AudioBuffer);
    bufferList->mNumberBuffers = numberBuffers;
    for (int i =0; i < numberBuffers; ++i) {
        bufferList->mBuffers[i].mNumberChannels = 1;
        bufferList->mBuffers[i].mDataByteSize = CONST_BUFFER_SIZE;
        bufferList->mBuffers[i].mData = malloc(CONST_BUFFER_SIZE);
    }
    buffer = malloc(CONST_BUFFER_SIZE);
}

- (void)setupAudioComponent {
    AudioComponentDescription componentDesc;
    memset(&componentDesc, 0, sizeof(componentDesc));
    componentDesc.componentType = kAudioUnitType_Output;
    componentDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    componentDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    componentDesc.componentFlags = 0;
    componentDesc.componentFlagsMask = 0;
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &componentDesc);
    OSStatus status = AudioComponentInstanceNew(inputComponent, &audioUnit);
    assert(status == noErr);
}

- (void)setupInputFormat {
    AudioStreamBasicDescription inputFormat = [self PCMFormat];
    OSStatus status = AudioUnitSetProperty(audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, INPUT_BUS, &inputFormat, sizeof(inputFormat));
    assert(status == noErr);
}

- (void)setupOutputFormat {
    AudioStreamBasicDescription outputFormat = [self PCMFormat];
    outputFormat.mChannelsPerFrame = 2;
    OSStatus status = AudioUnitSetProperty(audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, OUTPUT_BUS, &outputFormat, sizeof(outputFormat));
    assert(status == noErr);
}

- (void)enableIO {
    uint32_t flag = 1;
    OSStatus stattus = AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, INPUT_BUS, &flag, sizeof(flag));
    assert(stattus == noErr);
}

- (AudioStreamBasicDescription)PCMFormat {
    AudioStreamBasicDescription basicDesc;
    memset(&basicDesc, 0, sizeof(basicDesc));
    basicDesc.mSampleRate = 44100;//PCM码率
    basicDesc.mFormatID = kAudioFormatLinearPCM;//PCM
    basicDesc.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsNonInterleaved;
    basicDesc.mFramesPerPacket = 1;
    basicDesc.mChannelsPerFrame = 1;
    basicDesc.mBytesPerFrame = 2;
    basicDesc.mBytesPerPacket = 2;
    basicDesc.mBitsPerChannel = 16;
    return basicDesc;
}

- (AURenderCallbackStruct)callback:(AURenderCallback)cb {
    AURenderCallbackStruct cbStruct;
    cbStruct.inputProc = cb;
    cbStruct.inputProcRefCon = (__bridge void *)self;
    return cbStruct;
}

- (void)setupRecoderCallback {
    AURenderCallbackStruct cb = [self callback:recordCallback];
    OSStatus status = AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Output, INPUT_BUS, &cb, sizeof(cb));
    assert(status);
}

- (void)setupPlayCallback {
    AURenderCallbackStruct cb = [self callback:playCallback];
    OSStatus status = AudioUnitSetProperty(audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, OUTPUT_BUS, &cb, sizeof(cb));
    assert(status);
}

static OSStatus recordCallback(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData) {
    AudioUnitRecordAndPlay *rp = (__bridge AudioUnitRecordAndPlay *)inRefCon;
    rp->bufferList->mNumberBuffers = 1;
    OSStatus status = AudioUnitRender(rp->audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, rp->bufferList);
    assert(status == noErr);
    [rp writePCM];
    return status;
}

static OSStatus playCallback(void *inRefCon,
                             AudioUnitRenderActionFlags *ioActionFlags,
                             const AudioTimeStamp *inTimeStamp,
                             UInt32 inBusNumber,
                             UInt32 inNumberFrames,
                             AudioBufferList *ioData) {
    AudioUnitRecordAndPlay *rp = (__bridge AudioUnitRecordAndPlay *)inRefCon;
    memcpy(ioData->mBuffers[0].mData, rp->bufferList->mBuffers[0].mData, rp->bufferList->mBuffers[0].mDataByteSize);
    ioData->mBuffers[0].mDataByteSize = rp->bufferList->mBuffers[0].mDataByteSize;
    NSInteger bytes = (CONST_BUFFER_SIZE < ioData->mBuffers[1].mDataByteSize * 2) ? CONST_BUFFER_SIZE : ioData->mBuffers[1].mDataByteSize * 2;
    bytes = [rp->inputStream read:rp->buffer maxLength:bytes];
    for (int i = 0; i < bytes; i++) {
        ((Byte*)ioData->mBuffers[1].mData)[i/2] = rp->buffer[i];
    }
    ioData->mBuffers[1].mDataByteSize = (UInt32)bytes / 2;
    if (ioData->mBuffers[1].mDataByteSize < ioData->mBuffers[0].mDataByteSize) {
        ioData->mBuffers[0].mDataByteSize = ioData->mBuffers[1].mDataByteSize;
    }
    return noErr;
}

- (void)writePCM {
    static FILE *file = NULL;
    Byte *buffer = bufferList->mBuffers[0].mData;
    size_t size = bufferList->mBuffers[0].mDataByteSize;
    NSString *filePath = [NSTemporaryDirectory() stringByAppendingString:@"/record.pcm"];
    if (!file) {
        file = fopen(filePath.UTF8String, "w");
        /*
         "r" 以只读方式打开文件，该文件必须存在。
         "w" 打开只写文件，若文件存在则文件长度清为0，即该文件内容会消失。若文件不存在则建立该文件。
          "w+" 打开可读写文件，若文件存在则文件长度清为零，即该文件内容会消失。若文件不存在则建立该文件。
         "a" 以附加的方式打开只写文件。若文件不存在，则会建立该文件，如果文件存在，写入的数据会被加到文件尾，即文件原先的内容会被保留。（EOF符保留）
         "a+" 以附加方式打开可读写的文件。若文件不存在，则会建立该文件，如果文件存在，写入的数据会被加到文件尾后，即文件原先的内容会被保留。（原来的EOF符不保留）
          "wb" 只写打开或新建一个二进制文件，只允许写数据。
          "wb+" 读写打开或建立一个二进制文件，允许读和写。
         "ab" 追加打开一个二进制文件，并在文件末尾写数据。
         "ab+"读写打开一个二进制文件，允许读，或在文件末追加数据。
         */
    }
    fwrite(buffer, size, 1, file);
    /* -- buffer:指向数据块的指针
     -- size:每个数据的大小，单位为Byte(例如：sizeof(int)就是4)
     -- count:数据个数
     -- stream:文件指针
     */
}

@end
