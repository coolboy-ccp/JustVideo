//
//  BaseAudioPlayer.h
//  JustVideo
//
//  Created by 储诚鹏 on 2018/11/5.
//  Copyright © 2018 储诚鹏. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BaseAudioPlayer : NSObject

@property (nonatomic, readonly) NSURL *fileURL;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)defaultPlayer;
- (instancetype)initWithUrl:(NSURL *)url;
- (void)start;
- (void)stop;
@end

NS_ASSUME_NONNULL_END
