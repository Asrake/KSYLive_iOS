#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "KSYStreamerBase.h"

@class KSYGPUCamera;
@class GPUImageFilter;
@class GPUImageView;

@interface KSYGPUStreamerKit : NSObject
/**
 @abstract 初始化方法
 @discussion 创建带有默认参数的 KSYGPUStreamer
 
 @warning KSYGPUStreamer只支持单实例推流，构造多个实例会出现异常
 */
- (instancetype) initWithDefaultCfg;

#pragma mark - capture state
/**
 @abstract 当前采集设备状况
 @discussion 可以通过该属性获取采集设备的工作状况
 
 @discussion 通知：
 * KSYCaptureStateDidChangeNotification 当采集设备工作状态发生变化时提供通知
 * 收到通知后，通过本属性查询新的状态，并作出相应的动作
 */
@property (nonatomic, readonly) KSYCaptureState captureState;

/**
 @abstract   获取采集状态对应的字符串
 */
- (NSString*) getCaptureStateName : (KSYCaptureState) stat;

/**
 @abstract   获取当前采集状态对应的字符串
 */
- (NSString*) getCurCaptureStateName;

// Posted when capture state changes
FOUNDATION_EXPORT NSString *const KSYCaptureStateDidChangeNotification NS_AVAILABLE_IOS(7_0);

#pragma mark - capture actions
/**
 @abstract 启动预览
 @param view 预览画面作为subview，插入到 view 的最底层
 @discussion 设置完成采集参数之后，按照设置值启动预览，启动后对采集参数修改不会生效
 @discussion 需要访问摄像头和麦克风的权限，若授权失败，其他API都会拒绝服务
 
 @warning: 开始推流前必须先启动预览
 @see videoDimension, cameraPosition, videoOrientation, videoFPS
 */
- (void) startPreview: (UIView*) view;

/**
 @abstract   停止预览，停止采集设备，并清理会话
 @discussion 若推流未结束，则先停止推流
 
 @see stopStream
 */
- (void) stopPreview;

/**
 @abstract   设置当前使用的滤镜
 @discussion 若filter 为nil， 则关闭滤镜
 @discussion 若filter 为GPUImageFilter的实例，则使用该滤镜做处理
 
 @see GPUImageFilter
 */
- (void) setupFilter:(GPUImageFilter*) filter;

#pragma mark - get sub modules
/**
 @abstract   获取初始化时创建的底层推流工具
 @discussion 1. 通过它来设置推流参数
 @discussion 2. 通过它来启动，停止推流
 */
@property (nonatomic, readonly) KSYStreamerBase*   streamerBase;

/**
 @abstract   获取开始推流后的采集设备
 @discussion 通过该指针可以对摄像头进行操作
 */
@property (nonatomic, readonly) KSYGPUCamera*   capDev;

/**
 @abstract   获取当前使用的滤镜
 @discussion 通过此指针可以对滤镜参数进行设置
 */
@property (nonatomic, readonly) GPUImageFilter* filter;

/**
 @abstract   获取预览视图
 @discussion 通过此指针可以对预览视图进行操作
 */
@property (nonatomic, readonly) GPUImageView*   preview;

#pragma mark - capture settings

/**
 @abstract   视频帧率
 @discussion video frame per seconds 有效范围[1~30], 超出会提示参数错误
 */
@property (nonatomic, assign) int                       videoFPS;

/**
 @abstract   视频分辨率
 @discussion width x height （ 此处width始终大于高度，是否竖屏取决于videoOrientation的值 )
 
 @see KSYVideoDimension, videoOrientation
 */
@property (nonatomic, assign) KSYVideoDimension        videoDimension;

/**
 @abstract   用户定义的视频分辨率
 @discussion 当videoDimension 设置为 KSYVideoDimension_UserDefine_* 时有效
 @discussion 内部始终将较大的值作为宽度 (若需要竖屏，请设置 videoOrientation）
 @discussion 宽高都会向上取整为4的整数倍
 @discussion 宽度有效范围[160, 1280]
 @discussion 高度有效范围[ 90,  720], 超出范围会提示参数错误
 @see KSYVideoDimension, videoOrientation
 */
@property (nonatomic, assign) CGSize        videoDimensionUserDefine;

/**
 @abstract   摄像头位置
 @discussion 前后摄像头
 */
@property (nonatomic, assign) AVCaptureDevicePosition   cameraPosition;

/**
 @abstract   摄像头朝向
 @discussion (1~4):down up right left (home button)
 @discussion down,up: width < height
 @discussion right,left: width > height
 @discussion 需要与UI方向一致
 */
@property (nonatomic, assign) AVCaptureVideoOrientation videoOrientation;

/**
 @abstract   AVCaptureVideoOrientation / UIInterfaceOrientation
 */
+ (AVCaptureVideoOrientation) getCapOrientation: (UIInterfaceOrientation) orien ;


#pragma mark - camera operation
/**
 @abstract   切换摄像头
 @return     TRUE: 成功切换摄像头， FALSE：当前参数，下一个摄像头不支持，切换失败
 @discussion 在前后摄像头间切换，从当前的摄像头切换到另一个，切换成功则修改cameraPosition的值
 @discussion 开始预览后开始有效，推流过程中也响应切换请求
 
 @see cameraPosition
 */
- (BOOL) switchCamera;

/**
 @abstract   当前采集设备是否支持闪光灯
 @return     YES / NO
 @discussion 通常只有后置摄像头支持闪光灯
 
 @see setTorchMode
 */
- (BOOL) isTorchSupported;

/**
 @abstract   开关闪光灯
 @discussion 切换闪光灯的开关状态 开 <--> 关
 
 @see setTorchMode
 */
- (void) toggleTorch;

/**
 @abstract   设置闪光灯
 @param      mode  AVCaptureTorchModeOn/Off
 @discussion 设置闪光灯的开关状态
 @discussion 开始预览后开始有效
 
 @see AVCaptureTorchMode
 */
- (void) setTorchMode: (AVCaptureTorchMode)mode;

/**
 @abstract   获取当前采集设备的指针
 
 @discussion 开放本指针的目的是开放类似下列添加到AVCaptureDevice的 categories：
 - AVCaptureDeviceFlash
 - AVCaptureDeviceTorch
 - AVCaptureDeviceFocus
 - AVCaptureDeviceExposure
 - AVCaptureDeviceWhiteBalance
 - etc.
 
 @return AVCaptureDevice* 预览开始前调用返回为nil，开始预览后，返回当前正在使用的摄像头
 
 @warning  请勿修改摄像头的像素格式，帧率，分辨率等参数，修改后会导致推流工作异常或崩溃
 @see AVCaptureDevice  AVCaptureDeviceTorch AVCaptureDeviceFocus
 */
- (AVCaptureDevice*) getCurrentCameraDevices;

@end
