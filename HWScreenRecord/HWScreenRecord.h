//
//  HWScreenRecord.h
//  ScreenShow
//
//  Created by HalloWorld on 15/5/28.
//  Copyright (c) 2015年 halloworld. All rights reserved.
//

@import Foundation;

@interface HWScreenRecord : NSObject

+ (instancetype)shareInterface;

@property NSInteger mFrameInterval;                 //FPS = mFrameInterval / 60, 默认值为2

@property BOOL mWriteToAlbum;                       //YES：写入系统相册并删除本地document下得文件；NO：写入本地Document

- (void)startRecording;
- (void)stopRecording;

@end

