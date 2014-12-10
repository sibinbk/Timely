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
#define kZGCycleTime                        @"cycleTime"
#define kZGRepeatCount                      @"repeatCount"
#define kZGTaskCount                        @"taskCount"
#define kZGTimerCycleCount                  @"timerCycleCount"
#define kZGLongBreakDelay                   @"longBreakDelay"
#define kZGCountDownCycle                   @"countDownCycle"

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
@property (nonatomic) NSTimeInterval cycleTime;
@property (nonatomic) CountDownCycleType cycle;
@property (nonatomic) NSInteger taskCount;
@property (nonatomic) NSInteger longBreakCount;
@property (nonatomic) NSInteger timerCycleCount;

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
    }
    else {
        _totalCountDownTime = 0;
        self.timePassed = 0;
        self.taskTime = 0;
        self.shortBreakTime = 0;
        self.repeatCount = 0;

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
    [self setInitiaCycleValues];
    [self notifyDelegate:self.taskTime];
}

- (void)setCountDownRunning:(BOOL)countDownRunning
{
    _countDownRunning = countDownRunning;
    
    if (!self.defaultTimer && countDownRunning) {
        [self setupDefaultTimer];
    }
    
    if (!countDownRunning) {
        if (!self.started) {
            [self notifyDelegate:self.taskTime];
        } else {
            [self notifyDelegate:self.cycleTime];
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
    if (![self countDownRunning]) {
        if (self.totalCountDownTime > self.timePassed) {
            self.countDownCompleteDate = [NSDate dateWithTimeInterval:(self.totalCountDownTime - self.timePassed) sinceDate:[NSDate date]];
            self.countDownRunning = YES;
            [self setupLocalNotifications];
            [self backUpMySelf];
            return YES;
        } else {
            [self.delegate countDownCompleted:self];
            [self removeSelfBackup];
            return NO;
        }
    } else {
        return NO;
    }
}

- (BOOL)pauseCountDown
{
    if ([self countDownRunning]) {
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
    self.timePassed = 0;
    self.countDownRunning = NO;
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
    [self setInitiaCycleValues];
    [self removeSelfBackup];
}

#pragma mark - timer update method.

- (void)timerUpdated:(NSTimer *)timer
{
    if ([self countDownRunning]) {
        if ([self.countDownCompleteDate timeIntervalSinceNow] <= 0 && self.taskCount > self.repeatCount) {
            self.timePassed = MAX(0, round(self.totalCountDownTime - [self.countDownCompleteDate timeIntervalSinceNow]));
            if ([self.delegate respondsToSelector:@selector(countDownCompleted:)]) {
                [self.delegate countDownCompleted:self];
            }
            [self resetCountDown];
        }
        else {
            NSTimeInterval newTimePassed = round(self.totalCountDownTime - [self.countDownCompleteDate timeIntervalSinceNow]);
            
            if (self.cycleTime < newTimePassed) {
                while (self.cycleTime < newTimePassed) {
                    switch (self.cycle) {
                        case TaskCycle:
                            self.timerCycleCount++;
                            if (![self checkIfLongBreakCycle:self.taskCount]) {
                                self.cycle = ShortBreakCycle;
                                self.cycleTime += self.shortBreakTime;
                            } else {
                                self.cycle = LongBreakCycle;
                                self.cycleTime += self.longBreakTime;
                            }
                            break;
                            
                        case ShortBreakCycle:
                            self.cycle = TaskCycle;
                            self.taskCount++;
                            self.timerCycleCount++;
                            self.cycleTime += self.taskTime;
                            break;
                            
                        case LongBreakCycle:
                            self.cycle = TaskCycle;
                            self.taskCount++;
                            self.timerCycleCount++;
                            self.cycleTime += self.taskTime;
                            break;
                    }
                    
                    [self notifySpecificDelegateMethod:newTimePassed];
                }
            } else if (self.cycleTime == newTimePassed) {
                
                [self notifySpecificDelegateMethod:newTimePassed];
                
                switch (self.cycle) {
                    case TaskCycle:
                        self.timerCycleCount++;
                        if (![self checkIfLongBreakCycle:self.taskCount]) {
                            self.cycle = ShortBreakCycle;
                            self.cycleTime += self.shortBreakTime;
                        } else {
                            self.cycle = LongBreakCycle;
                            self.cycleTime += self.longBreakTime;
                        }
                        if ([self.delegate respondsToSelector:@selector(taskCompleted:)])
                            [self.delegate taskCompleted:self];
                        break;
                        
                    case ShortBreakCycle:
                        self.cycle = TaskCycle;
                        self.taskCount++;
                        self.timerCycleCount++;
                        self.cycleTime += self.taskTime;
                        if ([self.delegate respondsToSelector:@selector(shortBreakCompleted:)])
                            [self.delegate shortBreakCompleted:self];
                        break;
                        
                    case LongBreakCycle:
                        self.cycle = TaskCycle;
                        self.taskCount++;
                        self.timerCycleCount++;
                        self.cycleTime += self.taskTime;
                        if ([self.delegate respondsToSelector:@selector(longBreakCompleted:)])
                            [self.delegate longBreakCompleted:self];
                        break;
                }
            } else {
                [self notifySpecificDelegateMethod:newTimePassed];
            }
            
            self.timePassed = newTimePassed;
        }
    }
}

#pragma mark - helper methods

- (BOOL)checkIfLongBreakCycle:(NSInteger)taskCount
{
    if (self.longBreakDelay == 0) {
        return NO;
    } else {
        if (taskCount % self.longBreakDelay == 0) {
            return YES;
        } else {
            return NO;
        }
    }
}

- (void)setupDefaultTimer
{
    self.defaultTimer = [NSTimer timerWithTimeInterval:1.f target:self selector:@selector(timerUpdated:) userInfo:nil repeats:YES];
    [self.defaultTimer fire];
    [[NSRunLoop mainRunLoop] addTimer:self.defaultTimer forMode:NSRunLoopCommonModes];
}

- (void)setInitiaCycleValues
{
    self.cycleTime = self.taskTime;
    self.cycle = TaskCycle;
    self.taskCount = 1;
    self.timerCycleCount = 1;
}

- (void)notifyDelegate:(NSTimeInterval)newCycleTime
{
    if ([self.delegate respondsToSelector:@selector(secondUpdated:countDownTimePassed:ofTotalTime:)]) {
        [self.delegate secondUpdated:self countDownTimePassed:self.timePassed ofTotalTime:newCycleTime];
    }
}

- (void)notifySpecificDelegateMethod:(NSTimeInterval)newTimePassed
{
    if ([self.delegate respondsToSelector:@selector(secondUpdated:countDownTimePassed:ofTotalTime:)]) {
        [self.delegate secondUpdated:self countDownTimePassed:newTimePassed ofTotalTime:self.cycleTime];
    }
}

#pragma mark - schedule local notifications

- (void)setupLocalNotifications
{
    // Calculates completion time of each cycle.
    NSTimeInterval cycleFinishTime = self.cycleTime;
    CountDownCycleType cycleType = self.cycle;
    NSInteger taskTimerCount = self.taskCount;
    int notificationCount = (int)(self.repeatCount * 2 - self.timerCycleCount);
    
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.timeZone = nil;
    notification.soundName = UILocalNotificationDefaultSoundName;
    
    for (int i = 0; i < notificationCount; i++) {
        
        switch (cycleType) {
            case TaskCycle:
                notification.fireDate = [NSDate dateWithTimeIntervalSinceNow:(cycleFinishTime - self.timePassed)];
                notification.alertBody = [NSString stringWithFormat:@"Task Cycle # %d completed. Have a break.", (int)taskTimerCount] ;
                if (![self checkIfLongBreakCycle:taskTimerCount]) {
                    cycleType = ShortBreakCycle;
                    cycleFinishTime += self.shortBreakTime;
                } else {
                    cycleType = LongBreakCycle;
                    cycleFinishTime += self.longBreakTime;
                }
                break;
                
            case ShortBreakCycle:
                notification.fireDate = [NSDate dateWithTimeIntervalSinceNow:(cycleFinishTime - self.timePassed)];
                notification.alertBody = @"Short Break completed";
                cycleType = TaskCycle;
                cycleFinishTime += self.taskTime;
                taskTimerCount++;
                break;
                
            case LongBreakCycle:
                notification.fireDate = [NSDate dateWithTimeIntervalSinceNow:(cycleFinishTime - self.timePassed)];
                notification.alertBody = @"Long Break completed";
                cycleType = TaskCycle;
                cycleFinishTime += self.taskTime;
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
    return @{kZGCountDownTimerCompleteDateKey: self.countDownCompleteDate,
             kZGCountDownTimerTimePassedKey: [NSNumber numberWithDouble:self.timePassed],
             kZGCountDownTotalTimeKey: [NSNumber numberWithDouble:self.totalCountDownTime],
             kZGCountDownRunningKey: [NSNumber numberWithBool:self.countDownRunning],
             kZGTaskTime: [NSNumber numberWithDouble:self.taskTime],
             kZGShortBreakTime: [NSNumber numberWithDouble:self.shortBreakTime],
             kZGLongBreakTime: [NSNumber numberWithDouble:self.longBreakTime],
             kZGCycleTime: [NSNumber numberWithDouble:self.cycleTime],
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
    self.countDownCompleteDate = [countDownInfo valueForKey:kZGCountDownTimerCompleteDateKey];
    self.taskTime = [[countDownInfo valueForKey:kZGTaskTime] doubleValue];
    self.shortBreakTime = [[countDownInfo valueForKey:kZGShortBreakTime] doubleValue];
    self.longBreakTime = [[countDownInfo valueForKey:kZGLongBreakTime] doubleValue];
    self.cycleTime = [[countDownInfo valueForKey:kZGCycleTime] doubleValue];
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
