//
//  ZGCountDownTimer.m
//  ZGCountDownTimer
//
//  Created by Kyle Fang on 2/28/13.
//  Copyright (c) 2013 Kyle Fang. All rights reserved.
//

#import "ZGCountDownTimer.h"
#import "AppDelegate.h"

#define kZGCountDownTimerCompleteDateKey    @"countDownCompleteDate"
#define kZGCountDownTimerTimePassedKey      @"countDownTimePassed"
#define kZGCountDownTotalTimeKey            @"countDownTotalTime"
#define kZGCountDownRunningKey              @"countDownRunning"
#define kZGTaskTime                         @"taskTime"
#define kZGShortBreakTime                   @"shortBreakTime"
#define kZGLongBreakTime                    @"longBreakTime"
#define kZGCycleFinishTime                  @"cycleFinishTime"
#define kZGRepeatCount                      @"repeatCount"
#define kZGTaskCount                        @"taskCount"
#define kZGTimerCycleCount                  @"timerCycleCount"
#define kZGLongBreakDelay                   @"longBreakDelay"
#define kZGCountDownCycle                   @"countDownCycle"
#define kZGStartCountDate                   @"startCountDate"

#define kZGCountDownUserDefaultKey          @"ZGCountDownUserDefaults"

typedef NS_ENUM(NSInteger, CountDownCycleType) {
    TaskCycle,
    ShortBreakCycle,
    LongBreakCycle
};

@interface ZGCountDownTimer()

@property (nonatomic) NSTimer *defaultTimer;
@property (nonatomic) BOOL countDownRunning;
@property (nonatomic) NSDate *countDownCompleteDate;
@property (nonatomic) NSTimeInterval cycleFinishTime;
@property (nonatomic) CountDownCycleType cycle;
@property (nonatomic) NSInteger taskCount;
@property (nonatomic) NSInteger longBreakCount;
@property (nonatomic) NSInteger timerCycleCount;
@property (nonatomic) NSDate *startCountDate;

@end

@implementation ZGCountDownTimer

#pragma mark - init methods
static NSMutableDictionary *_countDownTimersWithIdentifier;

+ (ZGCountDownTimer *)defaultCountDownTimer
{
    return [self countDownTimerWithIdentifier:kZGCountDownUserDefaultKey];
}

+ (ZGCountDownTimer *)countDownTimerWithIdentifier:(NSString *)identifier
{
    if (!identifier) {
        identifier = kZGCountDownUserDefaultKey;
    }
    if (_countDownTimersWithIdentifier) {
        _countDownTimersWithIdentifier = [[NSMutableDictionary alloc] init];
    }
    ZGCountDownTimer *timer = [_countDownTimersWithIdentifier objectForKey:identifier];
    if (!timer) {
        timer = [[self alloc] init];
        timer.timerIdentifier = identifier;
        [_countDownTimersWithIdentifier setObject:timer forKey:identifier];
    }
    return timer;
}

#pragma mark - setup methods.

- (void)setupCountDownForTheFirstTime:(void (^)(ZGCountDownTimer *))firstBlock
                    restoreFromBackUp:(void (^)(ZGCountDownTimer *))restoreFromBackup
{
    if ([self backupExist]) {
        [self restoreMySelf];
        if (restoreFromBackup) {
            restoreFromBackup(self);
        }
    } else {
        if (firstBlock) {
            firstBlock(self);
        }
    }
}

#pragma mark - setters.

- (void)setTotalCountDownTime:(NSTimeInterval)totalCountDownTime
{
    _totalCountDownTime = totalCountDownTime;
    
    // The below methods are for setting initial cycle values and setting the textlabel values with initial taskTime when the app launches for the first time.
    [self setInitialCycleValues];
}

- (void)setCountDownRunning:(BOOL)countDownRunning
{
    _countDownRunning = countDownRunning;
    
    if (!self.defaultTimer && countDownRunning) {
        [self setupDefaultTimer];
    }
    
    // Checks if Timer was paused.
    if (!countDownRunning) {
        if (self.started) {
            [self notifyDelegateWithPassedTime:self.timePassed ofCycleFinishTime:self.cycleFinishTime];
        }
    }
}

#pragma mark - timer API methods.

- (BOOL)isRunning
{
    return self.countDownRunning;
}

- (BOOL)started
{
    return self.timePassed > 0;
}

- (BOOL)startCountDown
{
    if (!self.countDownRunning) {
        if (!self.started) {
            self.startCountDate = [NSDate date];
        } else {
            self.startCountDate = [[NSDate date] dateByAddingTimeInterval:-self.timePassed];
        }
        self.countDownRunning = YES;
        [self setupLocalNotifications];
        [self backUpMySelf];
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)pauseCountDown
{
    if (self.countDownRunning) {
        self.countDownRunning = NO;
        [[UIApplication sharedApplication] cancelAllLocalNotifications];
        [self backUpMySelf];
        return YES;
    }
    else {
        return NO;
    }
}

- (void)resetCountDown
{
    [self setInitialCycleValues];
    _countDownRunning = NO;
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
    [self removeSelfBackup];
}

- (void)skipCountDown
{
    if ([self backupExist]) {
        [self removeSelfBackup];
    }
    self.timePassed = self.cycleFinishTime;
    [self skipToNextCycle];
    [self backUpMySelf];
    [self notifyDelegateWithPassedTime:self.timePassed ofCycleFinishTime:self.cycleFinishTime];
}

#pragma mark - timer update method.

- (void)timerUpdated:(NSTimer *)timer
{
    NSLog(@"Timer Loop called");
    if (self.countDownRunning) {
        if (self.cycleFinishTime > self.totalCountDownTime) {
            if ([self.delegate respondsToSelector:@selector(countDownCompleted:)]) {
                [self.delegate countDownCompleted:self];
            }
            [self resetCountDown];
        } else {
            NSTimeInterval newTimePassed = round([self calcuateTimePassed]);
            NSLog(@"New TimePassed : %f", newTimePassed);
            
            if (newTimePassed < self.cycleFinishTime) {
                [self notifyDelegateWithPassedTime:newTimePassed ofCycleFinishTime:self.cycleFinishTime];
            } else if (newTimePassed == self.cycleFinishTime) {
                [self notifyDelegateWithPassedTime:newTimePassed ofCycleFinishTime:self.cycleFinishTime];
                
                switch (self.cycle) {
                    case TaskCycle:
                        self.timerCycleCount++;
                        if (![self checkIfLongBreakCycle:self.taskCount]) {
                            self.cycle = ShortBreakCycle;
                            self.cycleFinishTime += self.shortBreakTime;
                        } else {
                            self.cycle = LongBreakCycle;
                            self.cycleFinishTime += self.longBreakTime;
                        }
                        if ([self.delegate respondsToSelector:@selector(taskCompleted:)])
                            [self.delegate taskCompleted:self];
                        break;
                    case ShortBreakCycle:
                        self.cycle = TaskCycle;
                        self.taskCount++;
                        self.timerCycleCount++;
                        self.cycleFinishTime += self.taskTime;
                        if ([self.delegate respondsToSelector:@selector(shortBreakCompleted:)])
                            [self.delegate shortBreakCompleted:self];
                        break;
                    case LongBreakCycle:
                        self.cycle = TaskCycle;
                        self.taskCount++;
                        self.timerCycleCount++;
                        self.cycleFinishTime += self.taskTime;
                        if ([self.delegate respondsToSelector:@selector(longBreakCompleted:)])
                            [self.delegate longBreakCompleted:self];
                        break;
                }
            } else {
                while (self.cycleFinishTime < newTimePassed) {
                    // Check current countdown cycle and skip to next cycle.
                    [self skipToNextCycle];
                }

                if (self.cycleFinishTime > self.totalCountDownTime) {
                    [self notifyDelegateWithPassedTime:0 ofCycleFinishTime:self.taskTime];
                } else {
                    [self notifyDelegateWithPassedTime:newTimePassed ofCycleFinishTime:self.cycleFinishTime];
                }
            }
            
            self.timePassed = newTimePassed;
        }
    }
}

#pragma mark - helper methods

- (NSTimeInterval)calcuateTimePassed
{
    NSTimeInterval tempTimePassed = [[NSDate date] timeIntervalSinceDate:self.startCountDate];
    NSLog(@"TempTime passed: %f", tempTimePassed);
    NSLog(@"Old TimePassed : %f", self.timePassed);
    
    // Checks previous value to avoid skipping the count number.
    if ((tempTimePassed - self.timePassed) < 0.5) {
        return (tempTimePassed + 1.0);
    } else {
        return (tempTimePassed);
    }
}

- (BOOL)checkIfLongBreakCycle:(NSInteger)taskCount
{
    if (self.longBreakDelay > 0) {
        if (taskCount % self.longBreakDelay == 0) {
            return YES;
        } else {
            return NO;
        }
    } else {
        return NO;
    }
}

- (void)setupDefaultTimer
{
    self.defaultTimer = [NSTimer timerWithTimeInterval:1.f target:self selector:@selector(timerUpdated:) userInfo:nil repeats:YES];
    [self.defaultTimer fire];
    [[NSRunLoop mainRunLoop] addTimer:self.defaultTimer forMode:NSRunLoopCommonModes];
}

- (void)setInitialCycleValues
{
    self.startCountDate = [NSDate dateWithTimeIntervalSinceReferenceDate:0];
    self.timePassed = 0;
    self.cycleFinishTime = self.taskTime;
    self.cycle = TaskCycle;
    self.taskCount = 1;
    self.timerCycleCount = 1;
    [self notifyDelegateWithPassedTime:0 ofCycleFinishTime:self.taskTime];
}

- (void)skipToNextCycle
{
    switch (self.cycle) {
        case TaskCycle:
            self.timerCycleCount++;
            if (![self checkIfLongBreakCycle:self.taskCount]) {
                self.cycle = ShortBreakCycle;
                self.cycleFinishTime += self.shortBreakTime;
            } else {
                self.cycle = LongBreakCycle;
                self.cycleFinishTime += self.longBreakTime;
            }
            break;
        case ShortBreakCycle:
            self.cycle = TaskCycle;
            self.taskCount++;
            self.timerCycleCount++;
            self.cycleFinishTime += self.taskTime;
            break;
        case LongBreakCycle:
            self.cycle = TaskCycle;
            self.taskCount++;
            self.timerCycleCount++;
            self.cycleFinishTime += self.taskTime;
            break;
    }
}

- (void)notifyDelegateWithPassedTime:(NSTimeInterval)timePassed ofCycleFinishTime:(NSTimeInterval)finishTime
{
    if ([self.delegate respondsToSelector:@selector(secondUpdated:countDownTimePassed:ofTotalTime:ofCycle:)]) {
        [self.delegate secondUpdated:self countDownTimePassed:timePassed ofTotalTime:finishTime ofCycle:[self currentCycleName]];
    }
}

- (NSString *)currentCycleName
{
    NSString *cycleName;
    switch (self.cycle) {
        case TaskCycle:
            cycleName = @"Pomodoro";
            break;
        case ShortBreakCycle:
            cycleName = @"Short Break";
            break;
        case LongBreakCycle:
            cycleName = @"Long Break";
            break;
    }
    return cycleName;
}

#pragma mark - schedule local notifications

- (void)setupLocalNotifications
{
    // Calculates completion time of each cycle.
    NSTimeInterval tempCycleFinishTime = self.cycleFinishTime;
    CountDownCycleType cycleType = self.cycle;
    NSInteger taskTimerCount = self.taskCount;
    int notificationCount = (int)(self.repeatCount * 2 - self.timerCycleCount);
    
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.timeZone = nil;
    notification.soundName = nil;
    
    for (int i = 0; i < notificationCount; i++) {
        
        switch (cycleType) {
            case TaskCycle:
                notification.fireDate = [NSDate dateWithTimeIntervalSinceNow:(tempCycleFinishTime - self.timePassed)];
                notification.alertBody = [NSString stringWithFormat:@"Task Cycle # %d completed. Have a break.", (int)taskTimerCount] ;
                if (![self checkIfLongBreakCycle:taskTimerCount]) {
                    cycleType = ShortBreakCycle;
                    tempCycleFinishTime += self.shortBreakTime;
                } else {
                    cycleType = LongBreakCycle;
                    tempCycleFinishTime += self.longBreakTime;
                }
                break;
                
            case ShortBreakCycle:
                notification.fireDate = [NSDate dateWithTimeIntervalSinceNow:(tempCycleFinishTime - self.timePassed)];
                notification.alertBody = @"Short Break completed";
                cycleType = TaskCycle;
                tempCycleFinishTime += self.taskTime;
                taskTimerCount++;
                break;
                
            case LongBreakCycle:
                notification.fireDate = [NSDate dateWithTimeIntervalSinceNow:(tempCycleFinishTime - self.timePassed)];
                notification.alertBody = @"Long Break completed";
                cycleType = TaskCycle;
                tempCycleFinishTime += self.taskTime;
                taskTimerCount++;
                break;
        }
        
        [[UIApplication sharedApplication] scheduleLocalNotification:notification];
    }
    
    notification.fireDate = [NSDate dateWithTimeIntervalSinceNow:(self.totalCountDownTime - self.timePassed)];
    notification.alertBody = @"Well done. Task finished.";
    
    [[UIApplication sharedApplication] scheduleLocalNotification:notification];
}

#pragma mark - backup/restore methods

- (BOOL)backupExist
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *timerInfo = [defaults objectForKey:self.timerIdentifier];
    return timerInfo != nil;
}

- (void)backUpMySelf
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[self countDownInfoForBackup] forKey:self.timerIdentifier];
    [defaults synchronize];
}

- (void)restoreMySelf
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [self restoreWithCountDownBackup:[defaults objectForKey:self.timerIdentifier]];
}

- (void)removeSelfBackup
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:nil forKey:self.timerIdentifier];
    [defaults synchronize];
}

- (NSDictionary *)countDownInfoForBackup
{
    return @{
             kZGStartCountDate: self.startCountDate,
             kZGCountDownTimerTimePassedKey: [NSNumber numberWithDouble:self.timePassed],
             kZGCountDownTotalTimeKey: [NSNumber numberWithDouble:self.totalCountDownTime],
             kZGCountDownRunningKey: [NSNumber numberWithBool:self.countDownRunning],
             kZGTaskTime: [NSNumber numberWithDouble:self.taskTime],
             kZGShortBreakTime: [NSNumber numberWithDouble:self.shortBreakTime],
             kZGLongBreakTime: [NSNumber numberWithDouble:self.longBreakTime],
             kZGCycleFinishTime: [NSNumber numberWithDouble:self.cycleFinishTime],
             kZGRepeatCount: [NSNumber numberWithInteger:self.repeatCount],
             kZGTaskCount: [NSNumber numberWithInteger:self.taskCount],
             kZGTimerCycleCount: [NSNumber numberWithInteger:self.timerCycleCount],
             kZGLongBreakDelay : [NSNumber numberWithInteger:self.longBreakDelay],
             kZGCountDownCycle: [NSNumber numberWithInt:self.cycle]
             };
}

- (void)restoreWithCountDownBackup:(NSDictionary *)countDownInfo
{
    self.totalCountDownTime = [[countDownInfo valueForKey:kZGCountDownTotalTimeKey] doubleValue];
    self.timePassed = [[countDownInfo valueForKey:kZGCountDownTimerTimePassedKey] doubleValue];
    self.startCountDate = [countDownInfo valueForKey:kZGStartCountDate];
    self.taskTime = [[countDownInfo valueForKey:kZGTaskTime] doubleValue];
    self.shortBreakTime = [[countDownInfo valueForKey:kZGShortBreakTime] doubleValue];
    self.longBreakTime = [[countDownInfo valueForKey:kZGLongBreakTime] doubleValue];
    self.cycleFinishTime = [[countDownInfo valueForKey:kZGCycleFinishTime] doubleValue];
    self.repeatCount = [[countDownInfo valueForKey:kZGRepeatCount] integerValue];
    self.taskCount = [[countDownInfo valueForKey:kZGTaskCount] integerValue];
    self.timerCycleCount = [[countDownInfo valueForKey:kZGTimerCycleCount] integerValue];
    self.longBreakDelay = [[countDownInfo valueForKey:kZGLongBreakDelay] integerValue];
    self.cycle = [[countDownInfo valueForKey:kZGCountDownCycle] intValue];
    self.countDownRunning = [[countDownInfo valueForKey:kZGCountDownRunningKey] boolValue];
}

- (void)dealloc
{
    [self.defaultTimer invalidate];
}

+ (NSString *)getDateStringForTimeInterval:(NSTimeInterval)timeInterval
{
    return [self getDateStringForTimeInterval:timeInterval withDateFormatter:nil];
}

+ (NSString *)getDateStringForTimeInterval:(NSTimeInterval )timeInterval withDateFormatter:(NSNumberFormatter *)formatter
{
    double hours;
    double minutes;
    double seconds = round(timeInterval);
    hours = floor(seconds / 3600.);
    seconds -= 3600. * hours;
    minutes = floor(seconds / 60.);
    seconds -= 60. * minutes;
    
    if (!formatter) {
        formatter = [[NSNumberFormatter alloc] init];
        [formatter setFormatterBehavior:NSNumberFormatterBehaviorDefault];
        [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
        [formatter setMaximumFractionDigits:1];
        [formatter setPositiveFormat:@"#00"];  // Use @"#00.0" to display milliseconds as decimal value.
    }
    
    NSString *secondsInString = [formatter stringFromNumber:[NSNumber numberWithDouble:seconds]];
    
    if (hours == 0) {
        return [NSString stringWithFormat:NSLocalizedString(@"%02.0f:%@", @"Short format for elapsed time (minute:second). Example: 05:3.4"), minutes, secondsInString];
    } else {
        return [NSString stringWithFormat:NSLocalizedString(@"%.0f:%02.0f:%@", @"Short format for elapsed time (hour:minute:second). Example: 1:05:3.4"), hours, minutes, secondsInString];
    }
}

@end
