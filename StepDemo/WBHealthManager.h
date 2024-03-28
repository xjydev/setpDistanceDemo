//
//  WBHealthManager.h
//  StepDemo
//
//  Created by jingyuan5 on 2024/3/27.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WBHealthManager : NSObject

- (void)updateData;
- (void)updateStep:(void (^)(float step))handle;
- (void)updateDistance:(void (^)(float distance))handle;
- (void)updateEnergy:(NSMutableString *)str;
@end

NS_ASSUME_NONNULL_END
