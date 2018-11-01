//
//  AudioUnitRecordAndPlay.h
//  JustVideo
//
//  Created by 储诚鹏 on 2018/10/31.
//  Copyright © 2018 储诚鹏. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AudioUnitRecordAndPlay : NSObject
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithURL:(NSString *)url;
- (void)start;
- (void)stop;
@end

NS_ASSUME_NONNULL_END
