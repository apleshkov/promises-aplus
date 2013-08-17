//
//  APPromise+Mutator.h
//  promise-aplus
//
//  Created by Andrew Pleshkov on 6/1/13.
//  Copyright (c) 2013 Andrew Pleshkov. All rights reserved.
//

#import "APPromise.h"

@interface APPromise (APPromiseMutator)

/**
 Fulfills promise with a value.
 @param value Fulfillment value.
 */
- (void)fulfillWithValue:(id)value;

/**
 Rejects promise with a reason.
 @param reason Rejection reason.
 */
- (void)rejectWithReason:(id)reason;

@end

@interface APPromise (APPromiseCreationShortcuts)

/**
 Creates an already fulfilled promise.
 @param value Fulfillment value
 */
+ (instancetype)promiseFulfilledWithValue:(id)value;

/**
 Creates an already rejected promise.
 @param reason Rejection reason.
 */
+ (instancetype)promiseRejectedWithReason:(id)reason;

@end
