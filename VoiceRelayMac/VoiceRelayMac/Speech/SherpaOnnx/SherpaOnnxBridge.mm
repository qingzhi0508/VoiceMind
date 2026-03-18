//
//  SherpaOnnxBridge.mm
//  VoiceRelayMac
//

#import "SherpaOnnxBridge.h"
#import <sherpa-onnx/c-api/c-api.h>

@implementation SherpaOnnxRecognizer {
    const SherpaOnnxOfflineRecognizer *_recognizer;
    const SherpaOnnxOfflineStream *_stream;
}

- (nullable instancetype)initWithModelPath:(NSString *)modelPath
                                tokensPath:(NSString *)tokensPath
                                  language:(NSString *)language
                                sampleRate:(int)sampleRate {
    self = [super init];
    if (self) {
        // 配置识别器参数
        SherpaOnnxOfflineRecognizerConfig config;
        memset(&config, 0, sizeof(config));

        // 设置特征提取参数
        config.feat_config.sample_rate = sampleRate;
        config.feat_config.feature_dim = 80;

        // 设置 SenseVoice 模型路径
        config.model_config.sense_voice.model = [modelPath UTF8String];
        config.model_config.sense_voice.language = [language UTF8String];
        config.model_config.sense_voice.use_itn = 1;  // 启用反文本规范化

        // 设置通用模型参数
        config.model_config.tokens = [tokensPath UTF8String];
        config.model_config.num_threads = 2;
        config.model_config.provider = "cpu";
        config.model_config.debug = 0;

        // 创建识别器
        _recognizer = SherpaOnnxCreateOfflineRecognizer(&config);
        if (_recognizer == NULL) {
            NSLog(@"❌ Failed to create sherpa-onnx offline recognizer");
            return nil;
        }

        // 创建音频流
        _stream = SherpaOnnxCreateOfflineStream(_recognizer);
        if (_stream == NULL) {
            NSLog(@"❌ Failed to create sherpa-onnx offline stream");
            SherpaOnnxDestroyOfflineRecognizer(_recognizer);
            return nil;
        }

        NSLog(@"✅ sherpa-onnx offline recognizer initialized");
    }
    return self;
}

- (void)acceptWaveform:(const float *)samples count:(int)count {
    if (_stream != NULL) {
        SherpaOnnxAcceptWaveformOffline(_stream, 16000, samples, count);
    }
}

- (void)decode {
    if (_recognizer != NULL && _stream != NULL) {
        SherpaOnnxDecodeOfflineStream(_recognizer, _stream);
    }
}

- (NSString *)getText {
    if (_recognizer == NULL || _stream == NULL) {
        return @"";
    }

    const SherpaOnnxOfflineRecognizerResult *result =
        SherpaOnnxGetOfflineStreamResult(_stream);

    if (result == NULL) {
        return @"";
    }

    NSString *text = result->text ? [NSString stringWithUTF8String:result->text] : @"";
    SherpaOnnxDestroyOfflineRecognizerResult(result);

    return text;
}

- (NSString *)getLanguage {
    if (_recognizer == NULL || _stream == NULL) {
        return @"";
    }

    const SherpaOnnxOfflineRecognizerResult *result =
        SherpaOnnxGetOfflineStreamResult(_stream);

    if (result == NULL) {
        return @"";
    }

    NSString *lang = result->lang ? [NSString stringWithUTF8String:result->lang] : @"";
    SherpaOnnxDestroyOfflineRecognizerResult(result);

    return lang;
}

- (NSString *)getEmotion {
    if (_recognizer == NULL || _stream == NULL) {
        return @"";
    }

    const SherpaOnnxOfflineRecognizerResult *result =
        SherpaOnnxGetOfflineStreamResult(_stream);

    if (result == NULL) {
        return @"";
    }

    NSString *emotion = result->emotion ? [NSString stringWithUTF8String:result->emotion] : @"";
    SherpaOnnxDestroyOfflineRecognizerResult(result);

    return emotion;
}

- (NSString *)getEvent {
    if (_recognizer == NULL || _stream == NULL) {
        return @"";
    }

    const SherpaOnnxOfflineRecognizerResult *result =
        SherpaOnnxGetOfflineStreamResult(_stream);

    if (result == NULL) {
        return @"";
    }

    NSString *event = result->event ? [NSString stringWithUTF8String:result->event] : @"";
    SherpaOnnxDestroyOfflineRecognizerResult(result);

    return event;
}

- (void)reset {
    if (_stream != NULL) {
        // 销毁旧流并创建新流
        SherpaOnnxDestroyOfflineStream(_stream);
        _stream = SherpaOnnxCreateOfflineStream(_recognizer);
    }
}

- (void)releaseResources {
    if (_stream != NULL) {
        SherpaOnnxDestroyOfflineStream(_stream);
        _stream = NULL;
    }

    if (_recognizer != NULL) {
        SherpaOnnxDestroyOfflineRecognizer(_recognizer);
        _recognizer = NULL;
    }
}

- (void)dealloc {
    [self releaseResources];
}

@end
