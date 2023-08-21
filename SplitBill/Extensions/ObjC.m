//
//  ObjC.m
//  SplitBill
//
//  Created by fer0n on 21.08.23.
//

#import <Foundation/Foundation.h>
#import "SplitBill-Bridging-Header.h"

@implementation ObjC

+ (BOOL)catchException:(void(^)(void))tryBlock error:(__autoreleasing NSError **)error {
    @try {
        tryBlock();
        return YES;
    }
    @catch (NSException *exception) {
        *error = [[NSError alloc] initWithDomain:exception.name code:0 userInfo:exception.userInfo];
        return NO;
    }
}

@end
