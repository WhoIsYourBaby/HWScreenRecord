//
//  ViewController.m
//  ScreenShow
//
//  Created by cdsb on 15/5/28.
//  Copyright (c) 2015年 halloworld. All rights reserved.
//

#import "ViewController.h"
#import "HWScreenShow.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [[HWScreenShow shareInterface] prepareForRecording];
    [[HWScreenShow shareInterface] startRecording];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (IBAction)stopTap:(id)sender {
    [[HWScreenShow shareInterface] stopRecording];
}

@end
