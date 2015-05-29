//
//  HWScreenRecord.h
//  ScreenShow
//
//  Created by HalloWorld on 15/5/28.
//  Copyright (c) 2015年 halloworld. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HWScreenRecord : NSObject

+ (instancetype)shareInterface;

@property NSInteger mFrameInterval;                 //FPS = mFrameInterval / 60, 默认值为2

- (void)prepareForRecording;                        //先准备，再开始录音
- (void)startRecording;
- (void)stopRecording;

@end

