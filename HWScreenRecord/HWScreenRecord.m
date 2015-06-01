//
//  HWScreenRecord.m
//  ScreenShow
//
//  Created by HalloWorld on 15/5/28.
//  Copyright (c) 2015年 halloworld. All rights reserved.
//

@import AVFoundation;
@import UIKit;
@import AssetsLibrary;

#import "HWScreenRecord.h"
#import "AppDelegate.h"
#import "KTouchPointerWindow.h"

#define TIME_SCALE 600

static HWScreenRecord *sInterface = NULL;

@interface HWScreenRecord () <AVCaptureAudioDataOutputSampleBufferDelegate>{
    dispatch_queue_t mWriterQueue;
    CMTime mTimeStamp;
    BOOL mIsStart;
}

@property (strong, nonatomic) AVAssetWriter *mWriter;
@property (strong, nonatomic) AVAssetWriterInput *mVideoWriterInput;
@property (strong, nonatomic) AVAssetWriterInput *mAudioWriterInput;
@property (strong, nonatomic) AVAssetWriterInputPixelBufferAdaptor *mWriterAdaptor;
@property (strong, nonatomic) CADisplayLink *mDisplayLink;
@property (strong, nonatomic) AVCaptureSession *mCaptureSession;
@property (strong, nonatomic) AVCaptureConnection *mAudioConnection;

@end

@implementation HWScreenRecord


+ (instancetype)shareInterface {
    if (sInterface == NULL) {
        sInterface = [[HWScreenRecord alloc] init];
    }
    return sInterface;
}

- (void)clearVideos {
    NSString *vDoc = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSArray *vSubFiles = [[NSFileManager defaultManager] subpathsAtPath:vDoc];
    for (NSString *vSub in vSubFiles) {
        NSString *vFulSub = [vDoc stringByAppendingPathComponent:vSub];
        if ([[NSFileManager defaultManager] removeItemAtPath:vFulSub error:nil]) {
            NSLog(@"%s -> %@", __FUNCTION__, vFulSub);
        }
    }
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self clearVideos];
        KTouchPointerWindowInstall();
        self.mFrameInterval = 2;
        NSString *vQueueLabel = @"com.halloworld.screenshow";
        mWriterQueue = dispatch_queue_create([vQueueLabel UTF8String], NULL);
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
        [self screenSize];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (NSString *)defaultFileName {
    time_t timer;
    time(&timer);
    NSString *timestamp = [NSString stringWithFormat:@"%ld", timer];
    return [NSString stringWithFormat:@"%@.mov", timestamp];
}


- (NSURL *)outputFileURL {
    NSString *vFileName = [self defaultFileName];
    NSString *vDoc = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString *vPath = [vDoc stringByAppendingPathComponent:vFileName];
    NSLog(@"%s -> %@", __FUNCTION__, vPath);
    NSURL *vUrl = [NSURL fileURLWithPath:vPath];
    return vUrl;
}


- (void)prepareForRecording {
    NSError *vError = nil;
    self.mWriter = [[AVAssetWriter alloc] initWithURL:[self outputFileURL] fileType:AVFileTypeQuickTimeMovie error:&vError];
    CGSize vSize = [self screenSize];
    
    //Video
    NSDictionary *outputSettings = @{AVVideoCodecKey : AVVideoCodecH264, AVVideoWidthKey : @(vSize.width), AVVideoHeightKey : @(vSize.height)};
    self.mVideoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:outputSettings];
    self.mVideoWriterInput.expectsMediaDataInRealTime = YES;
    
    NSDictionary *sourcePixelBufferAttributes = @{(NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32ARGB)};
    self.mWriterAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:self.mVideoWriterInput
                                                                                           sourcePixelBufferAttributes:sourcePixelBufferAttributes];
    NSParameterAssert(self.mWriter);
    NSParameterAssert([self.mWriter canAddInput:self.mVideoWriterInput]);
    [self.mWriter addInput:self.mVideoWriterInput];
    
    //Audio
    self.mCaptureSession = [[AVCaptureSession alloc] init];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(captureSessionNotification:) name:nil object:self.mCaptureSession];
    
    AVCaptureDevice *vAudioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    AVCaptureDeviceInput *vAudioIn = [[AVCaptureDeviceInput alloc] initWithDevice:vAudioDevice error:nil];
    if ( [self.mCaptureSession canAddInput:vAudioIn] ) {
        [self.mCaptureSession addInput:vAudioIn];
    }
    
    AVCaptureAudioDataOutput *vAudioOut = [[AVCaptureAudioDataOutput alloc] init];
    // Put audio on its own queue to ensure that our video processing doesn't cause us to drop audio
    dispatch_queue_t vAudioCaptureQueue = dispatch_queue_create( "com.apple.sample.capturepipeline.audio", DISPATCH_QUEUE_SERIAL );
    [vAudioOut setSampleBufferDelegate:self queue:vAudioCaptureQueue];
    
    if ( [self.mCaptureSession canAddOutput:vAudioOut] ) {
        [self.mCaptureSession addOutput:vAudioOut];
    }
    self.mAudioConnection = [vAudioOut connectionWithMediaType:AVMediaTypeAudio];
    
    NSDictionary *vOutputSettings = [vAudioOut recommendedAudioSettingsForAssetWriterWithOutputFileType:AVFileTypeQuickTimeMovie];
    self.mAudioWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:vOutputSettings];
    self.mAudioWriterInput.expectsMediaDataInRealTime = YES;
    [self.mWriter addInput:self.mAudioWriterInput];
}

- (void)captureSessionNotification:(NSNotification *)aSender {
    NSLog(@"%s -> %@", __FUNCTION__, aSender.name);
}

- (void)startRecording {
    [self.mWriter startWriting];
//    [self.mWriter startSessionAtSourceTime:kCMTimeZero];
    
    [self.mCaptureSession startRunning];
    
    self.mDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(captureFrame:)];
    self.mDisplayLink.frameInterval = self.mFrameInterval;
    [self.mDisplayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopRecording {
    [self.mDisplayLink invalidate];
    
    dispatch_async(mWriterQueue, ^ {
        if (self.mWriter.status != AVAssetWriterStatusCompleted && self.mWriter.status != AVAssetWriterStatusUnknown) {
            [self.mVideoWriterInput markAsFinished];
        }
        [self.mCaptureSession stopRunning];
        [self.mWriter finishWritingWithCompletionHandler:^ {
            ALAssetsLibrary *vAL = [[ALAssetsLibrary alloc] init];
            [vAL writeVideoAtPathToSavedPhotosAlbum:[self.mWriter outputURL] completionBlock:^(NSURL *assetURL, NSError *error) {
                [[NSFileManager defaultManager] removeItemAtURL:[self.mWriter outputURL] error:nil];
            }];
        }];
    });
}

- (void)applicationDidEnterBackground:(id)sender {
}


- (void)applicationWillEnterForeground:(id)sender {
    NSLog(@"%s -> ", __FUNCTION__);
}


- (CGSize)screenSize {
    UIScreen *vSr = [UIScreen mainScreen];
    return vSr.bounds.size;
}


- (void)captureFrame:(CADisplayLink *)aSender {
    if (!mIsStart) {
        return ;
    }
    dispatch_async(mWriterQueue, ^ {
       if (self.mVideoWriterInput.readyForMoreMediaData) {
           CVReturn vStatus = kCVReturnSuccess;
           CVPixelBufferRef vBuffer = NULL;
           CFTypeRef vBackingData;
           __block UIImage *vScreenshot = nil;
           dispatch_sync(dispatch_get_main_queue(), ^{
               vScreenshot = [self screenshot];
           });
           CGImageRef vImage = vScreenshot.CGImage;
           
           CGDataProviderRef vDataProvider = CGImageGetDataProvider(vImage);
           CFDataRef vData = CGDataProviderCopyData(vDataProvider);
           vBackingData = CFDataCreateMutableCopy(kCFAllocatorDefault, CFDataGetLength(vData), vData);
           CFRelease(vData);
           
           const UInt8 *vBytePtr = CFDataGetBytePtr(vBackingData);
           
           vStatus = CVPixelBufferCreateWithBytes(kCFAllocatorDefault,
                                                 CGImageGetWidth(vImage),
                                                 CGImageGetHeight(vImage),
                                                 kCVPixelFormatType_32BGRA,
                                                 (void *)vBytePtr,
                                                 CGImageGetBytesPerRow(vImage),
                                                 NULL,
                                                 NULL,
                                                 NULL,
                                                 &vBuffer);
           NSParameterAssert(vStatus == kCVReturnSuccess && vBuffer);
           if (vBuffer) {
               if(![self.mWriterAdaptor appendPixelBuffer:vBuffer withPresentationTime:mTimeStamp]) {
                   [self stopRecording];
               }
               CVPixelBufferRelease(vBuffer);
           }
           CFRelease(vBackingData);
       }
    });
}


- (UIImage *)screenshot {
    UIScreen *vMainScreen = [UIScreen mainScreen];
    CGSize vImageSize = vMainScreen.bounds.size;
    UIGraphicsBeginImageContext(vImageSize);
    CGContextRef vContext = UIGraphicsGetCurrentContext();
    UIWindow *vWindow = [(AppDelegate *)[UIApplication sharedApplication].delegate window];
    CGContextSaveGState(vContext);
    CGContextTranslateCTM(vContext, vWindow.center.x, vWindow.center.y);
    CGContextConcatCTM(vContext, [vWindow transform]);
    CGContextTranslateCTM(vContext,
                          -vWindow.bounds.size.width * vWindow.layer.anchorPoint.x,
                          -vWindow.bounds.size.height * vWindow.layer.anchorPoint.y);
    [vWindow.layer.presentationLayer renderInContext:vContext];
    
    CGContextRestoreGState(vContext);
    
    UIImage *vImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return vImage;
}



#pragma mark - Audio Output Delegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    mTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    if (!mIsStart) {
        [self.mWriter startSessionAtSourceTime:mTimeStamp];
        mIsStart = YES;
    }
    if ([self.mWriter status] == AVAssetWriterStatusWriting
        && [self.mAudioWriterInput isReadyForMoreMediaData]
        && connection == self.mAudioConnection
        && mIsStart) {
        if (![self.mAudioWriterInput appendSampleBuffer:sampleBuffer]) {
            NSLog(@"%s -> ", __FUNCTION__);
        }
    }
}

@end

