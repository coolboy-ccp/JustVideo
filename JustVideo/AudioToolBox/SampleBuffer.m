//
//  SampleBuffer.m
//  JustVideo
//
//  Created by 储诚鹏 on 2018/11/7.
//  Copyright © 2018 储诚鹏. All rights reserved.
//

#import "SampleBuffer.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <AVFoundation/AVFoundation.h>

@implementation SampleBuffer
{
    AVAsset *mAsset;
    AVAssetReader *mReader;
    AVAssetReaderTrackOutput *mReaderAudioTrackOutput;
}

- (void)loadAsset {
    NSDictionary *inputOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:AVURLAssetPreferPreciseDurationAndTimingKey];
    AVURLAsset *inputAsset = [[AVURLAsset alloc] initWithURL:[[NSBundle mainBundle] URLForResource:@"test" withExtension:@"mov"] options:inputOptions];
    __weak typeof(self) weakSelf = self;
    [inputAsset loadValuesAsynchronouslyForKeys:[NSArray arrayWithObject:@"tracks"] completionHandler: ^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSError *error = nil;
            AVKeyValueStatus tracksStatus = [inputAsset statusOfValueForKey:@"tracks" error:&error];
            if (tracksStatus == AVKeyValueStatusLoaded)
            {
                if (weakSelf) {
                    __strong typeof(weakSelf) ss = weakSelf;
                    ss->mAsset = inputAsset;
                }
            }
        });
    }];
}

- (NSDictionary *)outputOptions {
    NSMutableDictionary *outputSettings = [NSMutableDictionary dictionary];
    [outputSettings setObject:@(kAudioFormatLinearPCM) forKey:AVFormatIDKey];
    [outputSettings setObject:@(16) forKey:AVLinearPCMBitDepthKey];
    [outputSettings setObject:@(NO) forKey:AVLinearPCMIsBigEndianKey];
    [outputSettings setObject:@(NO) forKey:AVLinearPCMIsFloatKey];
    [outputSettings setObject:@(YES) forKey:AVLinearPCMIsNonInterleaved];
    [outputSettings setObject:@(44100.0) forKey:AVSampleRateKey];
    [outputSettings setObject:@(1) forKey:AVNumberOfChannelsKey];
    return outputSettings.copy;
}

- (void)setupReader {
    AVAssetReader *assetReader = [AVAssetReader assetReaderWithAsset:mAsset error:nil];
    AVAssetTrack *audioTrack = [mAsset tracksWithMediaType:AVMediaTypeAudio].firstObject;
    mReaderAudioTrackOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:audioTrack outputSettings:[self outputOptions]];
    mReaderAudioTrackOutput.alwaysCopiesSampleData = NO;
    [assetReader addOutput:mReaderAudioTrackOutput];
    mReader = assetReader;
}

@end
