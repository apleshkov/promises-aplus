//
//  APPromise+Mutator.h
//  promise-aplus
//
//  Created by Andrew Pleshkov on 6/1/13.
//  Copyright (c) 2013 Andrew Pleshkov. All rights reserved.
//

#import "APPromise.h"

@interface APPromise (APPromiseMutator)

- (void)fulfillWithValue:(id)value;
- (void)rejectWithReason:(id)reason;

@end

@interface APPromise (APPromiseCreationShortcuts)

+ (instancetype)promiseFulfilledWithValue:(id)value;
+ (instancetype)promiseRejectedWithReason:(id)reason;

@end
