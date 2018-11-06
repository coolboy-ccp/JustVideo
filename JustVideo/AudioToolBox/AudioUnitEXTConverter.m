//
//  AudioUnitEXTConverter.m
//  JustVideo
//
//  Created by 储诚鹏 on 2018/11/6.
//  Copyright © 2018 储诚鹏. All rights reserved.
//

#import "AudioUnitEXTConverter.h"

static const UInt32 buffer_size = 0x10000;
#define OUTPUT_BUS 0

@implementation AudioUnitEXTConverter
{
    ExtAudioFileRef exAudioFile;
    AudioStreamBasicDescription audioFileFormat;
    AudioStreamBasicDescription outputFormat;
    
    SInt64 readFrames;
    UInt64 totalFrames;
    
    AudioUnit audioUnit;
    AudioBufferList *bufferList;
    AudioConverterRef audioConverter;
}

+ (instancetype)selfWithType:(NSString *)type {
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"abc" withExtension:type];
    return [[AudioUnitEXTConverter alloc] initWithUrl:url];
}

+ (instancetype)mp3 {
    return [self selfWithType:@"mp3"];
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
}

- (void)disposeUnit {
    AudioOutputUnitStop(audioUnit);
    AudioUnitUninitialize(audioUnit);
    AudioComponentInstanceDispose(audioUnit);
    AudioConverterDispose(audioConverter);
}

- (void)setup {
    [self setupAVSession];
    [self setupBuffer];
    [self openFile];
    [self setupOutput];
    [self sourcePropertys];
    [self setupComponent];
    [self setPropertys];
    [self setupCallback];
    [self play];
}

- (void)setupAVSession {
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
}

- (void)setupBuffer {
    bufferList = malloc(sizeof(AudioBufferList));
    bufferList->mNumberBuffers = 1;
    bufferList->mBuffers[0].mNumberChannels = 1;
    bufferList->mBuffers[0].mDataByteSize = buffer_size;
    bufferList->mBuffers[0].mData = malloc(buffer_size);
}

- (void)openFile {
    OSStatus status = ExtAudioFileOpenURL((__bridge CFURLRef)self.fileURL, &exAudioFile);
    assert(status == noErr);
}

- (void)setupOutput {
    memset(&outputFormat, 0, sizeof(outputFormat));
    outputFormat.mSampleRate = 44100;
    outputFormat.mFormatID = kAudioFormatLinearPCM;
    outputFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger;
    outputFormat.mBytesPerPacket = 2;
    outputFormat.mBytesPerFrame = 2;
    outputFormat.mFramesPerPacket = 1;
    outputFormat.mChannelsPerFrame = 1;
    outputFormat.mBitsPerChannel = 16;
}

- (void)sourcePropertys {
    UInt32 size = sizeof(audioFileFormat);
    OSStatus status = ExtAudioFileGetProperty(exAudioFile, kExtAudioFileProperty_FileDataFormat, &size, &audioFileFormat);
    assert(status == noErr);
    status = ExtAudioFileSetProperty(exAudioFile, kExtAudioFileProperty_ClientDataFormat, size, &outputFormat);
    assert(status == noErr);
    size = sizeof(totalFrames);
    status = ExtAudioFileGetProperty(exAudioFile, kExtAudioFileProperty_FileLengthFrames, &size, &totalFrames);
    assert(status == noErr);
    readFrames = 0;
}

- (void)setupComponent {
    AudioComponentDescription audioDesc;
    audioDesc.componentType = kAudioUnitType_Output;
    audioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioDesc.componentFlags = 0;
    audioDesc.componentFlagsMask = 0;
    AudioComponent component = AudioComponentFindNext(NULL, &audioDesc);
    OSStatus status = AudioComponentInstanceNew(component, &audioUnit);
    assert(status == noErr);
}

- (void)setPropertys {
    UInt32 flag = 1;
    OSStatus status = AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, OUTPUT_BUS, &flag, sizeof(flag));
    assert(status == noErr);
    status = AudioUnitSetProperty(audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, OUTPUT_BUS, &outputFormat, sizeof(outputFormat));
    assert(status == noErr);
}

- (void)setupCallback {
    AURenderCallbackStruct cb;
    cb.inputProc = callback;
    cb.inputProcRefCon = (__bridge void *)self;
    OSStatus status = AudioUnitSetProperty(audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, OUTPUT_BUS, &cb, sizeof(cb));
    assert(status == noErr);
}

- (void)play {
    OSStatus status = AudioUnitInitialize(audioUnit);
    assert(status==noErr);
    status = AudioOutputUnitStart(audioUnit);
    assert(status==noErr);
}

OSStatus callback(void *inRefCon,
                  AudioUnitRenderActionFlags *ioActionFlags,
                  const AudioTimeStamp *inTimeStamp,
                  UInt32 inBusNumber,
                  UInt32 inNumberFrames,
                  AudioBufferList *ioData) {
    AudioUnitEXTConverter *ext = (__bridge AudioUnitEXTConverter *)inRefCon;
    ext->bufferList->mBuffers[0].mDataByteSize = buffer_size;
    OSStatus status = ExtAudioFileRead(ext->exAudioFile, &inNumberFrames, ext->bufferList);
    assert(status == noErr);
    memcpy(ioData->mBuffers[0].mData, ext->bufferList->mBuffers[0].mData, ext->bufferList->mBuffers[0].mDataByteSize);
    ioData->mBuffers[0].mDataByteSize = ext->bufferList->mBuffers[0].mDataByteSize;
    ext->readFrames += ext->bufferList->mBuffers[0].mDataByteSize / ext->outputFormat.mBytesPerFrame;
    writePCM(ext->bufferList->mBuffers[0].mData, ext->bufferList->mBuffers[0].mDataByteSize);
    if (ext->bufferList->mBuffers[0].mDataByteSize <= 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [ext stop];
        });
        return -10001;
    }
    return noErr;
    
}

static void writePCM(const void *data, size_t size) {
    static FILE *file;
    if (!file) {
        NSString *filePath = [NSTemporaryDirectory() stringByAppendingString:@"extconverter.pcm"];
        file = fopen(filePath.UTF8String, "w");
    }
    fwrite(data, size, 1, file);
}

@end
