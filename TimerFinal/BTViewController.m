//
//  BTViewController.m
//  BreakTimer
//
//  Created by Sibin Baby on 19/04/2014.
//  Copyright (c) 2014 BreakTimer. All rights reserved.
//

#import "BTViewController.h"
#import "ZGCountDownTimer.h"

#define kDefaultCountDownNotificationKey @"countDownNotificationKey"

@interface BTViewController () <ZGCountDownTimerDelegate>

@property (weak, nonatomic) IBOutlet UILabel *timerLabel;
@property (weak, nonatomic) IBOutlet UILabel *cycleLabel;
@property (weak, nonatomic) IBOutlet UIButton *startButton;
@property (weak, nonatomic) IBOutlet UIButton *resetButton;

@property(strong, nonatomic) ZGCountDownTimer *myCountDownTimer;
@property(strong, nonatomic) UILocalNotification *localNotification;

- (IBAction)startButtonPressed:(id)sender;
- (IBAction)resetButtonPressed:(id)sender;
- (IBAction)skipButtonPressed:(id)sender;

@end

@implementation BTViewController

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:YES];
    NSLog(@"view will appear");
}
- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.taskTime = 20;
    self.shortBreakTime = 10;
    self.longBreakTime = 15;
    self.repeatCount = 3;
    self.longBreakDelay = 2;
    
    self.myCountDownTimer = [ZGCountDownTimer countDownTimerWithIdentifier:nil];
    self.myCountDownTimer.delegate = self;
    
    [self.myCountDownTimer setupCountDownForTheFirstTime:^(ZGCountDownTimer *timer) {
        timer.taskTime = self.taskTime;
        timer.shortBreakTime = self.shortBreakTime;
        timer.longBreakTime = self.longBreakTime;
        timer.repeatCount = self.repeatCount;
        timer.longBreakDelay = self.longBreakDelay;
        timer.totalCountDownTime = [self calculateTotalCountDownTime];
    } restoreFromBackUp:^(ZGCountDownTimer *timer) {}];
    
    if (![self.myCountDownTimer isRunning]) {
        if (!self.myCountDownTimer.started)
            [self.startButton setTitle:@"Start" forState:UIControlStateNormal];
        else
            [self.startButton setTitle:@"Resume" forState:UIControlStateNormal];
    } else {
        [self.startButton setTitle:@"Pause" forState:UIControlStateNormal];
    }
}

- (NSTimeInterval)calculateTotalCountDownTime
{
    int longBreakCount = 0;
    
    if (self.longBreakDelay > 0) {
        longBreakCount = (int)(self.repeatCount / self.longBreakDelay);
    }
    
    NSTimeInterval totalTime = self.taskTime * self.repeatCount + self.shortBreakTime * (self.repeatCount - longBreakCount) + self.longBreakTime * longBreakCount;
    
    return totalTime;
}

- (UILocalNotification *)localNotification
{
    if (!_localNotification) {
        NSArray *localNotifications = [[UIApplication sharedApplication] scheduledLocalNotifications];
        for (UILocalNotification *noti in localNotifications) {
            NSString *identifier = [noti.userInfo valueForKey:kDefaultCountDownNotificationKey];
            if ([identifier isEqualToString:self.tabBarItem.title]) {
                _localNotification = noti;
                return _localNotification;
            }
        }
        _localNotification = [[UILocalNotification alloc] init];
        _localNotification.userInfo = @{kDefaultCountDownNotificationKey : @"Timer"};
        _localNotification.alertBody = @"Count down completed";
        _localNotification.soundName = UILocalNotificationDefaultSoundName;
    }
    return _localNotification;
}

- (IBAction)startButtonPressed:(id)sender {
    if (![self.myCountDownTimer isRunning]) {
        [self.myCountDownTimer startCountDown];
//        self.localNotification.fireDate = [NSDate dateWithTimeIntervalSinceNow:(self.myCountDownTimer.totalCountDownTime - self.myCountDownTimer.timePassed)];
//        [[UIApplication sharedApplication] scheduleLocalNotification:self.localNotification];
        [self.startButton setTitle:@"Pause" forState:UIControlStateNormal];
    } else {
        [self.myCountDownTimer pauseCountDown];
//        [[UIApplication sharedApplication] cancelLocalNotification:self.localNotification];
        if (!self.myCountDownTimer.started)
            [self.startButton setTitle:@"Start" forState:UIControlStateNormal];
        else
            [self.startButton setTitle:@"Resume" forState:UIControlStateNormal];
    }
}

- (IBAction)resetButtonPressed:(id)sender {
    [self.myCountDownTimer resetCountDown];
//    [[UIApplication sharedApplication] cancelLocalNotification:self.localNotification];
    [self.startButton setTitle:@"Start" forState:UIControlStateNormal];
}

- (IBAction)skipButtonPressed:(id)sender {
    [self.myCountDownTimer skipCountDown];
}

#pragma mark - Delegate methods.

- (void)secondUpdated:(ZGCountDownTimer *)sender countDownTimePassed:(NSTimeInterval)timePassed ofTotalTime:(NSTimeInterval)totalTime ofCycle:(NSString *)cycle{
    self.timerLabel.text = [ZGCountDownTimer getDateStringForTimeInterval:(totalTime - timePassed)];
    self.cycleLabel.text = cycle;
}

- (void)countDownCompleted:(ZGCountDownTimer *)sender {
    // Set start button title to 'START' after finishing timer.
    [self.startButton setTitle:@"Start" forState:UIControlStateNormal];
//    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Task Completed"
//                                                        message:@"Count down completed"
//                                                       delegate:nil
//                                              cancelButtonTitle:@"Dismiss"
//                                              otherButtonTitles:nil];
//    [alertView show];
}

- (void)taskCompleted:(ZGCountDownTimer *)sender {
//    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Task Finished" message:@"Task Cycle Completed" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
//    [alertView show];
}

- (void)shortBreakCompleted:(ZGCountDownTimer *)sender {
//    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Short Break Finished" message:@"Short Break Cycle Completed" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
//    [alertView show];
}

- (void)longBreakCompleted:(ZGCountDownTimer *)sender{
//    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Long Break Finished" message:@"Long Break Cycle Completed" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
//    [alertView show];
}

@end

