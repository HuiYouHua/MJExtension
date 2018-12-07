//
//  NSObject+MJClass.m
//  MJExtensionExample
//
//  Created by MJ Lee on 15/8/11.
//  Copyright (c) 2015年 小码哥. All rights reserved.
//

#import "NSObject+MJClass.h"
#import "NSObject+MJCoding.h"
#import "NSObject+MJKeyValue.h"
#import "MJFoundation.h"
#import <objc/runtime.h>

static const char MJAllowedPropertyNamesKey = '\0';
static const char MJIgnoredPropertyNamesKey = '\0';
static const char MJAllowedCodingPropertyNamesKey = '\0';
static const char MJIgnoredCodingPropertyNamesKey = '\0';

@implementation NSObject (MJClass)

+ (NSMutableDictionary *)classDictForKey:(const void *)key
{
    static NSMutableDictionary *allowedPropertyNamesDict;
    static NSMutableDictionary *ignoredPropertyNamesDict;
    static NSMutableDictionary *allowedCodingPropertyNamesDict;
    static NSMutableDictionary *ignoredCodingPropertyNamesDict;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        allowedPropertyNamesDict = [NSMutableDictionary dictionary];
        ignoredPropertyNamesDict = [NSMutableDictionary dictionary];
        allowedCodingPropertyNamesDict = [NSMutableDictionary dictionary];
        ignoredCodingPropertyNamesDict = [NSMutableDictionary dictionary];
    });
    
    if (key == &MJAllowedPropertyNamesKey) return allowedPropertyNamesDict;
    if (key == &MJIgnoredPropertyNamesKey) return ignoredPropertyNamesDict;
    if (key == &MJAllowedCodingPropertyNamesKey) return allowedCodingPropertyNamesDict;
    if (key == &MJIgnoredCodingPropertyNamesKey) return ignoredCodingPropertyNamesDict;
    return nil;
}

+ (void)mj_enumerateClasses:(MJClassesEnumeration)enumeration
{
    // 1.没有block就直接返回
    if (enumeration == nil) return;
    
    // 2.停止遍历的标记
    BOOL stop = NO;
    
    // 3.当前正在遍历的类
    Class c = self;
    
    // 4.开始遍历每一个类
    while (c && !stop) {
        // 4.1.执行操作
        enumeration(c, &stop);
        
        // 4.2.获得父类
        c = class_getSuperclass(c);
        
        if ([MJFoundation isClassFromFoundation:c]) break;
    }
}

+ (void)mj_enumerateAllClasses:(MJClassesEnumeration)enumeration
{
    // 1.没有block就直接返回
    if (enumeration == nil) return;
    
    // 2.停止遍历的标记
    BOOL stop = NO;
    
    // 3.当前正在遍历的类
    Class c = self;
    
    // 4.开始遍历每一个类
    while (c && !stop) {
        // 4.1.执行操作
        enumeration(c, &stop);
        
        // 4.2.获得父类
        c = class_getSuperclass(c);
    }
}

#pragma mark - 属性黑名单配置
+ (void)mj_setupIgnoredPropertyNames:(MJIgnoredPropertyNames)ignoredPropertyNames
{
    [self mj_setupBlockReturnValue:ignoredPropertyNames key:&MJIgnoredPropertyNamesKey];
}

+ (NSMutableArray *)mj_totalIgnoredPropertyNames
{
    return [self mj_totalObjectsWithSelector:@selector(mj_ignoredPropertyNames) key:&MJIgnoredPropertyNamesKey];
}

#pragma mark - 归档属性黑名单配置
+ (void)mj_setupIgnoredCodingPropertyNames:(MJIgnoredCodingPropertyNames)ignoredCodingPropertyNames
{
    [self mj_setupBlockReturnValue:ignoredCodingPropertyNames key:&MJIgnoredCodingPropertyNamesKey];
}

+ (NSMutableArray *)mj_totalIgnoredCodingPropertyNames
{
    return [self mj_totalObjectsWithSelector:@selector(mj_ignoredCodingPropertyNames) key:&MJIgnoredCodingPropertyNamesKey];
}

#pragma mark - 属性白名单配置
+ (void)mj_setupAllowedPropertyNames:(MJAllowedPropertyNames)allowedPropertyNames;
{
    [self mj_setupBlockReturnValue:allowedPropertyNames key:&MJAllowedPropertyNamesKey];
}

+ (NSMutableArray *)mj_totalAllowedPropertyNames
{
    return [self mj_totalObjectsWithSelector:@selector(mj_allowedPropertyNames) key:&MJAllowedPropertyNamesKey];
}

#pragma mark - 归档属性白名单配置
+ (void)mj_setupAllowedCodingPropertyNames:(MJAllowedCodingPropertyNames)allowedCodingPropertyNames
{
    [self mj_setupBlockReturnValue:allowedCodingPropertyNames key:&MJAllowedCodingPropertyNamesKey];
}

+ (NSMutableArray *)mj_totalAllowedCodingPropertyNames
{
    return [self mj_totalObjectsWithSelector:@selector(mj_allowedCodingPropertyNames) key:&MJAllowedCodingPropertyNamesKey];
}

#pragma mark - block和方法处理:存储block的返回值
+ (void)mj_setupBlockReturnValue:(id (^)(void))block key:(const char *)key
{
    if (block) {
        objc_setAssociatedObject(self, key, block(), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else {
        objc_setAssociatedObject(self, key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    // 清空数据
    MJExtensionSemaphoreCreate
    MJExtensionSemaphoreWait
    [[self classDictForKey:key] removeAllObjects];
    MJExtensionSemaphoreSignal
}


/**
 key值有四种,分别表示:
 1) MJAllowedPropertyNamesKey: 允许进行字典和模型的转换的属性
 2) MJIgnoredPropertyNamesKey: 被忽略进行字典和模型的转换的属性
 3) MJAllowedCodingPropertyNamesKey: 允许进行归档的属性
 4) MJIgnoredCodingPropertyNamesKey: 被忽略进行归档的属性
 
 方法解析:
 1.classDictForKey 表示根据传入的key值取出字典集合
 po [self classDictForKey:key]
 {
 MJUser =     (
 name,
 icon
 );
 }
 2.取出字典里以 self 为 key 所对应的值,即数组内容对应的就是上述 key 值表示的属性字典集合
 <__NSArrayM 0x6000001f84b0>(
 name,
 icon
 )
 3.当数组为空时,创建一个字典放入以 self 为key 的空值
 4.将实现 selector 方法返回的数组放入到这个以 self 为key 的数组当中
 5.遍历 self 类中以 key 为标识符的 数据内容取出并返回
 总结: 这个方法就是为了如果用户实现了比如+ (NSArray *)mj_allowedPropertyNames;+ (NSArray *)mj_allowedCodingPropertyNames; 这样的方法时, 返回用户在这里设置的数组属性内容
 */
+ (NSMutableArray *)mj_totalObjectsWithSelector:(SEL)selector key:(const char *)key
{
    MJExtensionSemaphoreCreate
    MJExtensionSemaphoreWait
   
    NSMutableArray *array = [self classDictForKey:key][NSStringFromClass(self)];
    if (array == nil) {
        // 创建、存储
        [self classDictForKey:key][NSStringFromClass(self)] = array = [NSMutableArray array];
        
        if ([self respondsToSelector:selector]) {
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            NSArray *subArray = [self performSelector:selector];
    #pragma clang diagnostic pop
            if (subArray) {
                [array addObjectsFromArray:subArray];
            }
        }
        
        [self mj_enumerateAllClasses:^(__unsafe_unretained Class c, BOOL *stop) {
            NSArray *subArray = objc_getAssociatedObject(c, key);
            [array addObjectsFromArray:subArray];
        }];
    }
    
    
    MJExtensionSemaphoreSignal
    
    return array;
}
@end
