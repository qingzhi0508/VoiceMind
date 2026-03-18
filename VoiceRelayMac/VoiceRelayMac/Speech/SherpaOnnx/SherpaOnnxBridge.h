//
//  SherpaOnnxBridge.h
//  VoiceRelayMac
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// sherpa-onnx 识别器的 Objective-C 桥接
@interface SherpaOnnxRecognizer : NSObject

/// 初始化识别器
/// @param modelPath 模型文件路径 (model.onnx)
/// @param tokensPath 词表文件路径 (tokens.txt)
/// @param sampleRate 采样率（通常为 16000）
- (nullable instancetype)initWithModelPath:(NSString *)modelPath
                                tokensPath:(NSString *)tokensPath
                                sampleRate:(int)sampleRate;

/// 接受音频波形数据
/// @param samples Float32 音频样本数组
/// @param count 样本数量
- (void)acceptWaveform:(const float *)samples count:(int)count;

/// 获取识别文本
/// @return 识别的文本结果
- (NSString *)getText;

/// 检查是否准备好获取结果
/// @return YES 如果有结果可用
- (BOOL)isReady;

/// 重置识别器状态
- (void)reset;

/// 释放资源
- (void)releaseResources;

@end

NS_ASSUME_NONNULL_END
