# MJExtension
MJExtension的源码解析

> 前篇我们对 [Runtime](https://www.jianshu.com/p/bf7b025f998e) 的相关方法进行了总结，同时也响应了写了几个案例，这次为了巩固下知识点，这里研究并分析了下[MJExtension](https://github.com/CoderMJLee/MJExtension)中关于字典转模型的原理。

[MJExtension解析](https://github.com/HuiYouHua/MJExtension)

# 一、MJExtension的应用
我们进MJExtension的git上可以看到，它实现功能有
- MJExtension是一套字典和模型之间互相转换的超轻量级框架
- JSON --> Model、Core Data Model
- JSONString --> Model、Core Data Model
- Model、Core Data Model --> JSON
- JSON Array --> Model Array、Core Data Model Array
- JSONString --> Model Array、Core Data Model Array
- Model Array、Core Data Model Array --> JSON Array
- Coding all properties of a model with only one line of code.
- 只需要一行代码，就能实现模型的所有属性进行Coding（归档和解档）

初次之外，如果我们要对模型数据有些特殊处理的话我们可以调用一下方法：
```
/**
 *  只有这个数组中的属性名才允许进行字典和模型的转换
 */
+ (NSArray *)mj_allowedPropertyNames;

/**
 *  这个数组中的属性名将会被忽略：不进行字典和模型的转换
 */
+ (NSArray *)mj_ignoredPropertyNames;

/**
 *  将属性名换为其他key去字典中取值
 *
 *  @return 字典中的key是属性名，value是从字典中取值用的key
 */
+ (NSDictionary *)mj_replacedKeyFromPropertyName;

/**
 *  将属性名换为其他key去字典中取值
 *
 *  @return 从字典中取值用的key
 */
+ (id)mj_replacedKeyFromPropertyName121:(NSString *)propertyName;

/**
 *  旧值换新值，用于过滤字典中的值
 *
 *  @param oldValue 旧值
 *
 *  @return 新值
 */
- (id)mj_newValueFromOldValue:(id)oldValue property:(MJProperty *)property;

/**
 *  这个数组中的属性名才会进行归档
 */
+ (NSArray *)mj_allowedCodingPropertyNames;
/**
 *  这个数组中的属性名将会被忽略：不进行归档
 */
+ (NSArray *)mj_ignoredCodingPropertyNames;
@end

@interface NSObject (MJCoding) <MJCoding>
/**
 *  解码（从文件中解析对象）
 */
- (void)mj_decode:(NSCoder *)decoder;
/**
 *  编码（将对象写入文件中）
 */
- (void)mj_encode:(NSCoder *)encoder;

/**
 *  这个数组中的属性名才会进行字典和模型的转换
 *
 *  @param allowedPropertyNames          这个数组中的属性名才会进行字典和模型的转换
 */
+ (void)mj_setupAllowedPropertyNames:(MJAllowedPropertyNames)allowedPropertyNames;

/**
 *  这个数组中的属性名将会被忽略：不进行字典和模型的转换
 *
 *  @param ignoredPropertyNames          这个数组中的属性名将会被忽略：不进行字典和模型的转换
 */
+ (void)mj_setupIgnoredPropertyNames:(MJIgnoredPropertyNames)ignoredPropertyNames;
```
这些看解释基本上都能懂，具体用法我们可以进它的主页或者下载其demo看看，用起来很方便，其中的部分方法的实现原理在下面我也会有相应的讲解。
> Tip：我们除了可以对这个全局的模型进行特殊处理，我们还可以对某次调用模型转换时的模型处理，就是上面代码部分的最后两个方法，当然，看他的源码的话还有更多，这里不多说了

# 二、原理解析
## 1.MJExtension的文件结构分析
这个是MJExtension的文件目录

![Snip20181207_3.png](https://upload-images.jianshu.io/upload_images/2202576-b04503f8f6d998ad.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
其中有几个核心类：NSObject+MJClass、NSObject+MJCoding、NSObject+MJKeyValue、NSObject+MJProperty，这几个主要就是用来模型解析和归解档的，相互直接有依赖。
另外NSString+MJExtension这个类中，就有方便对模型特殊处理的直接调用方法，不用自己费力去写了。
```
/**
 *  驼峰转下划线（loveYou -> love_you）
 */
- (NSString *)mj_underlineFromCamel;
/**
 *  下划线转驼峰（love_you -> loveYou）
 */
- (NSString *)mj_camelFromUnderline;
/**
 * 首字母变大写
 */
- (NSString *)mj_firstCharUpper;
/**
 * 首字母变小写
 */
- (NSString *)mj_firstCharLower;

- (BOOL)mj_isPureInt;

- (NSURL *)mj_url;
```
## 2. 原理分析
### 2.1 调用
首先我们看下demo中的其中一个模型转换的调用
```
void keyValues2object()
{
    // 1.定义一个字典
    NSDictionary *dict = @{
                           @"name" : @"Jack",
                           @"icon" : @"lufy.png",
                           @"age" : @"20",
                           @"height" : @1.55,
                           @"money" : @"100.9",
                           @"sex" : @(SexFemale),
                           @"gay" : @"1"
                       //  @"gay" : @"NO"
                       //  @"gay" : @"true"
                           };
    
    // 2.将字典转为MJUser模型
    MJUser *user = [MJUser mj_objectWithKeyValues:dict];
    
    // 3.打印MJUser模型的属性
    MJExtensionLog(@"name=%@, icon=%@, age=%d, height=%@, money=%@, sex=%d, gay=%d", user.name, user.icon, user.age, user.height, user.money, user.sex, user.gay);
}
```
###2.2 分析
######1) 我们点进 **mj_objectWithKeyValues:** 方法一直到这
```
/**
 1.获得JSON对象
 2.判断普通的模型转换还是Coredata转换
 */
+ (instancetype)mj_objectWithKeyValues:(id)keyValues context:(NSManagedObjectContext *)context
{
    // 获得JSON对象
    keyValues = [keyValues mj_JSONObject];
    MJExtensionAssertError([keyValues isKindOfClass:[NSDictionary class]], nil, [self class], @"keyValues参数不是一个字典");
    
    if ([self isSubclassOfClass:[NSManagedObject class]] && context) {
        NSString *entityName = [NSStringFromClass(self) componentsSeparatedByString:@"."].lastObject;
        return [[NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:context] mj_setKeyValues:keyValues context:context];
    }
    return [[[self alloc] init] mj_setKeyValues:keyValues];
}
```
###### 2）点击进入到**mj_setKeyValues:**这个方法
进到这个方法
```
- (instancetype)mj_setKeyValues:(id)keyValues context:(NSManagedObjectContext *)context
{
    // 获得JSON对象
    keyValues = [keyValues mj_JSONObject];
    
    MJExtensionAssertError([keyValues isKindOfClass:[NSDictionary class]], self, [self class], @"keyValues参数不是一个字典");
    
    Class clazz = [self class];
    // 获取名单类的数组
    NSArray *allowedPropertyNames = [clazz mj_totalAllowedPropertyNames];
    NSArray *ignoredPropertyNames = [clazz mj_totalIgnoredPropertyNames];
    
    //通过封装的方法回调一个通过运行时编写的，用于返回属性列表的方法。
    [clazz mj_enumerateProperties:^(MJProperty *property, BOOL *stop) {
        @try {
            // 0.检测是否被忽略
            if (allowedPropertyNames.count && ![allowedPropertyNames containsObject:property.name]) return;
            if ([ignoredPropertyNames containsObject:property.name]) return;
            
            // 1.取出属性值
            id value;
            NSArray *propertyKeyses = [property propertyKeysForClass:clazz];
            for (NSArray *propertyKeys in propertyKeyses) {
                value = keyValues;
                for (MJPropertyKey *propertyKey in propertyKeys) {
                    value = [propertyKey valueInObject:value];
                }
                if (value) break;
            }
            
            // 值的过滤
            id newValue = [clazz mj_getNewValueFromObject:self oldValue:value property:property];
            if (newValue != value) { // 有过滤后的新值
                [property setValue:newValue forObject:self];
                return;
            }
            
            // 如果没有值，就直接返回
            if (!value || value == [NSNull null]) return;
            
            // 2.复杂处理
            MJPropertyType *type = property.type;
            Class propertyClass = type.typeClass;
            Class objectClass = [property objectClassInArrayForClass:[self class]];
            
            // 不可变 -> 可变处理
            if (propertyClass == [NSMutableArray class] && [value isKindOfClass:[NSArray class]]) {
                value = [NSMutableArray arrayWithArray:value];
            } else if (propertyClass == [NSMutableDictionary class] && [value isKindOfClass:[NSDictionary class]]) {
                value = [NSMutableDictionary dictionaryWithDictionary:value];
            } else if (propertyClass == [NSMutableString class] && [value isKindOfClass:[NSString class]]) {
                value = [NSMutableString stringWithString:value];
            } else if (propertyClass == [NSMutableData class] && [value isKindOfClass:[NSData class]]) {
                value = [NSMutableData dataWithData:value];
            }
            
            if (!type.isFromFoundation && propertyClass) { // 模型属性
                value = [propertyClass mj_objectWithKeyValues:value context:context];
            } else if (objectClass) {
                if (objectClass == [NSURL class] && [value isKindOfClass:[NSArray class]]) {
                    // string array -> url array
                    NSMutableArray *urlArray = [NSMutableArray array];
                    for (NSString *string in value) {
                        if (![string isKindOfClass:[NSString class]]) continue;
                        [urlArray addObject:string.mj_url];
                    }
                    value = urlArray;
                } else { // 字典数组-->模型数组
                    value = [objectClass mj_objectArrayWithKeyValuesArray:value context:context];
                }
            } else {
                if (propertyClass == [NSString class]) {
                    if ([value isKindOfClass:[NSNumber class]]) {
                        // NSNumber -> NSString
                        value = [value description];
                    } else if ([value isKindOfClass:[NSURL class]]) {
                        // NSURL -> NSString
                        value = [value absoluteString];
                    }
                } else if ([value isKindOfClass:[NSString class]]) {
                    if (propertyClass == [NSURL class]) {
                        // NSString -> NSURL
                        // 字符串转码
                        value = [value mj_url];
                    } else if (type.isNumberType) {
                        NSString *oldValue = value;
                        
                        // NSString -> NSNumber
                        if (type.typeClass == [NSDecimalNumber class]) {
                            value = [NSDecimalNumber decimalNumberWithString:oldValue];
                        } else {
                            value = [numberFormatter_ numberFromString:oldValue];
                        }
                        
                        // 如果是BOOL
                        if (type.isBoolType) {
                            // 字符串转BOOL（字符串没有charValue方法）
                            // 系统会调用字符串的charValue转为BOOL类型
                            NSString *lower = [oldValue lowercaseString];
                            if ([lower isEqualToString:@"yes"] || [lower isEqualToString:@"true"]) {
                                value = @YES;
                            } else if ([lower isEqualToString:@"no"] || [lower isEqualToString:@"false"]) {
                                value = @NO;
                            }
                        }
                    }
                } else if ([value isKindOfClass:[NSNumber class]] && propertyClass == [NSDecimalNumber class]){
                    // 过滤 NSDecimalNumber类型
                    if (![value isKindOfClass:[NSDecimalNumber class]]) {
                        value = [NSDecimalNumber decimalNumberWithDecimal:[((NSNumber *)value) decimalValue]];
                    }
                }
                
                // value和property类型不匹配
                if (propertyClass && ![value isKindOfClass:propertyClass]) {
                    value = nil;
                }
            }
            
            // 3.赋值
            [property setValue:value forObject:self];
        } @catch (NSException *exception) {
            MJExtensionBuildError([self class], exception.reason);
            MJExtensionLog(@"%@", exception);
        }
    }];
    
    // 转换完毕
    if ([self respondsToSelector:@selector(mj_keyValuesDidFinishConvertingToObject)]) {
        [self mj_keyValuesDidFinishConvertingToObject];
    }
    if ([self respondsToSelector:@selector(mj_keyValuesDidFinishConvertingToObject:)]) {
        [self mj_keyValuesDidFinishConvertingToObject:keyValues];
    }
    return self;
}
```
这段代码就是模型解析的核心代码，下面我们来分析一下
首先是这段代码的分析：
```

 1.将需要转换的对象转成JSON对象
 2.获取黑白名单中的数据内容: 可以转换的, 被忽略的
 3.遍历这个对象的所有属性,对其做响应处理
    3.1 检查该属性是否允许进行字典和模型
    3.2 检查该属性是否是忽略进行字典和模型
    3.3 取出该属性对应的值
    3.4 处理3.3中获取的值, 可以实现 mj_newValueFromOldValue: 方法进行处理, 比如设置其固定值, 日期格式转换等等
    3.4 获取属性的包装属性, 类类型, 和如果该属性是数组的数组成员类型
    3.5 处理3.3中获取的值, 如果是不可变类型,就变为可变类型
    3.6 判断属性的数据类型并做响应处理
        3.6.1 如果该属性不是 Foundation 对象的数据类型的话, 则递归调用上述所有步骤,直到其实 Foundation 对象类型, 主要是用来处理 模型套模型的数据结构
        3.6.2 如果该属性是数组的数组成员类型存在则做响应处理
            3.6.2.1 如果数组成员类型是url 或者 数组, 则组合成数组类型
            3.6.2.2 如果数组成员类型是其他类型,则转换为模型数组,仍然是递归执行
        3.6.3 如果是其他情况, 这时候剩下的都是些基本数据类型了, 则直接进行响应处理
    3.7 通过以上处理获得最终的属性值, 利用 KVC 进行赋值
 4.至此,模型转换完成, 可以实现 mj_keyValuesDidFinishConvertingToObject:方法 来拿到你原始的 JSON 数据
```
我们一步一步的分析下
###### 1.将需要转换的对象转成JSON对象
```
// 获得JSON对象
    keyValues = [keyValues mj_JSONObject];
```
进去看下
```
- (id)mj_JSONObject
{
    if ([self isKindOfClass:[NSString class]]) {
        return [NSJSONSerialization JSONObjectWithData:[((NSString *)self) dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
    } else if ([self isKindOfClass:[NSData class]]) {
        return [NSJSONSerialization JSONObjectWithData:(NSData *)self options:kNilOptions error:nil];
    }
    
    return self.mj_keyValues;
}
```
这段就是调用系统的JSON序列化，返回我们要转换的JSON对象

###### 2.获取黑白名单中的数据内容: 可以转换的, 被忽略的
```
 Class clazz = [self class];
    // 获取名单类的数组
    NSArray *allowedPropertyNames = [clazz mj_totalAllowedPropertyNames];
    NSArray *ignoredPropertyNames = [clazz mj_totalIgnoredPropertyNames];
```
我们点进这段代码的实现一直到下面这部分：
```
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
```
这段代码实际上是为了返回四种数据，还记得我们在上面写的类似下面这种方法：
```
/**
 *  只有这个数组中的属性名才允许进行字典和模型的转换
 */
+ (NSArray *)mj_allowedPropertyNames;

/**
 *  这个数组中的属性名将会被忽略：不进行字典和模型的转换
 */
+ (NSArray *)mj_ignoredPropertyNames;
```
它就是为了返回我们实现的这些方法中的数组属性内容，下面我们来分析下：
首先，这个key值有四种
> key值有四种,分别表示:
 >1) MJAllowedPropertyNamesKey: 允许进行字典和模型的转换的属性
 >2) MJIgnoredPropertyNamesKey: 被忽略进行字典和模型的转换的属性
> 3) MJAllowedCodingPropertyNamesKey: 允许进行归档的属性
> 4) MJIgnoredCodingPropertyNamesKey: 被忽略进行归档的属性

这里为了防止数据错乱，用了GCD 信号量机制，下面我们继续分析：
1. 首先我们看
```
NSMutableArray *array = [self classDictForKey:key][NSStringFromClass(self)];
```
点击去看的话会发现他会声明四个静态变量分别存储上面四种类型的属性数组，这没什么。
2. 创建和存储那些我们需要特殊处理属性的数组
```
[self classDictForKey:key][NSStringFromClass(self)] = array = [NSMutableArray array];
```
这里我设置了两个要被忽略的字段，
```
 po [self classDictForKey:key]
 {
   MJUser =     (
     name,
     icon
   );
 }

<__NSArrayM 0x6000001f84b0>(
   name,
   icon
 )
```
我们可以看到：取出字典里以 self 为 key 所对应的值,即数组内容对应的就是上述 key 值表示的属性字典集合
3. 当数组为空时,创建一个字典放入以 self 为key 的空值
4. 将实现 selector 方法返回的数组放入到这个以 self 为key 的数组当中
```
if ([self respondsToSelector:selector]) {
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            NSArray *subArray = [self performSelector:selector];
    #pragma clang diagnostic pop
            if (subArray) {
                [array addObjectsFromArray:subArray];
            }
        }
```
这个方法需要我们去实现，就是上面讲的要返回的特殊处理的字段
5. 遍历 self 类中以 key 为标识符的 数据内容取出并返回
```
[self mj_enumerateAllClasses:^(__unsafe_unretained Class c, BOOL *stop) {
            NSArray *subArray = objc_getAssociatedObject(c, key);
            [array addObjectsFromArray:subArray];
        }];
```

总结: 这个方法就是为了如果用户实现了比如 **+ (NSArray *)mj_allowedPropertyNames+ (NSArray *)mj_allowedCodingPropertyNames;** 这样的方法时, 返回用户在这里设置的数组属性内容

回到3中
###### 3.遍历这个对象的所有属性,对其做响应处理
```
//通过封装的方法回调一个通过运行时编写的，用于返回属性列表的方法。
    [clazz mj_enumerateProperties:^(MJProperty *property, BOOL *stop) {
```
我们点进去直到
```
+ (NSMutableArray *)properties
{
    NSMutableArray *cachedProperties = [self propertyDictForKey:&MJCachedPropertiesKey][NSStringFromClass(self)];
    
    if (cachedProperties == nil) {
        MJExtensionSemaphoreCreate
        MJExtensionSemaphoreWait
        
        if (cachedProperties == nil) {
            cachedProperties = [NSMutableArray array];
            
            [self mj_enumerateClasses:^(__unsafe_unretained Class c, BOOL *stop) {
                // 1.获得所有的成员变量
                unsigned int outCount = 0;
                objc_property_t *properties = class_copyPropertyList(c, &outCount);
                
                // 2.遍历每一个成员变量
                for (unsigned int i = 0; i<outCount; i++) {
                    // 将每一个成员变量包装成一个对象
                    MJProperty *property = [MJProperty cachedPropertyWithProperty:properties[i]];
                    // 过滤掉Foundation框架类里面的属性
                    if ([MJFoundation isClassFromFoundation:property.srcClass]) continue;
                    property.srcClass = c;
                    [property setOriginKey:[self propertyKey:property.name] forClass:self];
                    [property setObjectClassInArray:[self propertyObjectClassInArray:property.name] forClass:self];
                    [cachedProperties addObject:property];
                }
                
                // 3.释放内存
                free(properties);
            }];
            
            [self propertyDictForKey:&MJCachedPropertiesKey][NSStringFromClass(self)] = cachedProperties;
        }
        
        MJExtensionSemaphoreSignal
    }
    
    return cachedProperties;
}
```
步骤解析：
```
1. 根据 MJCachedPropertiesKey 字段取缓存中的缓存属性数组
2. 如果不存在,则创建数组,遍历该类下的所有属性
3. 将每个属性包装成一个 MJProperty 对象,设置该对象的objc_property_t, name, type, 父类...,设置的内容可以查看runtime中
4. 同时在 propertyKey 和 propertyObjectClassInArray 中可以设置对象要替换的属性和模型类, 可以在 mj_replacedKeyFromPropertyName121 和 mj_objectClassInArray...方法中设置
5. 将该类的成员属性缓存起来并返回
总结：这段代码就是返回我们对象的所有属性，同时可以对这些属性的字段做一些类似替换，格式化等操作。可以进**propertyKey：**这个方法查看
```
###### 3.1 检查该属性是否允许进行字典和模型
###### 3.2 检查该属性是否是忽略进行字典和模型
```
if (allowedPropertyNames.count && ![allowedPropertyNames containsObject:property.name]) return;
if ([ignoredPropertyNames containsObject:property.name]) return;
```
如果该字段不允许转换或者被忽略转换则直接返回
###### 3.3 取出该属性对应的值
```
id value;
NSArray *propertyKeyses = [property propertyKeysForClass:clazz];
for (NSArray *propertyKeys in propertyKeyses) {
      value = keyValues;
      for (MJPropertyKey *propertyKey in propertyKeys) {
             value = [propertyKey valueInObject:value];
      }
      if (value) break;
}
```
###### 3.4 处理3.3中获取的值, 可以实现 mj_newValueFromOldValue: 方法进行处理, 比如设置其固定值, 日期格式转换等等
```
id newValue = [clazz mj_getNewValueFromObject:self oldValue:value property:property];
if (newValue != value) { // 有过滤后的新值
     [property setValue:newValue forObject:self];
     return;
}
```
###### 3.4 获取属性的包装属性, 类类型, 和如果该属性是数组的数组成员类型
```
MJPropertyType *type = property.type;
Class propertyClass = type.typeClass;
Class objectClass = [property objectClassInArrayForClass:[self class]];
```
###### 3.5 处理3.3中获取的值, 如果是不可变类型,就变为可变类型
```
if (propertyClass == [NSMutableArray class] && [value isKindOfClass:[NSArray class]]) {
    value = [NSMutableArray arrayWithArray:value];
} else if (propertyClass == [NSMutableDictionary class] && [value isKindOfClass:[NSDictionary class]]) {
    value = [NSMutableDictionary dictionaryWithDictionary:value];
} else if (propertyClass == [NSMutableString class] && [value isKindOfClass:[NSString class]]) {
    value = [NSMutableString stringWithString:value];
} else if (propertyClass == [NSMutableData class] && [value isKindOfClass:[NSData class]]) {
    value = [NSMutableData dataWithData:value];
}
```
###### 3.6 判断属性的数据类型并做响应处理
```
if (propertyClass == [NSMutableArray class] && [value isKindOfClass:[NSArray class]]) {
    value = [NSMutableArray arrayWithArray:value];
} else if (propertyClass == [NSMutableDictionary class] && [value isKindOfClass:[NSDictionary class]]) {
    value = [NSMutableDictionary dictionaryWithDictionary:value];
} else if (propertyClass == [NSMutableString class] && [value isKindOfClass:[NSString class]]) {
    value = [NSMutableString stringWithString:value];
} else if (propertyClass == [NSMutableData class] && [value isKindOfClass:[NSData class]]) {
    value = [NSMutableData dataWithData:value];
}

if (!type.isFromFoundation && propertyClass) { // 模型属性
    value = [propertyClass mj_objectWithKeyValues:value context:context];
} else if (objectClass) {
    if (objectClass == [NSURL class] && [value isKindOfClass:[NSArray class]]) {
        // string array -> url array
        NSMutableArray *urlArray = [NSMutableArray array];
        for (NSString *string in value) {
            if (![string isKindOfClass:[NSString class]]) continue;
            [urlArray addObject:string.mj_url];
        }
        value = urlArray;
    } else { // 字典数组-->模型数组
        value = [objectClass mj_objectArrayWithKeyValuesArray:value context:context];
    }
} else {
    if (propertyClass == [NSString class]) {
        if ([value isKindOfClass:[NSNumber class]]) {
            // NSNumber -> NSString
            value = [value description];
        } else if ([value isKindOfClass:[NSURL class]]) {
            // NSURL -> NSString
            value = [value absoluteString];
        }
    } else if ([value isKindOfClass:[NSString class]]) {
        if (propertyClass == [NSURL class]) {
            // NSString -> NSURL
            // 字符串转码
            value = [value mj_url];
        } else if (type.isNumberType) {
            NSString *oldValue = value;
            
            // NSString -> NSNumber
            if (type.typeClass == [NSDecimalNumber class]) {
                value = [NSDecimalNumber decimalNumberWithString:oldValue];
            } else {
                value = [numberFormatter_ numberFromString:oldValue];
            }
            
            // 如果是BOOL
            if (type.isBoolType) {
                // 字符串转BOOL（字符串没有charValue方法）
                // 系统会调用字符串的charValue转为BOOL类型
                NSString *lower = [oldValue lowercaseString];
                if ([lower isEqualToString:@"yes"] || [lower isEqualToString:@"true"]) {
                    value = @YES;
                } else if ([lower isEqualToString:@"no"] || [lower isEqualToString:@"false"]) {
                    value = @NO;
                }
            }
        }
    } else if ([value isKindOfClass:[NSNumber class]] && propertyClass == [NSDecimalNumber class]){
        // 过滤 NSDecimalNumber类型
        if (![value isKindOfClass:[NSDecimalNumber class]]) {
            value = [NSDecimalNumber decimalNumberWithDecimal:[((NSNumber *)value) decimalValue]];
        }
    }
    
    // value和property类型不匹配
    if (propertyClass && ![value isKindOfClass:propertyClass]) {
        value = nil;
    }
}
```
- 3.6.1 如果该属性不是 Foundation 对象的数据类型的话, 则递归调用上述所有步骤,直到其实 Foundation 对象类型, 主要是用来处理 模型套模型的数据结构
- 3.6.2 如果该属性是数组的数组成员类型存在则做响应处理
  - 3.6.2.1 如果数组成员类型是url 或者 数组, 则组合成数组类型
  - 3.6.2.2 如果数组成员类型是其他类型,则转换为模型数组,仍然是递归执行
- 3.6.3 如果是其他情况, 这时候剩下的都是些基本数据类型了, 则直接进行响应处理
###### 3.7 通过以上处理获得最终的属性值, 利用 KVC 进行赋值
```
[property setValue:value forObject:self];
```
###### 4.至此,模型转换完成, 可以实现 mj_keyValuesDidFinishConvertingToObject:方法 来拿到你原始的 JSON 数据
```
 if ([self respondsToSelector:@selector(mj_keyValuesDidFinishConvertingToObject)]) {
     [self mj_keyValuesDidFinishConvertingToObject];
}
if ([self respondsToSelector:@selector(mj_keyValuesDidFinishConvertingToObject:)]) {
    [self mj_keyValuesDidFinishConvertingToObject:keyValues];
}
```

> 总结：MJExtension就是运用 runtime 对类添加属性和获取属性，获取类的成员变量以及对成员变量的操作以及递归思想等实现模型转换的。
> 如果对 runtime 调用方法不熟悉的童鞋，可以看下前篇文章[Runtime方法总结及部分案例](https://www.jianshu.com/p/bf7b025f998e)
>喜欢的就点个赞👍吧





