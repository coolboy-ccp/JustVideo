//
//  AudioUnitEXTConverter.h
//  JustVideo
//
//  Created by 储诚鹏 on 2018/11/6.
//  Copyright © 2018 储诚鹏. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BaseAudioPlayer.h"

NS_ASSUME_NONNULL_BEGIN

@interface AudioUnitEXTConverter : BaseAudioPlayer
+ (instancetype)defaultPlayer NS_UNAVAILABLE;
+ (instancetype)mp3;
@end

NS_ASSUME_NONNULL_END
