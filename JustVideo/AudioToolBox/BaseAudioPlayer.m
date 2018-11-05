//
//  BaseAudioPlayer.m
//  JustVideo
//
//  Created by 储诚鹏 on 2018/11/5.
//  Copyright © 2018 储诚鹏. All rights reserved.
//

#import "BaseAudioPlayer.h"

@implementation BaseAudioPlayer
@synthesize fileURL;

+ (instancetype)defaultPlayer {
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"test" withExtension:@"pcm"];
    return [[self alloc] initWithUrl:url];
}

- (instancetype)initWithUrl:(NSURL *)url {
    if (self = [super init]) {
        fileURL = url;
    }
    return self;
}

- (void)start {}
- (void)stop {}
@end
