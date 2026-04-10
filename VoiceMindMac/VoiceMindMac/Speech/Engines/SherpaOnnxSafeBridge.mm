#import "SherpaOnnxSafeBridge.h"
#include <sherpa-onnx/c-api/c-api.h>
#include <cstring>
#include <exception>
#include <string>

@implementation SherpaOnnxSafeBridge

+ (void *)createParaformerRecognizerWithEncoder:(NSString *)encoderPath
                                        decoder:(NSString *)decoderPath
                                         tokens:(NSString *)tokensPath
                                     modelType:(NSString *)modelType
                                    sampleRate:(int32_t)sampleRate
                                    numThreads:(int32_t)numThreads
                                          error:(NSString **)errorMessage {
    try {
        SherpaOnnxOnlineRecognizerConfig config;
        memset(&config, 0, sizeof(config));

        // Feature config
        config.feat_config.sample_rate = sampleRate;
        config.feat_config.feature_dim = 80;

        // Model config
        config.model_config.num_threads = numThreads;
        config.model_config.provider = "cpu";
        config.model_config.debug = 1;
        config.model_config.model_type = modelType.UTF8String;
        config.model_config.tokens = tokensPath.UTF8String;

        // Paraformer-specific
        config.model_config.paraformer.encoder = encoderPath.UTF8String;
        config.model_config.paraformer.decoder = decoderPath.UTF8String;

        // Recognizer config
        config.decoding_method = "greedy_search";
        config.max_active_paths = 4;
        config.enable_endpoint = 0;

        NSLog(@"🔧 SafeBridge: Creating paraformer recognizer");
        NSLog(@"   encoder: %@", encoderPath);
        NSLog(@"   decoder: %@", decoderPath);
        NSLog(@"   tokens: %@", tokensPath);
        NSLog(@"   model_type: %@", modelType);
        NSLog(@"   sizeof(SherpaOnnxOnlineModelConfig) = %lu", sizeof(SherpaOnnxOnlineModelConfig));
        NSLog(@"   sizeof(SherpaOnnxOnlineRecognizerConfig) = %lu", sizeof(SherpaOnnxOnlineRecognizerConfig));

        const SherpaOnnxOnlineRecognizer *recognizer =
            SherpaOnnxCreateOnlineRecognizer(&config);

        if (recognizer == nullptr) {
            if (errorMessage) {
                *errorMessage = @"SherpaOnnxCreateOnlineRecognizer returned NULL";
            }
        }
        return (void *)recognizer;
    } catch (const std::exception &e) {
        if (errorMessage) {
            *errorMessage = [NSString stringWithFormat:@"C++ exception: %s", e.what()];
        }
        return nil;
    } catch (...) {
        if (errorMessage) {
            *errorMessage = @"Unknown C++ exception while creating Sherpa-ONNX recognizer";
        }
        return nil;
    }
}

+ (void *)createTransducerRecognizerWithEncoder:(NSString *)encoderPath
                                         decoder:(NSString *)decoderPath
                                          joiner:(NSString *)joinerPath
                                          tokens:(NSString *)tokensPath
                                       modelType:(NSString *)modelType
                                      sampleRate:(int32_t)sampleRate
                                      numThreads:(int32_t)numThreads
                                            error:(NSString **)errorMessage {
    try {
        SherpaOnnxOnlineRecognizerConfig config;
        memset(&config, 0, sizeof(config));

        // Feature config
        config.feat_config.sample_rate = sampleRate;
        config.feat_config.feature_dim = 80;

        // Model config
        config.model_config.num_threads = numThreads;
        config.model_config.provider = "cpu";
        config.model_config.debug = 1;
        config.model_config.model_type = modelType.UTF8String;
        config.model_config.tokens = tokensPath.UTF8String;

        // Transducer-specific
        config.model_config.transducer.encoder = encoderPath.UTF8String;
        config.model_config.transducer.decoder = decoderPath.UTF8String;
        config.model_config.transducer.joiner = joinerPath.UTF8String;

        // Recognizer config
        config.decoding_method = "greedy_search";
        config.max_active_paths = 4;
        config.enable_endpoint = 0;

        NSLog(@"🔧 SafeBridge: Creating transducer recognizer");

        const SherpaOnnxOnlineRecognizer *recognizer =
            SherpaOnnxCreateOnlineRecognizer(&config);

        if (recognizer == nullptr) {
            if (errorMessage) {
                *errorMessage = @"SherpaOnnxCreateOnlineRecognizer returned NULL";
            }
        }
        return (void *)recognizer;
    } catch (const std::exception &e) {
        if (errorMessage) {
            *errorMessage = [NSString stringWithFormat:@"C++ exception: %s", e.what()];
        }
        return nil;
    } catch (...) {
        if (errorMessage) {
            *errorMessage = @"Unknown C++ exception while creating Sherpa-ONNX recognizer";
        }
        return nil;
    }
}

+ (void *)createOnlineStream:(void *)recognizer {
    try {
        const SherpaOnnxOnlineStream *stream = SherpaOnnxCreateOnlineStream(
            (const SherpaOnnxOnlineRecognizer *)recognizer);
        return (void *)stream;
    } catch (const std::exception &e) {
        NSLog(@"Sherpa-ONNX C++ exception creating stream: %s", e.what());
        return nil;
    } catch (...) {
        NSLog(@"Sherpa-ONNX: Unknown exception creating online stream");
        return nil;
    }
}

@end
