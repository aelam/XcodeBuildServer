//
//  Person.h
//  Hello
//
//  Created by wang.lun on 2025/08/31.
//

#import "Person.h"

@implementation Person

- (instancetype)initWithName:(NSString *)name {
    if (self = [super init]) {
        self.name = name;
    }
    return self;
}

@end
