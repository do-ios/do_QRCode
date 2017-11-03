//
//  do_QRCode_SM.m
//  DoExt_API
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//
#import <UIKit/UIKit.h>
#import "do_QRCode_SM.h"

#import "doScriptEngineHelper.h"
#import "doIScriptEngine.h"
#import "doInvokeResult.h"
#import "doJsonHelper.h"
#import "doUIModuleHelper.h"
#import "doIOHelper.h"
#import "doIApp.h"
#import "doIDataFS.h"
#import "doIPage.h"
#import "doDefines.h"
#import "doServiceContainer.h"
#import "doLogEngine.h"

@implementation do_QRCode_SM
#pragma mark - 方法
#pragma mark - 同步异步方法的实现
//同步
//异步
- (void)create:(NSArray *)parms
{
    //异步耗时操作，但是不需要启动线程，框架会自动加载一个后台线程处理这个函数
    NSDictionary *_dictParas = [parms objectAtIndex:0];
    //参数字典_dictParas
    id<doIScriptEngine> _scritEngine = [parms objectAtIndex:1];

    NSString *text = [doJsonHelper GetOneText:_dictParas :@"text" :@""];
    float length = [doJsonHelper GetOneFloat:_dictParas :@"length" :500];
    
    length = length * _scritEngine.CurrentPage.RootView.XZoom;
    
    NSString *logoPath = [doJsonHelper GetOneText:_dictParas :@"logoPath" :nil];
    float logoLength = [doJsonHelper GetOneFloat:_dictParas :@"logoLength" :20];
    if (logoLength >= 30) {
        logoLength = 30;
    }
    
    logoLength = logoLength / 100.0 * length;
    
    NSString *logoRealPath;
    UIImage *logoImage;
    if (logoPath != nil) {
        if ([self isLogoImagePathLegal:logoPath]) {
            logoRealPath = [doIOHelper GetLocalFileFullPath:_scritEngine.CurrentPage.CurrentApp :logoPath];
            if([doIOHelper ExistFile:logoRealPath]) {
                logoImage = [UIImage imageWithContentsOfFile:logoRealPath];
                if (logoImage == nil) {
                    [[doServiceContainer Instance].LogEngine WriteError:nil :@"logo图片初始化失败"];
                }
            }else {
                [[doServiceContainer Instance].LogEngine WriteError:nil :@"logo图片不存在"];
            }

        }else {
            [[doServiceContainer Instance].LogEngine WriteError:nil :@"logo路径不合法"];
        }
    }
    
    //自己的代码实现
    UIImage *qrcode = [self createNonInterpolatedUIImageFormCIImage:[self createQRForString:text] withSize:length];
    UIImage *customQrcode = [self imageBlackToTransparent:qrcode withRed:60.0f andGreen:74.0f andBlue:89.0f];
    if (logoImage != nil) {
        customQrcode = [self createLogoQRCodeImage:customQrcode logoImage:logoImage logoLength:logoLength];
    }
    NSData *imageData = UIImageJPEGRepresentation(customQrcode, 1.0);
    
    NSDate * date = [NSDate date];
    NSString * timeStr = [NSString stringWithFormat:@"%f", [date timeIntervalSince1970]];
    timeStr = [timeStr substringToIndex:10];
    
    NSString * defaultFileName = [NSString stringWithFormat:@"%@", timeStr];
    NSString * outFileNameStr = [doJsonHelper GetOneText:_dictParas :@"outFileName" :defaultFileName];
    NSString * outFileName = [NSString stringWithFormat:@"%@.jpg",outFileNameStr];
    if (outFileName.length == 0) {
        outFileName = defaultFileName;
    }
    
    //outPath
    NSString * defaultFilePath = [NSString stringWithFormat:@"data://temp/do_QRCode/%@", outFileName];
    NSString * outPath = [doJsonHelper GetOneText:_dictParas :@"outPath" :defaultFilePath];
    NSString * tempPath = [outPath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (tempPath.length == 0) {
        outPath = defaultFilePath;
    }
    
    NSString * fullPath = _scritEngine.CurrentApp.DataFS.RootPath;
    NSString *path = [NSString stringWithFormat:@"%@/%@",fullPath,outPath];
    if(![doIOHelper ExistDirectory:path])
    {
        [doIOHelper CreateDirectory:path];
    }
    NSString *savePath = [NSString stringWithFormat:@"%@/%@",path,outFileName];
    NSString *refilePath = [NSString stringWithFormat:@"data://%@/%@",outPath,outFileName];
    [doIOHelper WriteAllBytes:savePath :imageData];
    NSString *_callbackName = [parms objectAtIndex:2];
    //回调函数名_callbackName
    doInvokeResult *_invokeResult = [[doInvokeResult alloc] init];
    [_invokeResult SetResultText:refilePath];
    //_invokeResult设置返回值
    [_scritEngine Callback:_callbackName :_invokeResult];
}
- (void)recognition:(NSArray *)parms
{
    //异步耗时操作，但是不需要启动线程，框架会自动加载一个后台线程处理这个函数
    NSDictionary *_dictParas = [parms objectAtIndex:0];
    NSString *path = [doJsonHelper GetOneText:_dictParas :@"path" :@""];
    
    //参数字典_dictParas
    id<doIScriptEngine> _scritEngine = [parms objectAtIndex:1];
    //自己的代码实现
    __block NSString *content;
    if ([path hasPrefix:@"http"]) {
        NSOperationQueue *queue = [[NSOperationQueue alloc]init];
        [queue addOperationWithBlock:^{
            NSData *dataImg = [NSData dataWithContentsOfURL:[NSURL URLWithString:path]];
            UIImage *img = [UIImage imageWithData:dataImg];
            content = [self getTextFromImage:img];
            NSString *_callbackName = [parms objectAtIndex:2];
            //回调函数名_callbackName
            doInvokeResult *_invokeResult = [[doInvokeResult alloc] init];
            //_invokeResult设置返回值
            [_invokeResult SetResultText:content];
            [_scritEngine Callback:_callbackName :_invokeResult];
        }];
    }
    else
    {
        NSString * imagePath = [doIOHelper GetLocalFileFullPath:_scritEngine.CurrentPage.CurrentApp :path];
        content = [self getTextFromImagePath:imagePath];
        NSString *_callbackName = [parms objectAtIndex:2];
        //回调函数名_callbackName
        doInvokeResult *_invokeResult = [[doInvokeResult alloc] init];
        //_invokeResult设置返回值
        [_invokeResult SetResultText:content];
        [_scritEngine Callback:_callbackName :_invokeResult];
    }
}
#pragma mark - 私有方法
- (BOOL)isLogoImagePathLegal:(NSString*)logoPath {
    BOOL pathLegal = false;
    if (([logoPath hasPrefix:@"data://"] || [logoPath hasPrefix:@"source://"]) && (![logoPath containsString:@"@"])) {
        pathLegal = true;
    }
    return pathLegal;
}

-(NSString *)getTextFromImagePath:(NSString *)path
{
    UIImage *uiImage = [UIImage imageNamed:path];
    return [self getTextFromImage:uiImage];
}
- (NSString *)getTextFromImage:(UIImage *)image
{
    NSString *result = @"";

    CIImage *ciimage = [CIImage imageWithCGImage:image.CGImage];
    CIContext *cicontext = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer:@(YES)}];
    static CIDetector *detector = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:CIDetectorAccuracyLow, CIDetectorAccuracy, nil];
        if (IOS_8) {
            detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:cicontext options:options];
        }
    });

    NSArray *imagearrar = [detector featuresInImage:ciimage];
    if (imagearrar.count > 0) {
        for (CIFeature *featrue in imagearrar) {
            if (![featrue isKindOfClass:[CIQRCodeFeature class]]) {
                continue;
            }
            CIQRCodeFeature *qrFeatrue = (CIQRCodeFeature *)featrue;
            
            NSData *data=[qrFeatrue.messageString dataUsingEncoding:NSUTF8StringEncoding];
            NSStringEncoding encode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
            NSString *string = [[NSString alloc] initWithData:data encoding:encode];
            
            if (string)
            {
                NSInteger max = [qrFeatrue.messageString length];
                char *nbytes = malloc(max + 1);
                NSUInteger i = 0;
                for (; i < max; i++)
                {
                    unichar ch = [qrFeatrue.messageString characterAtIndex:i];
                    nbytes[i] = (char) ch;
                }
                nbytes[max] = '\0';
                result=[NSString stringWithCString:nbytes encoding:encode];
            }else
                result = qrFeatrue.messageString;

        }
    }
    return result;
}
- (UIImage *)createNonInterpolatedUIImageFormCIImage:(CIImage *)image withSize:(CGFloat) size {
    CGRect extent = CGRectIntegral(image.extent);
    CGFloat scale = MIN(size/CGRectGetWidth(extent), size/CGRectGetHeight(extent));
    // create a bitmap image that we'll draw into a bitmap context at the desired size;
    size_t width = CGRectGetWidth(extent) * scale;
    size_t height = CGRectGetHeight(extent) * scale;
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceGray();
    CGContextRef bitmapRef = CGBitmapContextCreate(nil, width, height, 8, 0, cs, (CGBitmapInfo)kCGImageAlphaNone);
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef bitmapImage = [context createCGImage:image fromRect:extent];
    CGContextSetInterpolationQuality(bitmapRef, kCGInterpolationNone);
    CGContextScaleCTM(bitmapRef, scale, scale);
    CGContextDrawImage(bitmapRef, extent, bitmapImage);
    // Create an image with the contents of our bitmap
    CGImageRef scaledImage = CGBitmapContextCreateImage(bitmapRef);
    // Cleanup
    CGContextRelease(bitmapRef);
    CGImageRelease(bitmapImage);
    return [UIImage imageWithCGImage:scaledImage];
}
- (CIImage *)createQRForString:(NSString *)qrString {
    // Need to convert the string to a UTF-8 encoded NSData object
    NSData *stringData = [qrString dataUsingEncoding:NSUTF8StringEncoding];
    // Create the filter
    CIFilter *qrFilter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    // Set the message content and error-correction level
    [qrFilter setValue:stringData forKey:@"inputMessage"];
    [qrFilter setValue:@"H" forKey:@"inputCorrectionLevel"];
    // Send the image back
    return qrFilter.outputImage;
}

/**
 合成二维码和logo
 
 - parameter qrCodeImage: 二维码
 - parameter logoImage:   logoImage
 - parameter logoLength:   logoImage 的宽高

 - returns: 二维码和logoImage的混合图片
 */

- (UIImage*)createLogoQRCodeImage:(UIImage*)qrcodeImage logoImage:(UIImage*)logoImage logoLength:(float)logoLength{
    // 开启上下文
    UIGraphicsBeginImageContext(qrcodeImage.size);
    float width = qrcodeImage.size.width;
    float height = qrcodeImage.size.height;
    // 将二维码图片绘制进图像上下文
    [qrcodeImage drawInRect:CGRectMake(0, 0, width, height)];
    // 将头像图片绘制进图像上下文
    float x = (width - logoLength) * 0.5;
    float y = (height - logoLength) * 0.5;
    [logoImage drawInRect: CGRectMake(x, y, logoLength, logoLength)];
    // 从上下文获取图片
    UIImage *mixImage = UIGraphicsGetImageFromCurrentImageContext();
    // 关闭上下文
    UIGraphicsEndImageContext();
    return mixImage;
    
}
#pragma mark - imageToTransparent
void ProviderReleaseData (void *info, const void *data, size_t size){
    free((void*)data);
}
- (UIImage*)imageBlackToTransparent:(UIImage*)image withRed:(CGFloat)red andGreen:(CGFloat)green andBlue:(CGFloat)blue{
    const int imageWidth = image.size.width;
    const int imageHeight = image.size.height;
    size_t      bytesPerRow = imageWidth * 4;
    uint32_t* rgbImageBuf = (uint32_t*)malloc(bytesPerRow * imageHeight);
    // create context
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(rgbImageBuf, imageWidth, imageHeight, 8, bytesPerRow, colorSpace,
                                                 kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipLast);
    CGContextDrawImage(context, CGRectMake(0, 0, imageWidth, imageHeight), image.CGImage);
    // traverse pixe
    int pixelNum = imageWidth * imageHeight;
    uint32_t* pCurPtr = rgbImageBuf;
    for (int i = 0; i < pixelNum; i++, pCurPtr++){
        if ((*pCurPtr & 0xFFFFFF00) < 0x99999900){
            // change color
            uint8_t* ptr = (uint8_t*)pCurPtr;
            ptr[3] = red; //0~255
            ptr[2] = green;
            ptr[1] = blue;
        }else{
            uint8_t* ptr = (uint8_t*)pCurPtr;
            ptr[0] = 0;
        }
    }
    // context to image
    CGDataProviderRef dataProvider = CGDataProviderCreateWithData(NULL, rgbImageBuf, bytesPerRow * imageHeight, ProviderReleaseData);
    CGImageRef imageRef = CGImageCreate(imageWidth, imageHeight, 8, 32, bytesPerRow, colorSpace,
                                        kCGImageAlphaLast | kCGBitmapByteOrder32Little, dataProvider,
                                        NULL, true, kCGRenderingIntentDefault);
    CGDataProviderRelease(dataProvider);
    UIImage* resultUIImage = [UIImage imageWithCGImage:imageRef];
    // release
    CGImageRelease(imageRef);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    return resultUIImage;
}
@end
