#import <Foundation/Foundation.h>

/// Safe wrapper for SherpaOnnx C API calls that catches C++ exceptions
/// thrown by onnxruntime during model loading.
/// Returns nil if creation fails (instead of crashing the app).
@interface SherpaOnnxSafeBridge : NSObject

/// Create a streaming paraformer recognizer with proper memset zero-initialization.
/// All config construction happens in ObjC++ to avoid Swift struct initialization issues.
+ (void *)createParaformerRecognizerWithEncoder:(NSString *)encoderPath
                                        decoder:(NSString *)decoderPath
                                         tokens:(NSString *)tokensPath
                                     modelType:(NSString *)modelType
                                    sampleRate:(int32_t)sampleRate
                                    numThreads:(int32_t)numThreads
                                          error:(NSString **)errorMessage;

/// Create a streaming transducer recognizer with proper memset zero-initialization.
+ (void *)createTransducerRecognizerWithEncoder:(NSString *)encoderPath
                                         decoder:(NSString *)decoderPath
                                          joiner:(NSString *)joinerPath
                                          tokens:(NSString *)tokensPath
                                       modelType:(NSString *)modelType
                                      sampleRate:(int32_t)sampleRate
                                      numThreads:(int32_t)numThreads
                                            error:(NSString **)errorMessage;

/// Safely create an online stream.
+ (void *)createOnlineStream:(void *)recognizer;

/// Create an offline Qwen3-ASR recognizer with proper memset zero-initialization.
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
                                                error:(NSString **)errorMessage;

/// Safely create an offline stream for offline recognizers.
+ (void *)createOfflineStream:(void *)recognizer;

/// Safely destroy an offline recognizer.
+ (void)destroyOfflineRecognizer:(void *)recognizer;

/// Safely destroy an offline stream.
+ (void)destroyOfflineStream:(void *)stream;

/// Get offline stream result text. Caller must free with freeOfflineStreamResult.
+ (NSString *)getOfflineStreamResultText:(void *)stream;

/// Destroy offline stream result.
+ (void)freeOfflineStreamResult:(void *)result;

/// Accept waveform for offline stream.
+ (void)acceptWaveformOffline:(void *)stream sampleRate:(int32_t)sampleRate samples:(const float *)samples count:(int32_t)count;

/// Decode offline stream.
+ (void)decodeOfflineStream:(void *)recognizer stream:(void *)stream;

@end
