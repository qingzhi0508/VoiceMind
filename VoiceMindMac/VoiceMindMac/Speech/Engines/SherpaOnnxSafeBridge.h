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

@end
