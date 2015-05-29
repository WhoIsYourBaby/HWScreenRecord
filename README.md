HWScreenRecord
=======================================
集成到APP里面，可以录制手机屏幕+音频
使用方法
-----------------
###1、
将HWScreenRecord.h和HWScreenRecord.m拖入自己的项目中，并包含头文件
###2、
    [[HWScreenRecord shareInterface] prepareForRecording];
准备就绪
###3、
    [[HWScreenRecord shareInterface] startRecording];
开始录制屏幕
###4、
    [[HWScreenRecord shareInterface] stopRecording];
结束录制

# 如果需要手势支持请添加
KTouchPointerWindow
https://github.com/itok/KTouchPointerWindow
# 感谢
kishikawakatsumi的git@github.com:kishikawakatsumi/ScreenRecorder.git，
itok的https://github.com/itok/KTouchPointerWindow
