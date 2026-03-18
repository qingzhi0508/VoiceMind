//
//  SherpaOnnxBridge.mm
//  VoiceRelayMac
//

#import "SherpaOnnxBridge.h"
#import <sherpa-onnx/c-api/c-api.h>

@implementation SherpaOnnxRecognizer {
    SherpaOnnxOnlineRecognizer *_recognizer;
    SherpaOnnxOnlineStream *_stream;
}

- (nullable instancetype)initWithModelPath:(NSString *)modelPath
                                tokensPath:(NSString *)tokensPath
                                sampleRate:(int)sampleRate {
    self = [super init];
    if (self) {
        // 配置识别器参数
        SherpaOnnxOnlineRecognizerConfig config;
        memset(&config, 0, sizeof(config));

        // 设置模型路径
        config.model_config.sense_voice.model = [modelPath UTF8String];
        config.model_config.tokens = [tokensPath UTF8String];
        config.model_config.num_threads = 2;
        config.model_config.provider = "cpu";
        config.model_config.debug = 0;

        // 设置特征提取参数
        config.feat_config.sample_rate = sampleRate;
        config.feat_config.feature_dim = 80;

        // 创建识别器
        _recognizer = SherpaOnnxCreateOnlineRecognizer(&config);
        if (_recognizer == NULL) {
            NSLog(@"❌ Failed to create sherpa-onnx recognizer");
            return nil;
        }

        // 创建音频流
        _stream = SherpaOnnxCreateOnlineStream(_recognizer);
        if (_stream == NULL) {
            NSLog(@"❌ Failed to create sherpa-onnx stream");
            SherpaOnnxDestroyOnlineRecognizer(_recognizer);
            return nil;
        }

        NSLog(@"✅ sherpa-onnx recognizer initialized");
    }
    return self;
}

- (void)acceptWaveform:(const float *)samples count:(int)count {
    if (_stream != NULL) {
        SherpaOnnxOnlineStreamAcceptWaveform(_stream, 16000, samples, count);
    }
}

- (NSString *)getText {
    if (_recognizer == NULL || _stream == NULL) {
        return @"";
    }

    const SherpaOnnxOnlineRecognizerResult *result =
        SherpaOnnxGetOnlineStreamResult(_recognizer, _stream);

    if (result == NULL) {
        return @"";
    }

    NSString *text = [NSString stringWithUTF8String:result->text];
    SherpaOnnxDestroyOnlineRecognizerResult(result);

    return text ? text : @"";
}

- (BOOL)isReady {
    if (_recognizer == NULL || _stream == NULL) {
        return NO;
    }

    return SherpaOnnxIsOnlineStreamReady(_recognizer, _stream) != 0;
}

- (void)reset {
    if (_stream != NULL) {
        SherpaOnnxOnlineStreamReset(_stream);
    }
}

- (void)releaseResources {
    if (_stream != NULL) {
        SherpaOnnxDestroyOnlineStream(_stream);
        _stream = NULL;
    }

    if (_recognizer != NULL) {
        SherpaOnnxDestroyOnlineRecognizer(_recognizer);
        _recognizer = NULL;
    }
}

- (void)dealloc {
    [self releaseResources];
}

@end
