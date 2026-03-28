//
//  OpenCVWrapper.h
//  Scanner
//
//  Objective-C interface exposing OpenCV image processing to Swift.
//  Each method takes a UIImage and returns a processed UIImage.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface OpenCVWrapper : NSObject

// Basic filters
+ (UIImage *)grayscale:(UIImage *)image;
+ (UIImage *)binarize:(UIImage *)image;
+ (UIImage *)adaptiveThreshold:(UIImage *)image;

// Document enhancement
+ (UIImage *)documentEnhance:(UIImage *)image;
+ (UIImage *)whiteboard:(UIImage *)image;

// Color enhancement
+ (UIImage *)magicColor:(UIImage *)image;
+ (UIImage *)sharpen:(UIImage *)image;

// Special
+ (UIImage *)sealExtract:(UIImage *)image;
+ (UIImage *)sketch:(UIImage *)image;
+ (UIImage *)noShadow:(UIImage *)image;

// Version info
+ (NSString *)openCVVersion;

@end

NS_ASSUME_NONNULL_END
