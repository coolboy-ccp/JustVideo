//
//  ViewController.m
//  JustVideo
//
//  Created by 储诚鹏 on 2018/10/26.
//  Copyright © 2018 储诚鹏. All rights reserved.
//

#import "ViewController.h"
#import "AudioToolBox/BaseAudioPlayer.h"
#import "AudioToolBox/AudioUnitAUGraph.h"
#import "AudioToolBox/AudioUnitPlayPCM.h"

@interface ViewController ()
{
    NSArray <BaseAudioPlayer *>*players;
    IBOutletCollection(UIButton) NSArray *playBtns;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    players = @[[AudioUnitAUGraph defaultPlayer], [AudioUnitPlayPCM defaultPlayer]];
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
