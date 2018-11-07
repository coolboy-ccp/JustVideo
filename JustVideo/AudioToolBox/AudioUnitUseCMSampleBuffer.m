//
//  AudioUnitUseCMSampleBuffer.m
//  JustVideo
//
//  Created by 储诚鹏 on 2018/11/6.
//  Copyright © 2018 储诚鹏. All rights reserved.
//

#import "AudioUnitUseCMSampleBuffer.h"

#define OUTPUT_BUS 0

@implementation AudioUnitUseCMSampleBuffer
{
    AVAsset *mAsset;
    AVAssetReader *mReader;
    AVAssetReaderTrackOutput *mTrackOutput;
    AudioStreamBasicDescription outputFormat;
    AudioBufferList *bufferList;
    NSTimeInterval mTimeStamp;
    UInt32 readSize;
    AudioUnit audioUnit;
}

+ (instancetype)defaultPlayer {
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"test" withExtension:@"mov"];
    AudioUnitUseCMSampleBuffer *cm = [[AudioUnitUseCMSampleBuffer alloc] initWithUrl:url];
    [cm loadAsset];
    return cm;
}

- (void)start {
    [self setup];
}

- (void)stop {
    [self disposeUnit];
    [self freeBuffer];
}

- (void)setup {
    [self setupReader];
    [self setupoutputFormat];
    [self setupAVSession];
    [self setupAudioComponent];
    [self setPropertys];
    [self setupCallback];
    [self play];
}

- (void)play {
    AudioUnitInitialize(audioUnit);
    AudioOutputUnitStart(audioUnit);
}

- (void)setupAVSession {
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:0.1 error:nil];
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
    AudioUnitSetProperty(audioUnit,
                         kAudioUnitProperty_SetRenderCallback,
                         kAudioUnitScope_Input,
                         OUTPUT_BUS,
                         &cb,
                         sizeof(cb));
}

- (void)loadAsset {
    NSDictionary *options = @{AVURLAssetPreferPreciseDurationAndTimingKey : @(true)};
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:self.fileURL options:options];
    __weak typeof(self) ws = self;
    [asset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler:^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            AVKeyValueStatus status = [asset statusOfValueForKey:@"tracks" error:nil];
            if (status == AVKeyValueStatusLoaded) {
                if (ws) {
                    __strong typeof(ws) ss = ws;
                    ss->mAsset = asset;
                }
            }
        });
    }];
}

- (void)setupReader {
    AVAssetReader *reader = [AVAssetReader assetReaderWithAsset:mAsset error:nil];
    AVAssetTrack *audioTrack = [mAsset tracksWithMediaType:AVMediaTypeAudio].firstObject;
    mTrackOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:audioTrack outputSettings:[self outputSettings]];
    mTrackOutput.alwaysCopiesSampleData = false;
    [reader addOutput:mTrackOutput];
    mReader = reader;//这个东西必须用全局变量保持
    assert([mReader startReading]);
}

- (NSDictionary *)outputSettings {
    NSMutableDictionary *outputSetting = [NSMutableDictionary dictionary];
    outputSetting[AVFormatIDKey] = @(kAudioFormatLinearPCM);
    outputSetting[AVLinearPCMBitDepthKey] = @(16);
    outputSetting[AVLinearPCMIsBigEndianKey] = @(false);
    outputSetting[AVLinearPCMIsFloatKey] = @(false);
    outputSetting[AVLinearPCMIsNonInterleaved] = @(true);
    outputSetting[AVSampleRateKey] = @(44100.0);
    outputSetting[AVNumberOfChannelsKey] = @(1);
    return outputSetting.copy;
}

- (void)setupoutputFormat {
    outputFormat.mSampleRate = 44100;
    outputFormat.mFormatID = kAudioFormatLinearPCM;
    outputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsNonInterleaved;
    outputFormat.mFramesPerPacket = 1;
    outputFormat.mChannelsPerFrame = 1;
    outputFormat.mBytesPerPacket = 2;
    outputFormat.mBytesPerFrame = 2;
    outputFormat.mBitsPerChannel = 16;
}

- (AudioBufferList *)requestData {
    size_t bufferListSizeNeedOut = 0;
    CMBlockBufferRef blockBuffer = NULL;
    CMSampleBufferRef sampleBuffer = [mTrackOutput copyNextSampleBuffer];
    static AudioBufferList cmBufferList;
    if (sampleBuffer) {
        OSStatus status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, &bufferListSizeNeedOut, &cmBufferList, sizeof(cmBufferList), kCFAllocatorSystemDefault, kCFAllocatorSystemDefault, kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment, &blockBuffer);
        assert(status == noErr);
        CMTime presentationTimeStap = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        mTimeStamp = (1000 * presentationTimeStap.value) / presentationTimeStap.timescale;
        CFRelease(sampleBuffer);
        return  &cmBufferList;
    }
    else {
        return NULL;
    }
}


static OSStatus callback(void *inRefCon,
                         AudioUnitRenderActionFlags *ioActionFlags,
                         const AudioTimeStamp *inTimeStamp,
                         UInt32 inBusNumber,
                         UInt32 inNumberFrames,
                         AudioBufferList *ioData) {
    AudioUnitUseCMSampleBuffer *cm = (__bridge AudioUnitUseCMSampleBuffer *)inRefCon;
    if (!cm->bufferList || cm->readSize + ioData->mBuffers[0].mDataByteSize > cm->bufferList->mBuffers[0].mDataByteSize) {
        cm->bufferList = [cm requestData];
        cm->readSize = 0;
    }
    BOOL hasMoreData = cm->bufferList && cm->bufferList->mNumberBuffers > 0;
    if (hasMoreData) {
        for (int i = 0; i < cm->bufferList->mNumberBuffers; i++) {
            memcpy(ioData->mBuffers[i].mData, cm->bufferList->mBuffers[i].mData, ioData->mBuffers[i].mDataByteSize);
            cm->readSize += ioData->mBuffers[i].mDataByteSize;
        }
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [cm stop];
        });
        return -10001;
    }
    return noErr;
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
}

@end
