//
//  ViewController.m
//  JustVideo
//
//  Created by 储诚鹏 on 2018/10/26.
//  Copyright © 2018 储诚鹏. All rights reserved.
//

#import "ViewController.h"
#import <assert.h>
#import "AudioToolBox/BaseAudioPlayer.h"
#import "AudioToolBox/AudioUnitAUGraph.h"
#import "AudioToolBox/AudioUnitPlayPCM.h"
#import "AudioToolBox/AudioUnitConverter.h"
#import "AudioToolBox/AudioUnitEXTConverter.h"
#import "AudioToolBox/AudioUnitUseCMSampleBuffer.h"

@interface ViewController ()
{
    NSArray <BaseAudioPlayer *>*players;
    IBOutletCollection(UIButton) NSArray *playBtns;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    players = @[[AudioUnitAUGraph defaultPlayer], [AudioUnitPlayPCM defaultPlayer], [AudioUnitConverter mp3], [AudioUnitConverter m4a], [AudioUnitConverter aac], [AudioUnitEXTConverter mp3], [AudioUnitUseCMSampleBuffer defaultPlayer]];
    NSAssert(players.count == playBtns.count, @"功能按钮数组和功能类数组个数必须一样");
}

- (IBAction)play:(UIButton *)sender {
    [self resetPlayers:sender];
    NSInteger idx = sender.tag - 101;
    BaseAudioPlayer *player = players[idx];
    sender.selected = !sender.selected;
    if (sender.selected) {
        [player start];
    }
    else {
        [player stop];
    }
}

- (void)resetPlayers:(UIButton *)current {
    for (int i = 0; i < players.count; i ++) {
        UIButton *btn = playBtns[i];
        if (btn == current) {
            continue;
        }
        BaseAudioPlayer *player = players[i];
        [player stop];
        btn.selected = false;
    }
}

@end
