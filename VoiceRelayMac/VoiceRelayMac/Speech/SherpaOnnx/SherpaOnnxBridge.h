//
//  SherpaOnnxBridge.h
//  VoiceRelayMac
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// sherpa-onnx 识别器的 Objective-C 桥接（Offline API）
@interface SherpaOnnxRecognizer : NSObject

/// 初始化识别器
/// @param modelPath 模型文件路径 (model.onnx)
/// @param tokensPath 词表文件路径 (tokens.txt)
/// @param language 语言代码 (zh, en, ja, ko, yue)
/// @param sampleRate 采样率（通常为 16000）
- (nullable instancetype)initWithModelPath:(NSString *)modelPath
                                tokensPath:(NSString *)tokensPath
                                  language:(NSString *)language
                                sampleRate:(int)sampleRate;

/// 接受音频波形数据（累积模式）
/// @param samples Float32 音频样本数组
/// @param count 样本数量
- (void)acceptWaveform:(const float *)samples count:(int)count;

/// 执行识别（处理累积的音频）
- (void)decode;

/// 获取识别文本
/// @return 识别的文本结果
- (NSString *)getText;

/// 获取识别的语言（SenseVoice 特性）
/// @return 语言代码
- (NSString *)getLanguage;

/// 获取识别的情感（SenseVoice 特性）
/// @return 情感标签
- (NSString *)getEmotion;

/// 获取识别的事件（SenseVoice 特性）
/// @return 事件标签
- (NSString *)getEvent;

/// 重置识别器状态
- (void)reset;

/// 释放资源
- (void)releaseResources;

@end

NS_ASSUME_NONNULL_END
