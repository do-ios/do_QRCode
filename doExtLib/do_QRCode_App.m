//
//  do_QRCode_App.m
//  DoExt_SM
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import "do_QRCode_App.h"
static do_QRCode_App* instance;
@implementation do_QRCode_App
@synthesize OpenURLScheme;
+(id) Instance
{
    if(instance==nil)
        instance = [[do_QRCode_App alloc]init];
    return instance;
}
@end
