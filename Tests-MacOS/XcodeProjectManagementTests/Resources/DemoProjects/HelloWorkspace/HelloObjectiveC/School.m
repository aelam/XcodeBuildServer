//
//  School.m
//  Hello
//
//  Created by wang.lun on 2025/09/01.
//


#import "School.h"

@implementation School

- (instancetype)initWithName:(NSString *)name {
    if (self = [super init]) {
        self.name = name;
    }
    return self;
}

@end
