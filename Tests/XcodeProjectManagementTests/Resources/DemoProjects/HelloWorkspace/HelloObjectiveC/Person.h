//
//  Person.h
//  Hello
//
//  Created by wang.lun on 2025/08/31.
//

@import Foundation;

@interface Person : NSObject

@property (copy, nonnull) NSString * name;

- (nonnull instancetype)initWithName:(NSString *_Nonnull)name;

@end
