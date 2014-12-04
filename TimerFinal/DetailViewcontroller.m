//
//  DetailViewcontroller.m
//  TimerFinal
//
//  Created by Sibin Baby on 4/12/2014.
//  Copyright (c) 2014 Sibin Baby. All rights reserved.
//

#import "DetailViewcontroller.h"
#import "BTViewController.h"

@interface DetailViewcontroller () <BTViewControllerDelegate>
@end

@implementation DetailViewcontroller

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)secondUpdated:(BTViewController *)sender
{
    NSLog(@"It updates");
}
- (IBAction)cancel:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
