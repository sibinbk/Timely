//
//  BTViewController.h
//  BreakTimer
//
//  Created by Sibin Baby on 19/04/2014.
//  Copyright (c) 2014 BreakTimer. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BTViewController : UIViewController

@property (nonatomic) NSTimeInterval taskTime;
@property (nonatomic) NSTimeInterval shortBreakTime;
@property (nonatomic) NSTimeInterval longBreakTime;
@property (nonatomic) NSInteger repeatCount;
@property (nonatomic) NSInteger longBreakDelay;

@end
