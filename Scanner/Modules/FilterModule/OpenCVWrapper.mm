//
//  OpenCVWrapper.mm
//  Scanner
//
//  OpenCV-based image processing filters.
//
//  Implementation notes:
//  - UIImage ↔ cv::Mat conversion handles RGBA/BGRA correctly.
//  - All processing is synchronous; caller should dispatch to background.
//  - Memory managed via cv::Mat RAII (no manual release needed).
//

#ifdef __cplusplus
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdocumentation"
#pragma clang diagnostic ignored "-Wdeprecated-anon-enum-enum-conversion"
#import <opencv2/opencv.hpp>
#import <opencv2/imgproc.hpp>
#import <opencv2/photo.hpp>
#pragma clang diagnostic pop
#endif

#import "OpenCVWrapper.h"

@implementation OpenCVWrapper

#pragma mark - UIImage ↔ cv::Mat

+ (cv::Mat)matFromImage:(UIImage *)image {
    CGImageRef cgImage = image.CGImage;
    if (!cgImage) {
        return cv::Mat();
    }

    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);

    cv::Mat mat((int)height, (int)width, CV_8UC4);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(
        mat.data,
        width,
        height,
        8,
        mat.step[0],
        colorSpace,
        (CGBitmapInfo)kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault
    );

    CGContextDrawImage(ctx, CGRectMake(0, 0, width, height), cgImage);
    CGContextRelease(ctx);
    CGColorSpaceRelease(colorSpace);

    return mat; // RGBA
}

+ (UIImage *)imageFromMat:(const cv::Mat &)mat {
    cv::Mat rgba;
    if (mat.channels() == 1) {
        cv::cvtColor(mat, rgba, cv::COLOR_GRAY2RGBA);
    } else if (mat.channels() == 3) {
        cv::cvtColor(mat, rgba, cv::COLOR_BGR2RGBA);
    } else {
        rgba = mat;
    }

    NSData *data = [NSData dataWithBytes:rgba.data length:rgba.total() * rgba.elemSize()];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);

    CGImageRef cgImage = CGImageCreate(
        rgba.cols,
        rgba.rows,
        8,
        8 * (int)rgba.elemSize(),
        (int)rgba.step[0],
        colorSpace,
        kCGBitmapByteOrderDefault | (CGBitmapInfo)kCGImageAlphaPremultipliedLast,
        provider,
        NULL,
        false,
        kCGRenderingIntentDefault
    );

    UIImage *result = [UIImage imageWithCGImage:cgImage
                                          scale:1.0
                                    orientation:UIImageOrientationUp];

    CGImageRelease(cgImage);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);

    return result;
}

#pragma mark - Basic Filters

+ (UIImage *)grayscale:(UIImage *)image {
    cv::Mat src = [self matFromImage:image];
    if (src.empty()) return image;

    cv::Mat gray;
    cv::cvtColor(src, gray, cv::COLOR_RGBA2GRAY);

    // Boost contrast with CLAHE for a more dramatic grayscale look
    cv::Ptr<cv::CLAHE> clahe = cv::createCLAHE(2.0, cv::Size(8, 8));
    cv::Mat enhanced;
    clahe->apply(gray, enhanced);

    return [self imageFromMat:enhanced];
}

+ (UIImage *)binarize:(UIImage *)image {
    cv::Mat src = [self matFromImage:image];
    if (src.empty()) return image;

    cv::Mat gray;
    cv::cvtColor(src, gray, cv::COLOR_RGBA2GRAY);

    // Gaussian blur to reduce noise before thresholding
    cv::GaussianBlur(gray, gray, cv::Size(3, 3), 0);

    // Otsu's automatic thresholding — produces clean black & white
    cv::Mat binary;
    cv::threshold(gray, binary, 0, 255, cv::THRESH_BINARY | cv::THRESH_OTSU);

    return [self imageFromMat:binary];
}

+ (UIImage *)adaptiveThreshold:(UIImage *)image {
    cv::Mat src = [self matFromImage:image];
    if (src.empty()) return image;

    cv::Mat gray;
    cv::cvtColor(src, gray, cv::COLOR_RGBA2GRAY);

    // Slight blur for noise reduction
    cv::GaussianBlur(gray, gray, cv::Size(5, 5), 0);

    // Adaptive threshold handles uneven lighting much better than global threshold
    cv::Mat adaptive;
    cv::adaptiveThreshold(gray, adaptive, 255,
                          cv::ADAPTIVE_THRESH_GAUSSIAN_C,
                          cv::THRESH_BINARY, 21, 10);

    return [self imageFromMat:adaptive];
}

#pragma mark - Document Enhancement

+ (UIImage *)documentEnhance:(UIImage *)image {
    cv::Mat src = [self matFromImage:image];
    if (src.empty()) return image;

    cv::Mat bgr;
    cv::cvtColor(src, bgr, cv::COLOR_RGBA2BGR);

    // Convert to LAB for luminance-based enhancement
    cv::Mat lab;
    cv::cvtColor(bgr, lab, cv::COLOR_BGR2Lab);

    std::vector<cv::Mat> channels;
    cv::split(lab, channels);

    // Strong CLAHE on L channel for maximum text clarity
    cv::Ptr<cv::CLAHE> clahe = cv::createCLAHE(4.0, cv::Size(8, 8));
    clahe->apply(channels[0], channels[0]);

    cv::merge(channels, lab);
    cv::cvtColor(lab, bgr, cv::COLOR_Lab2BGR);

    // Unsharp mask for edge crispness
    cv::Mat blurred;
    cv::GaussianBlur(bgr, blurred, cv::Size(0, 0), 3);
    cv::addWeighted(bgr, 2.0, blurred, -1.0, 0, bgr);

    // Increase saturation slightly for richer document colors
    cv::Mat hsv;
    cv::cvtColor(bgr, hsv, cv::COLOR_BGR2HSV);
    std::vector<cv::Mat> hsvChannels;
    cv::split(hsv, hsvChannels);
    hsvChannels[1] = hsvChannels[1] * 1.2;
    cv::merge(hsvChannels, hsv);
    cv::cvtColor(hsv, bgr, cv::COLOR_HSV2BGR);

    cv::Mat result;
    cv::cvtColor(bgr, result, cv::COLOR_BGR2RGBA);
    return [self imageFromMat:result];
}

+ (UIImage *)whiteboard:(UIImage *)image {
    cv::Mat src = [self matFromImage:image];
    if (src.empty()) return image;

    cv::Mat gray;
    cv::cvtColor(src, gray, cv::COLOR_RGBA2GRAY);

    // Large-kernel morphological closing to estimate background
    cv::Mat bg;
    cv::Mat kernel = cv::getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(51, 51));
    cv::morphologyEx(gray, bg, cv::MORPH_CLOSE, kernel);

    // Divide grayscale by background to normalize lighting
    cv::Mat normalized;
    cv::divide(gray, bg, normalized, 255.0);

    // Light threshold to push background to pure white
    cv::Mat result;
    cv::threshold(normalized, result, 230, 255, cv::THRESH_TRUNC);

    // Stretch contrast to full 0–255
    cv::normalize(result, result, 0, 255, cv::NORM_MINMAX);

    return [self imageFromMat:result];
}

#pragma mark - Color Enhancement

+ (UIImage *)magicColor:(UIImage *)image {
    cv::Mat src = [self matFromImage:image];
    if (src.empty()) return image;

    cv::Mat bgr;
    cv::cvtColor(src, bgr, cv::COLOR_RGBA2BGR);

    // Convert to LAB
    cv::Mat lab;
    cv::cvtColor(bgr, lab, cv::COLOR_BGR2Lab);

    std::vector<cv::Mat> channels;
    cv::split(lab, channels);

    // CLAHE on L channel — moderate strength for natural look
    cv::Ptr<cv::CLAHE> clahe = cv::createCLAHE(3.0, cv::Size(8, 8));
    clahe->apply(channels[0], channels[0]);

    cv::merge(channels, lab);
    cv::cvtColor(lab, bgr, cv::COLOR_Lab2BGR);

    // Boost saturation
    cv::Mat hsv;
    cv::cvtColor(bgr, hsv, cv::COLOR_BGR2HSV);
    std::vector<cv::Mat> hsvChannels;
    cv::split(hsv, hsvChannels);
    hsvChannels[1] = hsvChannels[1] * 1.4; // noticeable boost
    cv::merge(hsvChannels, hsv);
    cv::cvtColor(hsv, bgr, cv::COLOR_HSV2BGR);

    // Slight brightness lift
    bgr.convertTo(bgr, -1, 1.05, 8);

    cv::Mat result;
    cv::cvtColor(bgr, result, cv::COLOR_BGR2RGBA);
    return [self imageFromMat:result];
}

+ (UIImage *)sharpen:(UIImage *)image {
    cv::Mat src = [self matFromImage:image];
    if (src.empty()) return image;

    cv::Mat bgr;
    cv::cvtColor(src, bgr, cv::COLOR_RGBA2BGR);

    // Unsharp mask: original + alpha * (original - blurred)
    cv::Mat blurred;
    cv::GaussianBlur(bgr, blurred, cv::Size(0, 0), 5);

    // Strong sharpening: weight = 2.5, subtract = -1.5
    cv::Mat sharpened;
    cv::addWeighted(bgr, 2.5, blurred, -1.5, 0, sharpened);

    cv::Mat result;
    cv::cvtColor(sharpened, result, cv::COLOR_BGR2RGBA);
    return [self imageFromMat:result];
}

#pragma mark - Special Filters

+ (UIImage *)sealExtract:(UIImage *)image {
    cv::Mat src = [self matFromImage:image];
    if (src.empty()) return image;

    cv::Mat bgr;
    cv::cvtColor(src, bgr, cv::COLOR_RGBA2BGR);

    // Convert to HSV and extract red channel (seals are typically red)
    cv::Mat hsv;
    cv::cvtColor(bgr, hsv, cv::COLOR_BGR2HSV);

    // Red hue wraps around 0/180 in OpenCV, need two ranges
    cv::Mat mask1, mask2, redMask;
    cv::inRange(hsv, cv::Scalar(0, 70, 50), cv::Scalar(15, 255, 255), mask1);
    cv::inRange(hsv, cv::Scalar(160, 70, 50), cv::Scalar(180, 255, 255), mask2);
    redMask = mask1 | mask2;

    // Clean up mask with morphological operations
    cv::Mat morph_kernel = cv::getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(3, 3));
    cv::morphologyEx(redMask, redMask, cv::MORPH_CLOSE, morph_kernel);
    cv::morphologyEx(redMask, redMask, cv::MORPH_OPEN, morph_kernel);

    // Create white background + red foreground result
    cv::Mat result(src.rows, src.cols, CV_8UC4, cv::Scalar(255, 255, 255, 255));

    // Copy red pixels from source where mask is active
    for (int y = 0; y < src.rows; y++) {
        for (int x = 0; x < src.cols; x++) {
            if (redMask.at<uchar>(y, x) > 0) {
                result.at<cv::Vec4b>(y, x) = src.at<cv::Vec4b>(y, x);
            }
        }
    }

    return [self imageFromMat:result];
}

+ (UIImage *)sketch:(UIImage *)image {
    cv::Mat src = [self matFromImage:image];
    if (src.empty()) return image;

    cv::Mat gray;
    cv::cvtColor(src, gray, cv::COLOR_RGBA2GRAY);

    // Invert
    cv::Mat inverted;
    cv::bitwise_not(gray, inverted);

    // Heavy Gaussian blur on inverted
    cv::Mat blurred;
    cv::GaussianBlur(inverted, blurred, cv::Size(21, 21), 0);

    // Color dodge blend: result = gray / (255 - blurred) * 255
    cv::Mat sketch;
    cv::divide(gray, 255 - blurred, sketch, 256.0);

    return [self imageFromMat:sketch];
}

+ (UIImage *)noShadow:(UIImage *)image {
    cv::Mat src = [self matFromImage:image];
    if (src.empty()) return image;

    cv::Mat bgr;
    cv::cvtColor(src, bgr, cv::COLOR_RGBA2BGR);

    // Split into channels
    std::vector<cv::Mat> channels;
    cv::split(bgr, channels);

    // For each channel: estimate background via large dilation, then normalize
    cv::Mat kernel = cv::getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(67, 67));
    std::vector<cv::Mat> normalized_channels;

    for (int i = 0; i < 3; i++) {
        cv::Mat dilated;
        cv::dilate(channels[i], dilated, kernel);

        cv::Mat bg_smoothed;
        cv::medianBlur(dilated, bg_smoothed, 21);

        cv::Mat diff;
        cv::absdiff(channels[i], bg_smoothed, diff);

        // Invert and normalize
        cv::Mat norm;
        cv::bitwise_not(diff, norm);
        cv::normalize(norm, norm, 0, 255, cv::NORM_MINMAX);

        normalized_channels.push_back(norm);
    }

    cv::Mat merged;
    cv::merge(normalized_channels, merged);

    cv::Mat result;
    cv::cvtColor(merged, result, cv::COLOR_BGR2RGBA);
    return [self imageFromMat:result];
}

#pragma mark - Info

+ (NSString *)openCVVersion {
    return [NSString stringWithFormat:@"OpenCV %s", CV_VERSION];
}

@end
