//
//  AudioUnitConverter.h
//  JustVideo
//
//  Created by 储诚鹏 on 2018/11/1.
//  Copyright © 2018 储诚鹏. All rights reserved.
//
// mp3/m4a/aac convert to pcm

#import <Foundation/Foundation.h>
#import "BaseAudioPlayer.h"

NS_ASSUME_NONNULL_BEGIN

@interface AudioUnitConverter :BaseAudioPlayer

+ (instancetype)defaultPlayer NS_UNAVAILABLE;
+ (instancetype)mp3;
+ (instancetype)m4a;
+ (instancetype)aac;

@end

NS_ASSUME_NONNULL_END
