//
//  ViewController.m
//  JustVideo
//
//  Created by 储诚鹏 on 2018/10/26.
//  Copyright © 2018 储诚鹏. All rights reserved.
//

#import "ViewController.h"
#import "AudioToolBox/AudioUnitAUGraph.h"

@interface ViewController ()
{
    AudioUnitAUGraph *au;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    au = [AudioUnitAUGraph defaultAU];
}

- (IBAction)augraphPlay:(UIButton *)sender {
    sender.selected = !sender.selected;
    if (sender.selected) {
         [au start];
    }
    else {
        [au stop];
    }
}


@end
