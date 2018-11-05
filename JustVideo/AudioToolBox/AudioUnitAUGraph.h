//
//  AudioUnitAUGraph.h
//  JustVideo
//
//  Created by 储诚鹏 on 2018/11/2.
//  Copyright © 2018 储诚鹏. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AudioUnitAUGraph : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)defaultAU;
- (instancetype)initWithUrl:(NSURL *)url;
- (void)start;
- (void)stop;
@end

NS_ASSUME_NONNULL_END
