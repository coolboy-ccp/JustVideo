//
//  VideoToolBoxFileManager.h
//  JustVideo
//
//  Created by 储诚鹏 on 2018/10/26.
//  Copyright © 2018 储诚鹏. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface VideoToolBoxFileManager : NSObject
- (instancetype)initWithFileName:(NSString *)name;
- (void)closeFile;
- (void)writeSps:(NSData *)sps pps:(NSData *)pps;
- (void)writeEncodeData:(NSData *)data;
- (void)setUpFileHandler;
- (NSInputStream *)read;
@end

NS_ASSUME_NONNULL_END
