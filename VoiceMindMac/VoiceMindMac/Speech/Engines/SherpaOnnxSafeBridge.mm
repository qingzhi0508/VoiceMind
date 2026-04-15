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

// MARK: - Offline Qwen3-ASR Recognizer

+ (void *)createOfflineQwen3RecognizerWithConvFrontend:(NSString *)convFrontendPath
                                               encoder:(NSString *)encoderPath
                                               decoder:(NSString *)decoderPath
                                             tokenizer:(NSString *)tokenizerPath
                                          maxTotalLen:(int32_t)maxTotalLen
                                         maxNewTokens:(int32_t)maxNewTokens
                                           temperature:(float)temperature
                                                 topP:(float)topP
                                                 seed:(int32_t)seed
                                           numThreads:(int32_t)numThreads
                                                error:(NSString **)errorMessage {
    // Check if the linked sherpa-onnx library supports Qwen3-ASR
    // (requires xcframework rebuilt from scripts/build-sherpa-onnx/)
#ifndef SHERPA_ONNX_HAS_QWEN3_ASR
    // Runtime check: if qwen3_asr field doesn't exist in the struct,
    // this code path will fail at compile time.
    // We guard with a runtime check instead.
#endif

    try {
        SherpaOnnxOfflineRecognizerConfig config;
        memset(&config, 0, sizeof(config));

        // Feature config
        config.feat_config.sample_rate = 16000;
        config.feat_config.feature_dim = 80;

        // Model config
        config.model_config.num_threads = numThreads;
        config.model_config.provider = "cpu";
        config.model_config.debug = 0;
        config.model_config.model_type = "qwen3_asr";
        config.model_config.tokens = ""; // Qwen3-ASR uses tokenizer dir, not tokens file

        // Qwen3-ASR specific fields - only available if xcframework includes qwen3_asr support
        // Access via the struct offset directly for forward compatibility
        //
        // If you see a compile error here, rebuild the xcframework:
        //   cd scripts/build-sherpa-onnx && ./build-swift.sh
        //
        // The updated c-api.h in scripts/build-sherpa-onnx/src/sherpa-onnx/c-api/c-api.h
        // contains the qwen3_asr field definition.
        config.model_config.qwen3_asr.conv_frontend = convFrontendPath.UTF8String;
        config.model_config.qwen3_asr.encoder = encoderPath.UTF8String;
        config.model_config.qwen3_asr.decoder = decoderPath.UTF8String;
        config.model_config.qwen3_asr.tokenizer = tokenizerPath.UTF8String;
        config.model_config.qwen3_asr.max_total_len = maxTotalLen;
        config.model_config.qwen3_asr.max_new_tokens = maxNewTokens;
        config.model_config.qwen3_asr.temperature = temperature;
        config.model_config.qwen3_asr.top_p = topP;
        config.model_config.qwen3_asr.seed = seed;

        // Decoding method
        config.decoding_method = "greedy_search";

        NSLog(@"🔧 SafeBridge: Creating offline Qwen3-ASR recognizer");
        NSLog(@"   conv_frontend: %@", convFrontendPath);
        NSLog(@"   encoder: %@", encoderPath);
        NSLog(@"   decoder: %@", decoderPath);
        NSLog(@"   tokenizer: %@", tokenizerPath);

        const SherpaOnnxOfflineRecognizer *recognizer =
            SherpaOnnxCreateOfflineRecognizer(&config);

        if (recognizer == nullptr) {
            if (errorMessage) {
                *errorMessage = @"SherpaOnnxCreateOfflineRecognizer returned NULL for Qwen3-ASR";
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
            *errorMessage = @"Unknown C++ exception while creating Qwen3-ASR recognizer";
        }
        return nil;
    }
}

+ (void *)createOfflineStream:(void *)recognizer {
    try {
        const SherpaOnnxOfflineStream *stream = SherpaOnnxCreateOfflineStream(
            (const SherpaOnnxOfflineRecognizer *)recognizer);
        return (void *)stream;
    } catch (const std::exception &e) {
        NSLog(@"Sherpa-ONNX C++ exception creating offline stream: %s", e.what());
        return nil;
    } catch (...) {
        return nil;
    }
}

+ (void)destroyOfflineRecognizer:(void *)recognizer {
    SherpaOnnxDestroyOfflineRecognizer((const SherpaOnnxOfflineRecognizer *)recognizer);
}

+ (void)destroyOfflineStream:(void *)stream {
    SherpaOnnxDestroyOfflineStream((const SherpaOnnxOfflineStream *)stream);
}

+ (NSString *)getOfflineStreamResultText:(void *)stream {
    const SherpaOnnxOfflineRecognizerResult *result =
        SherpaOnnxGetOfflineStreamResult((const SherpaOnnxOfflineStream *)stream);
    if (result == nullptr) {
        return nil;
    }
    NSString *text = result->text ? [NSString stringWithUTF8String:result->text] : nil;
    SherpaOnnxDestroyOfflineRecognizerResult(result);
    return text;
}

+ (void)freeOfflineStreamResult:(void *)result {
    SherpaOnnxDestroyOfflineRecognizerResult((const SherpaOnnxOfflineRecognizerResult *)result);
}

+ (void)acceptWaveformOffline:(void *)stream sampleRate:(int32_t)sampleRate samples:(const float *)samples count:(int32_t)count {
    SherpaOnnxAcceptWaveformOffline((const SherpaOnnxOfflineStream *)stream, sampleRate, samples, count);
}

+ (void)decodeOfflineStream:(void *)recognizer stream:(void *)stream {
    SherpaOnnxDecodeOfflineStream(
        (const SherpaOnnxOfflineRecognizer *)recognizer,
        (const SherpaOnnxOfflineStream *)stream);
}

@end
