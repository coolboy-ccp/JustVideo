//
//  VideoToolBoxFileManager.m
//  JustVideo
//
//  Created by 储诚鹏 on 2018/10/26.
//  Copyright © 2018 储诚鹏. All rights reserved.
//

#import "VideoToolBoxFileManager.h"

@implementation VideoToolBoxFileManager
{
    NSString *filePath;
    NSFileHandle *fileHandle;
}

- (instancetype)initWithFileName:(NSString *)name {
    if (self = [super init]) {
        filePath = [[self documentPath] stringByAppendingString:name];
    }
    return self;
}

- (void)setUpFileHandler {
    [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
    fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
}

- (NSString *)documentPath {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) lastObject];
}

- (void)closeFile {
    [fileHandle closeFile];
    fileHandle = NULL;
}

- (void)writeSps:(NSData *)sps pps:(NSData *)pps {
    if (fileHandle == NULL) {
        [self setUpFileHandler];
    };
    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
    NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
    [fileHandle writeData:ByteHeader];
    [fileHandle writeData:sps];
    [fileHandle writeData:ByteHeader];
    [fileHandle writeData:pps];
}

- (void)writeEncodeData:(NSData *)data {
    if (fileHandle == NULL) {
        [self setUpFileHandler];
    };
    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
    NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
    [fileHandle writeData:ByteHeader];
    [fileHandle writeData:data];
}

- (NSInputStream *)read {
    BOOL fileIsExist = [[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:false];
    NSInputStream *stream = nil;
    if (fileIsExist) {
        stream = [[NSInputStream alloc] initWithFileAtPath:filePath];
    }
    return stream;
}

@end
