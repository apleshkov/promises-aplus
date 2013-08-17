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
#define APPromiseDispatchRetain(object)   (dispatch_retain(object))
#define APPromiseDispatchRelease(object)  (dispatch_release(object))
#endif

typedef id(^APPromiseFulfillBlock)(id value);
typedef id(^APPromiseRejectBlock)(id reason);

/**
 Basic promise protocol.
 You can create your own promise, which could be returned, for example, from fulfill/reject handlers.
 */
@protocol APPromise <NSObject>

/**
 Primary method for interaction with a promise. See [this](http://promises-aplus.github.io/promises-spec/#the__method) for more info.
 
 @param queue A dispatch queue to which provided blocks will be submitted. Passing `NULL` is the same as passing `dispatch_get_main_queue()`.

 @param fulfilled Optional parameter.
 
      typedef id(^APPromiseFulfillBlock)(id value);
 
 Passing `nil` is the same as passing
 
      ^id(id value) { return value; }
      
 @param rejected Optional parameter.
 
      typedef id(^APPromiseRejectBlock)(id reason);
 
 Passing `nil` is the same as passing
 
      ^id(id reason) { return reason; }
 
 */
- (id<APPromise>)thenUseDispatchQueue:(dispatch_queue_t)queue
                          ifFulfilled:(APPromiseFulfillBlock)fulfilled
                             rejected:(APPromiseRejectBlock)rejected;

@end

/**
 Possible promise states.
 @see APPromise
 */
typedef NS_ENUM(NSInteger, APPromiseState) {
   /** Initial state. */
   APPromiseStatePending = 0,
   /** Fullfilled. */
   APPromiseStateFulfilled,
   /** Rejected. */
   APPromiseStateRejected
};

/**
 Basic promise non-mutable class. Useful to create a public interfaces with promises.
 
 `#import "APPromise+Mutator.h"` to fulfill or reject your promises.
 */
@interface APPromise : NSObject<APPromise>

/**
 Set a name to distinguish one promise from another (i.e. while debugging).
 */
@property (nonatomic) NSString *name;

/**
 Returns promise's current state. Thread-safe.
 @see APPromiseState
 */
- (APPromiseState)state;

/**
 @return Returns promise's fulfillment value (`nil` if still pending or rejected). Thread-safe.
 */
- (id)value;

/**
 @return Returns promise's rejection reason (`nil` if still pending or fulfilled). Thread-safe.
 */
- (id)reason;

@end

@interface APPromise (APPromiseStateShortcuts)

/**
 Check if promise is pending.
 
 Shortcut for:
 
      myPromise.state == APPromiseStatePending;
 
 @return Returns `YES` if still pending.
 @see state
 */
- (BOOL)isPending;

/**
 Check if promise is fulfilled.
 
 Shortcut for:
 
      myPromise.state == APPromiseStateFulfilled;
 
 @return Returns `YES` if fulfilled with -value.
 @see state
 */
- (BOOL)isFulfilled;

/**
 Check if promise is rejected.
 
 Shortcut for:
 
      myPromise.state == APPromiseStateRejected;
 
 @return Returns `YES` if rejected with -reason.
 @see state
 */
- (BOOL)isRejected;

@end

@interface APPromise (APPromiseCreation)

/**
 Creates and returns a pending promise.
 */
+ (instancetype)promise;

/**
 Same as +promise, but also sets a -name.
 @param name See -name.
 */
+ (instancetype)promiseWithName:(NSString *)name;

@end
