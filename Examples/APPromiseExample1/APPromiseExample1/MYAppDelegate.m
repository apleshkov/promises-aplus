//
//  MYAppDelegate.m
//  APPromiseExample1
//
//  Created by Andrew Pleshkov on 8/17/13.
//  Copyright (c) 2013 Andrew Pleshkov. All rights reserved.
//

#import "MYAppDelegate.h"
#import "MYExampleViewController.h"

@implementation MYAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
   self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
   
   self.window.backgroundColor = [UIColor whiteColor];
   
   self.window.rootViewController = [MYExampleViewController new];
   
   [self.window makeKeyAndVisible];
   
   return YES;
}

@end
