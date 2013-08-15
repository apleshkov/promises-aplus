//
//  APPromise.h
//  promise-aplus
//
//  Created by Andrew Pleshkov on 5/31/13.
//  Copyright (c) 2013 Andrew Pleshkov. All rights reserved.
//

#import <Foundation/Foundation.h>

#if OS_OBJECT_USE_OBJC
#define APPromiseDispatchRetain(object)
#define APPromiseDispatchRelease(object)
#else
#define APPromiseDispatchRetain(object) (dispatch_retain(object))
#define APPromiseDispatchRelease(object) (dispatch_release(object))
#endif

/* Blocks */

typedef id (^APPromiseFulfillBlock)(id value);
typedef id (^APPromiseRejectBlock)(id reason);

/* Protocol */

@protocol APPromise <NSObject>

- (id<APPromise>)thenUseDispatchQueue:(dispatch_queue_t)queue
                          ifFulfilled:(APPromiseFulfillBlock)fulfill
                             rejected:(APPromiseRejectBlock)reject;

@end

/* State */

typedef NS_ENUM(NSInteger, APPromiseState) {
   APPromiseStatePending = 0,
   APPromiseStateFulfilled,
   APPromiseStateRejected
};

/* Class */

@interface APPromise : NSObject<APPromise>

@property (nonatomic) NSString *name;

- (APPromiseState)state;
- (id)value;
- (id)reason;

@end

@interface APPromise (APPromiseStateShortcuts)

- (BOOL)isPending;

/*!
 DDDDDDD
 @abstract fjfjfjfjfjf
 @return Returns 1 if fulfilled, 0 otherwise
 */
- (BOOL)isFulfilled;
- (BOOL)isRejected;

@end

@interface APPromise (APPromiseCreation)

+ (instancetype)promise;
+ (instancetype)promiseWithName:(NSString *)name;

@end
