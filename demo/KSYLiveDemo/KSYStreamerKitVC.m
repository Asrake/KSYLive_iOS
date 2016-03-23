//
//  ViewController.m
//  KSYStreamerVC
//
//  Created by yiqian on 10/15/15.
//  Copyright (c) 2015 ksyun. All rights reserved.
//

#import "KSYStreamerKitVC.h"
#import <libksygpulive/libksygpulive.h>
#import <libksygpulive/libksygpuimage.h>


@interface KSYStreamerKitVC ()
{
    UIButton *_btnMusicPlay;
    UIButton *_btnMusicPause;
    UIButton *_btnMusicMix;
    UIButton *_btnMute;
    
    UISlider *_bgmVolS;
    UISlider *_micVolS;
    // chose filters
    UIButton *_btnFilters[4];
    
    int       _iReverb; // Reverb level
}

@property KSYGPUStreamerKit * kit;



@property UIButton *btnPreview;
@property UIButton *btnTStream;
@property UIButton *btnCamera;
@property UIButton *btnFlash;
@property UISwitch *btnAutoBw;
@property UILabel  *lblAutoBW;
@property UIButton *btnQuit;
@property UISwitch *btnAutoReconnect;
@property UILabel  *lblAutoReconnect;
@property GPUImageFilter     * filter;

@property UIButton *startReverb;
@property UIButton *stopReverb;

@property UISwitch *btnHighRes;
@property UILabel  *lblHighRes;

@property NSTimer *timer;

@property UIView* preview;

@property BOOL bMirrored;

@property double  lastSecond;
@property int  lastByte;
@property int  lastFrames;
@property int  lastDroppedF;
@property int  netEventCnt;

@property NSString  *netEventRaiseDrop;
@property int  netTimeOut;

@property int raiseCnt;
@property int dropCnt;

@property double  startTime;
@end

@implementation KSYStreamerKitVC


-(KSYGPUStreamerKit *)getStreamer {
    return _kit;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self initUI ];
    [self initKSYAuth];
    _kit = [[KSYGPUStreamerKit alloc] initWithDefaultCfg];
    [self setStreamerCfg];
    [self addObservers ];
}

- (void) addObservers {
    // statistics update every seconds
    _timer =  [NSTimer scheduledTimerWithTimeInterval:1.2
                                               target:self
                                             selector:@selector(updateStat:)
                                             userInfo:nil
                                              repeats:YES];
    //KSYStreamer state changes
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onCaptureStateChange:)
                                                 name:KSYCaptureStateDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onStreamStateChange:)
                                                 name:KSYStreamStateDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onNetStateEvent:)
                                                 name:KSYNetStateEventNotification
                                               object:nil];
}
- (void) rmObservers {
    if (_timer) {
        [_timer invalidate];
        _timer = nil;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:KSYCaptureStateDidChangeNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:KSYStreamStateDidChangeNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:KSYNetStateEventNotification
                                                  object:nil];
}

- (UIButton *)addButton:(NSString*)title
                 action:(SEL)action {
    UIButton * button;
    button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [button setTitle: title forState: UIControlStateNormal];
    button.backgroundColor = [UIColor lightGrayColor];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    return button;
}

- (UILabel *)addLable:(NSString*)title{
    UILabel *  lbl = [[UILabel alloc] init];
    lbl.text = title;
    [self.view addSubview:lbl];
    return lbl;
}
- (UISwitch *)addSwitch:(BOOL) on{
    UISwitch *sw = [[UISwitch alloc] init];
    [self.view addSubview:sw];
    sw.on = on;
    return sw;
}

- (void) initUI {
    _btnPreview = [self addButton:@"开始预览" action:@selector(onPreview:)];
    _btnTStream = [self addButton:@"开始推流" action:@selector(onStream:)];
    _btnFlash   = [self addButton:@"闪光灯" action:@selector(onFlash:)];
    _btnCamera  = [self addButton:@"前后摄像头" action:@selector(onCamera:)];
    _btnQuit    = [self addButton:@"退出"      action:@selector(onQuit:)];

    _lblAutoBW = [self addLable:@"自动调码率"];
    _btnAutoBw = [self addSwitch:YES];

    _btnFilters[0] = [self addButton:@"原始美白" action:@selector(OnChoseFilter:)];
    _btnFilters[1] = [self addButton:@"美颜" action:@selector(OnChoseFilter:)];
    _btnFilters[2] = [self addButton:@"白皙" action:@selector(OnChoseFilter:)];
    _btnFilters[3] = [self addButton:@"美白x+" action:@selector(OnChoseFilter:)];
    
    _startReverb =[self addButton:@"开始混响" action:@selector(onReverbStart:)];
    NSString * SReverb = [NSString stringWithFormat:@"开始混响%d",_iReverb];
    [_startReverb setTitle:SReverb  forState: UIControlStateNormal];
    _stopReverb = [self addButton:@"停止混响" action:@selector(onReverbStop:)];
    _iReverb    = 1;
    
    _btnMusicPlay  = [self addButton:@"播放"  action:@selector(onMusicPlay:)];
    _btnMusicPause = [self addButton:@"暂停"  action:@selector(onMusicPause:)];
    _btnMusicMix   = [self addButton:@"混音"  action:@selector(onMusicMix:)];
    
    _bgmVolS     = [self addSliderFrom:0.0 To:1.0];
    _micVolS     = [self addSliderFrom:0.0 To:1.0];
    _micVolS.value = 1.0;
    _btnMute    = [self addButton:@"静音"   action:@selector(onStreamMute:)];

    
    _lblAutoReconnect = [self addLable:@"自动重连"];
    _btnAutoReconnect = [self addSwitch:NO];

    _lblHighRes =[self addLable:@"高分辨率"];
    _btnHighRes =[self addSwitch:NO];

    _stat = [self addLable:@""];
    _stat.backgroundColor = [UIColor clearColor];
    _stat.textColor = [UIColor redColor];
    _stat.numberOfLines = 6;
    _stat.textAlignment = NSTextAlignmentLeft;

    self.view.backgroundColor = [UIColor whiteColor];
    _netEventRaiseDrop = @"";
    [self layoutUI];
}

- (void) layoutUI {
    CGFloat wdt = self.view.bounds.size.width;
    CGFloat hgt = self.view.bounds.size.height;
    CGFloat gap = 4;
    CGFloat btnWdt = 100;
    CGFloat btnHgt = 40;
    CGFloat yPos = hgt - btnHgt - gap;
    CGFloat xLeft   = gap;
    CGFloat xMiddle = (wdt - btnWdt*3 - gap*2) /2 + gap + btnWdt;
    CGFloat xRight  = wdt - btnWdt - gap;
    // full screen
    _preview.frame = self.view.bounds;
    
    // bottom left
    _btnPreview.frame = CGRectMake(xLeft,   yPos, btnWdt, btnHgt);
    _btnTStream.frame = CGRectMake(xRight, yPos, btnWdt, btnHgt);
    
    // top left
    yPos = 20+gap*3;
    _btnFlash.frame  = CGRectMake(xLeft,   yPos, btnWdt, btnHgt);
    _btnCamera.frame = CGRectMake(xMiddle, yPos, btnWdt, btnHgt);
    _btnQuit.frame   = CGRectMake(xRight,  yPos, btnWdt, btnHgt);
    
    // top row 2 left
    yPos += (gap + btnHgt);
    _lblAutoBW.frame        = CGRectMake(xLeft,   yPos, btnWdt, btnHgt);
    _lblHighRes.frame       = CGRectMake(xMiddle, yPos, btnWdt, btnHgt);
    _lblAutoReconnect.frame = CGRectMake(xRight,  yPos, btnWdt, btnHgt);
    
    // top row 3 left
    yPos += (btnHgt);
    _btnAutoBw.frame        = CGRectMake(xLeft,   yPos, btnWdt, btnHgt);
    _btnHighRes.frame       = CGRectMake(xMiddle, yPos, btnWdt, btnHgt);
    _btnAutoReconnect.frame = CGRectMake(xRight,  yPos, btnWdt, btnHgt);
    
    // top row 4 left
    yPos += (btnHgt);
    _btnMusicPlay.frame   = CGRectMake(xLeft,   yPos, btnWdt, btnHgt);
    _btnMusicPause.frame  = CGRectMake(xMiddle, yPos, btnWdt, btnHgt);
    _btnMusicMix.frame    = CGRectMake(xRight,  yPos, btnWdt, btnHgt);
    
    // top row 5 left
    yPos += (btnHgt+2);
    _bgmVolS.frame    = CGRectMake(xLeft,   yPos, btnWdt, btnHgt);
    _micVolS.frame    = CGRectMake(xMiddle, yPos, btnWdt, btnHgt);
    _btnMute.frame    = CGRectMake(xRight,  yPos, btnWdt, btnHgt);
    
    yPos += (btnHgt+20);
    _btnFilters[0].frame = CGRectMake(xLeft,   yPos, btnWdt, btnHgt);
    _startReverb.frame = CGRectMake(xRight,   yPos, btnWdt, btnHgt);
    
    yPos += (btnHgt+5);
    _btnFilters[1].frame = CGRectMake(xLeft,   yPos, btnWdt, btnHgt);
    _stopReverb.frame = CGRectMake(xRight,   yPos, btnWdt, btnHgt);
    yPos += (btnHgt+5);
    _btnFilters[2].frame = CGRectMake(xLeft,   yPos, btnWdt, btnHgt);
    yPos += (btnHgt+5);
    _btnFilters[3].frame = CGRectMake(xLeft,   yPos, btnWdt, btnHgt);
    // top row 5
    yPos += ( btnHgt);
    btnWdt = self.view.bounds.size.width - gap*2;
    btnHgt = hgt - yPos - btnHgt;
    _stat.frame = CGRectMake(gap, yPos , btnWdt, btnHgt);
}

- (void)viewDidAppear:(BOOL)animated {
    if ( _btnAutoBw != nil ) {
        [self layoutUI];
    }
    if (_bAutoStart) {
        [self onPreview:nil];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self onStream:nil];
        });
    }
}

- (BOOL)shouldAutorotate {
    BOOL  bShould = _kit.captureState != KSYCaptureStateCapturing;
    [self layoutUI];
    return bShould;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

const char * getDocPath () ;

- (void) setStreamerCfg {
    // capture settings
    if (_btnHighRes.on ) {
        _kit.videoDimension = KSYVideoDimension_16_9__960x540;
    }
    else {
        _kit.videoDimension = KSYVideoDimension_16_9__640x360;

    }
    _kit.streamerBase.videoCodec = KSYVideoCodec_X264;
    _kit.videoFPS = 15;
    [self.view autoresizesSubviews];
    
    // stream settings
    _kit.streamerBase.videoInitBitrate = 1000; // k bit ps
    _kit.streamerBase.videoMaxBitrate  = 1000; // k bit ps
    _kit.streamerBase.videoMinBitrate  = 100; // k bit ps
    _kit.streamerBase.audiokBPS        = 48; // k bit ps
    _kit.streamerBase.enAutoApplyEstimateBW = _btnAutoBw.on;
    
    // rtmp server info
    // stream name = 随机数 + codec名称 （构造流名，避免多个demo推向同一个流）
    NSString *devCode  = [ [KSYAuthInfo sharedInstance].mCode substringToIndex:3];
    NSString *codecSuf = _kit.streamerBase.videoCodec == KSYVideoCodec_X264 ? @"264" : @"265";
    NSString *streamName = [NSString stringWithFormat:@"%@.%@", devCode, codecSuf ];
    
    // hostURL = rtmpSrv + streamName
    NSString *rtmpSrv  = @"rtmp://test.uplive.ksyun.com/live";
    NSString *url      = [  NSString stringWithFormat:@"%@/%@", rtmpSrv, streamName];
    _hostURL = [[NSURL alloc] initWithString:url];
    [self setVideoOrientation];
}

- (IBAction)onQuit:(id)sender {
    [_kit.streamerBase stopStream];
    [_kit stopPreview];
    [self dismissViewControllerAnimated:FALSE completion:nil];
}

- (IBAction)onPreview:(id)sender {
    if ( NO == _btnPreview.isEnabled) {
        return;
    }
    if ( _kit.captureState != KSYCaptureStateCapturing ) {
        [self setStreamerCfg];
        [_kit startPreview: self.view];
        [UIApplication sharedApplication].idleTimerDisabled=YES;
    }
    else {
        [_kit stopPreview];
        [UIApplication sharedApplication].idleTimerDisabled=NO;
    }
}

- (IBAction)onStream:(id)sender {
    if (_kit.captureState != KSYCaptureStateCapturing ||
        NO == _btnTStream.isEnabled ) {
        return;
    }
    if (_kit.streamerBase.streamState != KSYStreamStateConnected) {
        [_kit.streamerBase startStream: _hostURL];
        [self initStatData];
    }
    else {
        [_kit.streamerBase stopStream];
    }
}

- (IBAction)onFlash:(id)sender {
    [_kit toggleTorch ];
    //[_kit setPreviewMirrored:_bMirrored];
    //_bMirrored= !_bMirrored;
}

- (IBAction)onCamera:(id)sender {
    if ( [_kit switchCamera ] == NO) {
        NSLog(@"切换失败 当前采集参数 目标设备无法支持");
    }
    BOOL backCam = (_kit.cameraPosition == AVCaptureDevicePositionBack);
    if ( backCam ) {
        [_btnCamera setTitle:@"切到前摄像" forState: UIControlStateNormal];
    }
    else {
        [_btnCamera setTitle:@"切到后摄像" forState: UIControlStateNormal];
    }
    backCam = backCam && (_kit.captureState == KSYCaptureStateCapturing);
    [_btnFlash  setEnabled:backCam ];
}

- (void) initStatData {
    _lastByte    = 0;
    _lastSecond  = [[NSDate date]timeIntervalSince1970];
    _lastFrames  = 0;
    _netEventCnt = 0;
    _raiseCnt    = 0;
    _dropCnt     = 0;
    _startTime   =  [[NSDate date]timeIntervalSince1970];
}

- (NSString*) sizeFormatted : (int )KB {
    if ( KB > 1000 ) {
        double MB   =  KB / 1000.0;
        return [NSString stringWithFormat:@" %4.2f MB", MB];
    }
    else {
        return [NSString stringWithFormat:@" %d KB", KB];
    }
}

- (void)updateStat:(NSTimer *)theTimer{
    if (_kit.streamerBase.streamState == KSYStreamStateConnected ) {
        int    KB          = [_kit.streamerBase uploadedKByte];
        int    curFrames   = [_kit.streamerBase encodedFrames];
        int    droppedF    = [_kit.streamerBase droppedVideoFrames];

        int deltaKbyte = KB - _lastByte;
        double curTime = [[NSDate date]timeIntervalSince1970];
        double deltaTime = curTime - _lastSecond;
        double realKbps = deltaKbyte*8 / deltaTime;   // deltaByte / deltaSecond
        
        double deltaFrames =(curFrames - _lastFrames);
        double fps = deltaFrames / deltaTime;
        
        double dropRate = (droppedF - _lastDroppedF ) / deltaTime;
        _lastByte     = KB;
        _lastSecond   = curTime;
        _lastFrames   = curFrames;
        _lastDroppedF = droppedF;
        NSString *uploadDateSize = [ self sizeFormatted:KB ];
        NSString* stateurl  = [NSString stringWithFormat:@"%@\n", [_hostURL absoluteString]] ;
        NSString* statekbps = [NSString stringWithFormat:@"realtime:%4.1fkbps %@\n", realKbps, _netEventRaiseDrop];
        NSString* statefps  = [NSString stringWithFormat:@"%2.1f fps | %@  | %@ \n", fps, uploadDateSize, [self timeFormatted: (int)(curTime-_startTime) ] ];
        NSString* statedrop = [NSString stringWithFormat:@"dropFrame %4d | %3.1f | %2.1f%% \n", droppedF, dropRate, droppedF * 100.0 / curFrames ];

        NSString* netEvent = [NSString stringWithFormat:@"netEvent %d notGood | %d raise | %d drop", _netEventCnt, _raiseCnt, _dropCnt];
        
        _stat.text = [ stateurl    stringByAppendingString:statekbps ];
        _stat.text = [ _stat.text  stringByAppendingString:statefps  ];
        _stat.text = [ _stat.text  stringByAppendingString:statedrop ];
        _stat.text = [ _stat.text  stringByAppendingString:netEvent  ];

        if (_netTimeOut == 0) {
            _netEventRaiseDrop = @" ";
        }
        else {
            _netTimeOut--;
        }
    }
}

- (IBAction)onTap:(id)sender {
    CGPoint point = [sender locationInView:self.view];
    CGPoint tap;
    tap.x = (point.x/self.view.frame.size.width);
    tap.y = (point.y/self.view.frame.size.height);
    NSError __autoreleasing *error;
    [self focusAtPoint:tap error:&error];
}

- (BOOL)focusAtPoint:(CGPoint )point error:(NSError *__autoreleasing* )error
{
    AVCaptureDevice *dev = [_kit getCurrentCameraDevices];
    if ([dev isFocusPointOfInterestSupported] && [dev isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        if ([dev lockForConfiguration:error]) {
            [dev setFocusPointOfInterest:point];
            [dev setFocusMode:AVCaptureFocusModeAutoFocus];
            NSLog(@"Focusing..");
            [dev unlockForConfiguration];
            return YES;
        }
    }
    return NO;
}

- (void) onCaptureStateChange:(NSNotification *)notification {
    // init stat
    [_btnTStream setEnabled:NO];
    [_btnAutoBw  setEnabled:YES];
    [_btnHighRes setEnabled:YES];
    [_btnFlash   setEnabled:NO];
    if ( _kit.captureState == KSYCaptureStateIdle){
        _stat.text = @"idle";
        [_btnPreview setEnabled:YES];
        [_btnPreview setTitle:@"StartPreview" forState:UIControlStateNormal];
    }
    else if (_kit.captureState == KSYCaptureStateCapturing ) {
        _stat.text = @"capturing";
        [_btnPreview setEnabled:YES];
        [_btnTStream setEnabled:YES];
        [_btnPreview setTitle:@"StopPreview" forState:UIControlStateNormal];
        BOOL backCam = (_kit.cameraPosition == AVCaptureDevicePositionBack);
        [_btnFlash   setEnabled:backCam];
        [_btnAutoBw  setEnabled:NO];
        [_btnHighRes setEnabled:NO];
    }
    else if (_kit.captureState == KSYCaptureStateClosingCapture ) {
        _stat.text = @"closing capture";
        [_btnPreview setEnabled:NO];
    }
    else if (_kit.captureState == KSYCaptureStateDevAuthDenied ) {
        _stat.text = @"camera/mic Authorization Denied";
        [_btnPreview setEnabled:YES];
    }
    else if (_kit.captureState == KSYCaptureStateParameterError ) {
        _stat.text = @"capture devices ParameterError";
        [_btnPreview setEnabled:YES];
    }
    else if (_kit.captureState == KSYCaptureStateDevBusy ) {
        _stat.text = @"device busy, try later";
        [self toast:_stat.text];
    }
    NSLog(@"newCapState: %lu [%@]", (unsigned long)_kit.captureState, _stat.text);
}

- (void) onStreamError {
    KSYStreamErrorCode err = _kit.streamerBase.streamErrorCode;
    [_btnPreview setEnabled:TRUE];
    [_btnTStream setEnabled:TRUE];
    [_btnTStream setTitle:@"StartStream" forState:UIControlStateNormal];
    [self toast:@"stream err"];
    if ( KSYStreamErrorCode_KSYAUTHFAILED == err ) {
        _stat.text = @"SDK auth failed, \npls check ak/sk";
    }
    else if ( KSYStreamErrorCode_CODEC_OPEN_FAILED == err) {
        _stat.text = @"Selected Codec not supported \n in this version";
    }
    else if ( KSYStreamErrorCode_CONNECT_FAILED == err) {
        _stat.text = @"Connecting error, pls check host url \nor network";
    }
    else if ( KSYStreamErrorCode_CONNECT_BREAK == err) {
        _stat.text = @"Connection break";
    }
    else if (  KSYStreamErrorCode_RTMP_NonExistDomain   == err) {
        _stat.text = @"error: NonExistDomain";
    }
    else if (  KSYStreamErrorCode_RTMP_NonExistApplication   == err) {
        _stat.text = @"error: NonExistApplication";
    }
    else if (  KSYStreamErrorCode_RTMP_AlreadyExistStreamName   == err) {
        _stat.text = @"error: AlreadyExistStreamName";
    }
    else if (  KSYStreamErrorCode_RTMP_ForbiddenByBlacklist   == err) {
        _stat.text = @"error: ForbiddenByBlacklist";
    }
    else if (  KSYStreamErrorCode_RTMP_InternalError   == err) {
        _stat.text = @"error: InternalError";
    }
    else if (  KSYStreamErrorCode_RTMP_URLExpired   == err) {
        _stat.text = @"error: URLExpired";
    }
    else if (  KSYStreamErrorCode_RTMP_SignatureDoesNotMatch   == err) {
        _stat.text = @"error: SignatureDoesNotMatch";
    }
    else if (  KSYStreamErrorCode_RTMP_InvalidAccessKeyId   == err) {
        _stat.text = @"error: InvalidAccessKeyId";
    }
    else if (  KSYStreamErrorCode_RTMP_BadParams   == err) {
        _stat.text = @"error: BadParams";
    }
    else if (  KSYStreamErrorCode_RTMP_ForbiddenByRegion   == err) {
        _stat.text = @"error: ForbiddenByRegion";
    }
    else {
        _stat.text = [[NSString alloc] initWithFormat:@"error: %lu",  (unsigned long)err];
    }
    NSLog(@"onErr: %lu [%@]", (unsigned long) err, _stat.text);
    // 断网重连
    if ( KSYStreamErrorCode_CONNECT_BREAK == err && _btnAutoReconnect.isOn ) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [_kit.streamerBase stopStream];
            [_kit.streamerBase startStream:_hostURL];
            [self initStatData];
        });
    }
}

- (void) onNetStateEvent:(NSNotification *)notification {
    KSYNetStateCode netEvent = _kit.streamerBase.netStateCode;
    //NSLog(@"net event : %ld", (unsigned long)netEvent );
    if ( netEvent == KSYNetStateCode_SEND_PACKET_SLOW ) {
        _netEventCnt++;
        if (_netEventCnt % 10 == 9) {
            [self toast:@"bad network"];
        }
        NSLog(@"bad network" );
    }
    else if ( netEvent == KSYNetStateCode_EST_BW_RAISE ) {
        _netEventRaiseDrop = @"raising";
        _raiseCnt++;
        _netTimeOut = 5;
        NSLog(@"bitrate raising" );
    }
    else if ( netEvent == KSYNetStateCode_EST_BW_DROP ) {
        _netEventRaiseDrop = @"dropping";
        _dropCnt++;
        _netTimeOut = 5;
        NSLog(@"bitrate dropping" );
    }
}

- (void) onStreamStateChange:(NSNotification *)notification {
    [_btnPreview setEnabled:NO];
    [_btnTStream setEnabled:NO];
    if ( _kit.streamerBase.streamState == KSYStreamStateIdle) {
        _stat.text = @"idle";
        [_btnPreview setEnabled:TRUE];
        [_btnTStream setEnabled:TRUE];
        [_btnTStream setTitle:@"StartStream" forState:UIControlStateNormal];
    }
    else if ( _kit.streamerBase.streamState == KSYStreamStateConnected){
        _stat.text = @"connected";
        [_btnTStream setEnabled:TRUE];
        [_btnTStream setTitle:@"StopStream" forState:UIControlStateNormal];
    }
    else if (_kit.streamerBase.streamState == KSYStreamStateConnecting ) {
        _stat.text = @"kit connecting";
    }
    else if (_kit.streamerBase.streamState == KSYStreamStateDisconnecting ) {
        _stat.text = @"disconnecting";
    }
    else if (_kit.streamerBase.streamState == KSYStreamStateError ) {
        [self onStreamError];
    }
    NSLog(@"newState: %lu [%@]", (unsigned long)_kit.streamerBase.streamState, _stat.text);
}

- (void) setVideoOrientation {
    UIDeviceOrientation orien = [ [UIDevice  currentDevice]  orientation];
    switch (orien) {
        case UIDeviceOrientationPortraitUpsideDown:
            _kit.videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        case UIDeviceOrientationLandscapeLeft:
            _kit.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        case UIDeviceOrientationLandscapeRight:
            _kit.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        default:
            _kit.videoOrientation = AVCaptureVideoOrientationPortrait;
            break;
    }
}

- (void) toast:(NSString*)message{
    UIAlertView *toast = [[UIAlertView alloc] initWithTitle:nil
                                                    message:message
                                                   delegate:nil
                                          cancelButtonTitle:nil
                                          otherButtonTitles:nil, nil];
    [toast show];
    double duration = 0.3; // duration in seconds
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [toast dismissWithClickedButtonIndex:0 animated:YES];
    });
}

- (NSString *)timeFormatted:(int)totalSeconds
{
    int seconds = totalSeconds % 60;
    int minutes = (totalSeconds / 60) % 60;
    int hours = totalSeconds / 3600;
    return [NSString stringWithFormat:@"%02d:%02d:%02d",hours, minutes, seconds];
}

-(IBAction)OnChoseFilter:(id)sender {
    for (int b = 0; b < 4; ++b) {
        if (sender == _btnFilters[b]) {
            _btnFilters[b].enabled = NO;
        }
        else {
            _btnFilters[b].enabled = YES;
        }
    }
    if( sender == _btnFilters[0]) {
        _filter = [[KSYGPUBeautifyExtFilter alloc] init];
    }
    else if( sender == _btnFilters[1]) {
        _filter = [[KSYGPUBeautifyFilter alloc] init];
    }
    else if( sender == _btnFilters[2]) {
        _filter = [[KSYGPUDnoiseFilter alloc] init];
    }
    else if( sender == _btnFilters[3])    {
        _filter = [[KSYGPUBeautifyPlusFilter alloc] init];
    }
    
    [_kit setupFilter:_filter];
}


-(IBAction)onReverbStart:(id)sender {
    [_kit.streamerBase enableReverb:_iReverb];
    
    _startReverb.enabled = NO;
    _stopReverb.enabled = YES;
    
    _iReverb++;
    _iReverb = _iReverb % 4;
    NSString * SReverb = [NSString stringWithFormat:@"开始混响%d",_iReverb];
    [sender setTitle:SReverb  forState: UIControlStateNormal];
} // Reverb

-(IBAction)onReverbStop:(id)sender{
    [_kit.streamerBase unableReverb];
    _startReverb.enabled = YES;
    _stopReverb.enabled = NO;
} //Reverb

- (IBAction)onMusicPlay:(id)sender {
    NSString *testMp3 = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/test.mp3"];
    static int i = 0;
    i = !i;
    if (i) {
        NSLog(@"bgm start %@", testMp3);
        _kit.streamerBase.bgmFinishBlock = ^{
            NSLog(@"bgm over %@", testMp3);
        };
        [_kit.streamerBase startMixMusic:testMp3 isLoop:NO];
    }
    else {
        [_kit.streamerBase stopMixMusic];
    }
}

- (IBAction)onMusicPause:(id)sender {
    static int i = 0;
    i = !i;
    if (i) {
        [_kit.streamerBase pauseMixMusic];
    }
    else {
        [_kit.streamerBase resumeMixMusic];
    }
}

- (IBAction)onMusicMix:(id)sender {
    static BOOL i = NO;
    i = !i;
    [_kit.streamerBase enableMicMixMusic:i];
}


- (UISlider *)addSliderFrom: (float) minV
                         To: (float) maxV{
    UISlider *sl = [[UISlider alloc] init];
    [self.view addSubview:sl];
    sl.minimumValue = minV;
    sl.maximumValue = maxV;
    sl.value = 0.5;
    [ sl addTarget:self action:@selector(onVolChanged:) forControlEvents:UIControlEventValueChanged ];
    return sl;
}

- (IBAction)onVolChanged:(id)sender {
    if (sender == _bgmVolS) {
        [_kit.streamerBase setBgmVolume:_bgmVolS.value];
    }
    else if (sender == _micVolS) {
        [_kit.streamerBase setMicVolume:_micVolS.value];
    }
}


- (IBAction)onStreamMute:(id)sender {
    static BOOL i = NO;
    i = !i;
    if (_kit.streamerBase){
        [_kit.streamerBase muteStreame:i];
    }
}

/**
 @abstrace 初始化金山云认证信息
 @discussion 开发者帐号fpzeng，其他信息如下：
 
 * appid: QYA0EEF0FDDD38C79913
 * ak: abc73bb5ab2328517415f8f52cd5ad37
 * sk: sff25dc4a428479ff1e20ebf225d113
 * sksign: md5(sk+tmsc)
 
 以上信息为错误ak/sk，请联系haomingfei@kingsoft.com获取正确认证信息。
 
 @warning 请将appid/ak/sk信息更新至开发者自己信息，再进行编译测试
 */
- (void)initKSYAuth {
    NSString* time = [NSString stringWithFormat:@"%d",(int)[[NSDate date]timeIntervalSince1970]];
    NSString* sk = [NSString stringWithFormat:@"s77d5c0eef4aaeff62e43d89f1b12a25%@", time];
    NSString* sksign = [KSYAuthInfo KSYMD5:sk];
    [[KSYAuthInfo sharedInstance]setAuthInfo:@"QYA0E0639AC997A8D128" accessKey:@"a5644305efa79b56b8dac55378b83e35" secretKeySign:sksign timeSeconds:time];
}

@end
