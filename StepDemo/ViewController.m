//
//  ViewController.m
//  StepDemo
//
//  Created by XX on 2024/3/26.
//

#import "ViewController.h"
#import <HealthKit/HealthKit.h>
#import <CoreMotion/CoreMotion.h>
@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIButton *dateButton;
@property (weak, nonatomic) IBOutlet UILabel *hkStepLabel;
@property (weak, nonatomic) IBOutlet UILabel *hkDistanceLabel;

@property (weak, nonatomic) IBOutlet UILabel *cmStepLabel;
@property (weak, nonatomic) IBOutlet UILabel *cmDistanceLabel;

@property (weak, nonatomic) IBOutlet UITextView *logTextView;

@property (nonatomic, strong)NSDate *startDate;
@property (nonatomic,strong) CMPedometer *pedometer;

// 创建healthStore实例对象
@property (nonatomic,strong) HKHealthStore *healthStore;
// 查询数据的类型，比如计步，行走+跑步距离等等
@property (nonatomic,strong) HKQuantityType *quantityType;
@property (nonatomic, strong)HKQuantityType *quantityDistanceType;
// 谓词，用于限制查询返回结果
@property (nonatomic,strong) NSPredicate *predicate;

@property (nonatomic, strong) HKQueryAnchor *lastAnchor;
@property (nonatomic, strong) HKQueryAnchor *lastDistanceAnchor;
@property (nonatomic, assign) NSInteger hkTotalStep;
@property (nonatomic, assign) float hkDistance;
@property (nonatomic, strong) NSDateFormatter *formatter;
@end

@implementation ViewController
-(NSDateFormatter *)formatter {
    if (!_formatter) {
        _formatter = [[NSDateFormatter alloc] init];
        [_formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        [_formatter setTimeZone:[NSTimeZone localTimeZone]];
    }
    return _formatter;
}
- (IBAction)dateButtonAction:(UIButton *)sender {
    self.startDate = [NSDate date];
    
    NSString *dateStr = [NSString stringWithFormat:@"开始时间：%@",[self.formatter stringFromDate:self.startDate]];
    [sender setTitle:dateStr forState:UIControlStateNormal];
    [[NSUserDefaults standardUserDefaults] setObject:self.startDate forKey:@"startdate"];
    [[NSUserDefaults standardUserDefaults]synchronize];
    self.hkDistance = 0;
    self.hkTotalStep = 0;
    self.predicate = nil;
    [self hkStopObserverQuery];
    [self hkObserverQuery];
//    [self pedometerStopUpdatesData];
    [self pedometerQueryToday];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.startDate = [[NSUserDefaults standardUserDefaults]objectForKey:@"startdate"];
    if (self.startDate == nil) {
        self.startDate = [NSDate date];
    }
    NSString *dateStr = [NSString stringWithFormat:@"开始时间：%@",[self.formatter stringFromDate:self.startDate]];
    [self.dateButton setTitle:dateStr forState:UIControlStateNormal];
    
    self.lastAnchor = [HKQueryAnchor anchorFromValue:0];
    self.lastDistanceAnchor = [HKQueryAnchor anchorFromValue:0];
    
    if ([HKHealthStore isHealthDataAvailable]) {
        NSSet *readObjectTypes = [NSSet setWithObjects:[HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount],[HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceWalkingRunning], nil];
        // 向用户请求授权共享或读取健康App数据
        [self.healthStore requestAuthorizationToShareTypes:nil readTypes:readObjectTypes completion:^(BOOL success, NSError * _Nullable error) {
            if(success){
                [self queryTotalStepCount:^(NSInteger stepCount) {
//                    dispatch_async(dispatch_get_main_queue(), ^{
//                        self.hkStepLabel.text = [NSString stringWithFormat:@"%ld",(long)stepCount];
//                    });
                 
                }];
                [self hkQueryToday:^(NSInteger stepCount) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSLog(@"真实运动步数(总步数 - 编辑的步数) = %ld",(long)stepCount);
                           [self logWithStr:[NSString stringWithFormat:@"当天真实运动步数(总步数 - 编辑的步数) = %ld",(long)stepCount]];
                    });
                }];
                [self hkObserverQuery];
            }else{
                NSLog(@"获取步数权限失败");
                [self logWithStr:@"获取步数权限失败"];
            }
        }];
    }
    else{
        [self logWithStr:@"不支持HealthKit"];
    }
    
    /// 创建计步器对象
    if ([CMPedometer isStepCountingAvailable] && [CMPedometer isDistanceAvailable]) { // 8.0 之后可使用
        self.pedometer = [[CMPedometer alloc] init];
        [self pedometerUpdatesData];
    }
    else {
        [self logWithStr:@"不支持计步器"];
    }

}

#pragma mark == HealthKit

- (HKHealthStore *)healthStore{
    if(_healthStore == nil){
        _healthStore = [[HKHealthStore alloc]init];
        }
    return _healthStore;
}

- (HKQuantityType *)quantityType{
    if(_quantityType == nil){
        _quantityType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    }
    return _quantityType;
}
- (HKQuantityType *)quantityDistanceType {
    if (!_quantityDistanceType) {
        _quantityDistanceType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceWalkingRunning];
    }
    return _quantityDistanceType;
}

- (NSPredicate *)predicate{
    if(_predicate == nil){
        // 构造当天时间段查询参数
        NSCalendar *calendar = [NSCalendar currentCalendar];
//        NSDate *now = [NSDate date];
        // 开始时间
        NSDate *startDate = self.startDate;
//        [calendar startOfDayForDate:self.startDate];
        // 结束时间
        NSDate *endDate = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:startDate options:0];
        _predicate = [HKQuery predicateForSamplesWithStartDate:startDate endDate:endDate options:HKQueryOptionStrictStartDate];
    }
    return _predicate;
}
- (void)hkStopObserverQuery {
    [self.healthStore disableBackgroundDeliveryForType:self.quantityType withCompletion:^(BOOL success, NSError * _Nullable error) {
        [self logWithStr:success?@"关闭监控步数成功":@"关闭监控步数失败"];
    }];
    [self.healthStore disableBackgroundDeliveryForType:self.quantityDistanceType withCompletion:^(BOOL success, NSError * _Nullable error) {
        [self logWithStr:success?@"关闭监控距离成功":@"关闭监控距离失败"];
    }];
}
- (void)hkObserverQuery {
        [self.healthStore enableBackgroundDeliveryForType:self.quantityType frequency:HKUpdateFrequencyImmediate withCompletion:^(BOOL success, NSError *error) {
            if (success) {
                NSLog(@"启动步数的通知");
            }else{
                NSLog(@"启动步数的通知失败");
            }
        }];
        HKObserverQuery *query = [[HKObserverQuery alloc] initWithSampleType:self.quantityType predicate:nil updateHandler:^(HKObserverQuery *query, HKObserverQueryCompletionHandler completionHandler, NSError *error) {
            NSLog(@"healthKit 监听步数 %@",error);
            [self logWithStr:error ? @"healthKit 监听步数 错误": @"healthKit 监听步数信息"];
            [self hkAnchoredObjectQuery];
        }];

        [self.healthStore executeQuery:query];
    
    [self.healthStore enableBackgroundDeliveryForType:self.quantityDistanceType frequency:HKUpdateFrequencyImmediate withCompletion:^(BOOL success, NSError *error) {
        if (success) {
            NSLog(@"启动距离的通知");
        }else{
            NSLog(@"启动距离的通知失败");
        }
    }];
    
    HKObserverQuery *dquery = [[HKObserverQuery alloc] initWithSampleType:self.quantityDistanceType predicate:nil updateHandler:^(HKObserverQuery *query, HKObserverQueryCompletionHandler completionHandler, NSError *error) {
        NSLog(@"distance healthKit 监听距离 %@",error);
        [self logWithStr:error ? @"distance healthKit 监听距离 错误": @"distance healthKit 监听距离信息"];
        [self hkAnchoredObjectDistanceQuery];
    }];

    [self.healthStore executeQuery:dquery];
}
- (void)hkAnchoredObjectQuery {
    
    HKAnchoredObjectQuery *query = [[HKAnchoredObjectQuery alloc]initWithType:self.quantityType predicate:self.predicate anchor:self.lastAnchor limit:20 resultsHandler:^(HKAnchoredObjectQuery * _Nonnull query, NSArray<__kindof HKSample *> * _Nullable sampleObjects, NSArray<HKDeletedObject *> * _Nullable deletedObjects, HKQueryAnchor * _Nullable newAnchor, NSError * _Nullable error) {
        self.lastAnchor = newAnchor;
        HKUnit *unit = [HKUnit countUnit];
        for (HKQuantitySample *sample in sampleObjects){
            NSLog(@"%@ 步数：%ld ",sample.device.name,(long)[sample.quantity doubleValueForUnit:unit]);
            [self logWithStr:[NSString stringWithFormat:@"%@ 步数：%ld ",sample.device.name,(long)[sample.quantity doubleValueForUnit:unit]]];
            if ([sample.device.name isEqualToString:@"iPhone"]) {
                self.hkTotalStep += (long)[sample.quantity doubleValueForUnit:unit];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                self.hkStepLabel.text = [NSString stringWithFormat:@"%ld 步",(long)self.hkTotalStep];
            });
        }
    }];
    [self.healthStore executeQuery:query];
    
}
- (void)hkAnchoredObjectDistanceQuery {
    HKAnchoredObjectQuery *dquery = [[HKAnchoredObjectQuery alloc]initWithType:self.quantityDistanceType predicate:self.predicate anchor:self.lastDistanceAnchor limit:20 resultsHandler:^(HKAnchoredObjectQuery * _Nonnull query, NSArray<__kindof HKSample *> * _Nullable sampleObjects, NSArray<HKDeletedObject *> * _Nullable deletedObjects, HKQueryAnchor * _Nullable newAnchor, NSError * _Nullable error) {
        self.lastDistanceAnchor = newAnchor;
        for (HKQuantitySample *sample in sampleObjects){
            double distance = [sample.quantity doubleValueForUnit:[HKUnit meterUnit]];
            NSLog(@"%@ 距离：%f",sample.device.name,distance);
            [self logWithStr:[NSString stringWithFormat:@"%@ 距离：%f",sample.device.name,distance]];
            if ([sample.device.name isEqualToString:@"iPhone"]) {
                self.hkDistance += distance;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                self.hkDistanceLabel.text = [NSString stringWithFormat:@"%.2f 米", self.hkDistance];
            });
        }
    }];
    [self.healthStore executeQuery:dquery];
}
- (void)hkQueryToday:(void(^)(NSInteger stepCount))completion {
    
    // 结果排序，从开始到结束依次
    NSSortDescriptor *startSortDec = [NSSortDescriptor sortDescriptorWithKey:HKPredicateKeyPathStartDate ascending:NO];
    NSSortDescriptor *endSortDec = [NSSortDescriptor sortDescriptorWithKey:HKPredicateKeyPathEndDate ascending:NO];
    
    HKSampleQuery *sampleQuery = [[HKSampleQuery alloc]initWithSampleType:self.quantityType predicate:self.predicate limit:HKObjectQueryNoLimit sortDescriptors:@[startSortDec,endSortDec] resultsHandler:^(HKSampleQuery * _Nonnull query, NSArray<__kindof HKSample *> * _Nullable results, NSError * _Nullable error) {
        if(error){
            !completion?:completion(0);
            return;
        }else{
            // 单位
            HKUnit *unit = [HKUnit countUnit];
            // 计算iPhone记录的步数
            NSInteger iPhoneCount = 0;
            // 计算iWatch记录的步数
            NSInteger iWatchCount = 0;
            // 计算健康App手动编辑的步数
            NSInteger userEnteredCount = 0;
            // 计算第三方App写入的步数
            NSInteger thirdAppCount = 0;
            // 遍历样本
            for (HKQuantitySample *sample in results){
                // 样本步数
                NSInteger count = (NSInteger)[sample.quantity doubleValueForUnit:unit];
                // 设备名称
                NSString *deviceName = sample.device.name;
                if (deviceName == nil) { // 包含手动编辑和第三方App写入
                    // 判断用户手动录入的数据。
                    NSInteger isUserEntered = [sample.metadata[HKMetadataKeyWasUserEntered] integerValue];;
                    if(isUserEntered == 1){
                        userEnteredCount += count;
                    }else{
                        thirdAppCount += count;
                    }
                }else if ([deviceName isEqualToString:@"iPhone"]){
                    iPhoneCount += count;
                }else if ([deviceName isEqualToString:@"Apple Watch"]){
                    iWatchCount += count;
                }
            }
            NSLog(@"iPhone记录的步数 = %ld",(long)iPhoneCount);
            NSLog(@"iWatch记录的步数 = %ld",(long)iWatchCount);
            NSLog(@"健康App手动编辑的步数 = %ld",(long)userEnteredCount);
            NSLog(@"第三方App写入的步数 = %ld",(long)thirdAppCount);
            // 主线程更新UI
            dispatch_async(dispatch_get_main_queue(), ^{
                !completion?:completion(iPhoneCount);
            });
        }
    }];
    [self.healthStore executeQuery:sampleQuery];
}
//这里的步数是总步数，和各个来源 包含手动编辑录入的
// HKStatisticsOptionCumulativeSum 总步数
// HKStatisticsOptionSeparateBySource 健康App所有步数数据的来源，包括iPhone、iWatch、健康App、第三方App等
- (void)queryTotalStepCount:(void(^)(NSInteger stepCount))completion{
//    NSPredicate *nowPredicate = [HKQuery predicateForSamplesWithStartDate:self.startDate endDate:[NSDate date] options:HKQueryOptionStrictStartDate];
    HKStatisticsQuery *query = [[HKStatisticsQuery alloc]initWithQuantityType:self.quantityType quantitySamplePredicate:self.predicate options:HKStatisticsOptionCumulativeSum|HKStatisticsOptionSeparateBySource completionHandler:^(HKStatisticsQuery * _Nonnull query, HKStatistics * _Nullable result, NSError * _Nullable error) {
        if (error) {
            NSLog(@"healthKit 获取失败！");
            !completion?:completion(0);
            return;
        }
        // 总步数
        double totalStepCount = [result.sumQuantity doubleValueForUnit:[HKUnit countUnit]];
        // 健康App编辑的步数
        double userEnteredCount = 0;
        // 遍历数据来源，获得健康App编辑的数值
        for(HKSource *source in result.sources){
            NSLog(@"%@",source.name);
            if([source.name isEqualToString:@"健康"]){
                userEnteredCount = [[result sumQuantityForSource:source] doubleValueForUnit:[HKUnit countUnit]];
            }
        }
        NSLog(@"今天healthKit步数%ld",(long)(totalStepCount - userEnteredCount));
        [self logWithStr:[NSString stringWithFormat:@"今天healthKit步数%ld",(long)(totalStepCount - userEnteredCount)]];
        !completion?:completion((NSInteger)(totalStepCount - userEnteredCount));
    }];
    [self.healthStore executeQuery:query];
}

#pragma mark == CoreMotion
- (void)pedometerQueryToday{
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    // 开始时间
    NSDate *startDate = self.startDate;
//    [calendar startOfDayForDate:now];
    // 结束时间
    NSDate *endDate = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:startDate options:0];
    
    // 查询当天数据
    [self.pedometer queryPedometerDataFromDate:startDate toDate:endDate withHandler:^(CMPedometerData * _Nullable pedometerData, NSError * _Nullable error) {
        if (error) {
            NSLog(@"获取失败");
            [self logWithStr:[NSString stringWithFormat:@"获取失败"]];
        } else {
            // 步数
            double stepCount = [pedometerData.numberOfSteps doubleValue];
            NSLog(@" 通过计步器获取当天步数： %ld",(long)stepCount);
            [self logWithStr:[NSString stringWithFormat:@" 通过计步器获取当天步数： %ld",(long)stepCount]];
            // 距离，若值为nil，不支持平台（下同）
            double distance = [pedometerData.distance doubleValue];
            NSLog(@" 通过计步器获取估计当天距离(米)： %ld",(long)distance);
            [self logWithStr:[NSString stringWithFormat:@" 通过计步器获取估计当天距离(米)： %ld",(long)distance]];
            
            // 上楼
            NSInteger floorsAscended = [pedometerData.floorsAscended integerValue];
            NSLog(@" 通过计步器获取当天上楼： %ld",(long)floorsAscended);
            [self logWithStr:[NSString stringWithFormat:@" 通过计步器获取上楼： %ld",(long)floorsAscended]];
            
            // 下楼
            NSInteger floorsDescended = [pedometerData.floorsDescended integerValue];
            NSLog(@" 通过计步器获取当天下楼： %ld",(long)floorsDescended);
            [self logWithStr:[NSString stringWithFormat:@" 通过计步器获取下楼： %ld",(long)floorsDescended]];
            // 速度 s/m
            double currentPace = [pedometerData.currentPace doubleValue];
            NSLog(@" 通过计步器获取速度(秒/米)： %ld",(long)currentPace);
            [self logWithStr:[NSString stringWithFormat:@" 通过计步器获取速度(秒/米)： %ld",(long)currentPace]];
            // 频率(step/s)
            double currentCadence = [pedometerData.currentCadence doubleValue];
            NSLog(@" 通过计步器获取频率(步/秒)： %ld",(long)currentCadence);
            [self logWithStr:[NSString stringWithFormat:@" 通过计步器获取频率(步/秒)： %ld",(long)currentCadence]];
            // 记得去主线程更新UI
            dispatch_async(dispatch_get_main_queue(), ^{
            });
        }
    }];
}
- (void)pedometerStopUpdatesData {
    [self.pedometer stopPedometerUpdates];
}
- (void)pedometerUpdatesData {
    // 获取更新数据
    [self.pedometer startPedometerUpdatesFromDate:self.startDate withHandler:^(CMPedometerData * _Nullable pedometerData, NSError * _Nullable error) {
        // 处理同上
        // 停止更新运动数据
        // [self.pedometer stopPedometerUpdates];
        double stepCount = [pedometerData.numberOfSteps doubleValue];
        NSLog(@" 实时通过计步器获取步数： %ld",(long)stepCount);
        [self logWithStr:[NSString stringWithFormat:@" 实时通过计步器获取步数： %ld",(long)stepCount]];
        double distance = [pedometerData.distance doubleValue];
        NSLog(@" 实时通过计步器获取估计距离(米)： %f",distance);
        [self logWithStr:[NSString stringWithFormat:@" 实时通过计步器获取估计距离(米)： %f",distance]];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.cmStepLabel.text = [NSString stringWithFormat:@"%ld 步",(long)stepCount];
            self.cmDistanceLabel.text = [NSString stringWithFormat:@"%.2f 米",distance];
        });
        
        
    }];
    
//    // 计步器事件
//    [self.pedometer startPedometerEventUpdatesWithHandler:^(CMPedometerEvent * _Nullable pedometerEvent, NSError * _Nullable error) {
//        // 停止计步器事件更新
//        //[self.pedometer stopPedometerEventUpdates];
//        NSLog(@"更新时间：%@",pedometerEvent.date);
//        [self logWithStr:[NSString stringWithFormat:@"更新时间：%@",pedometerEvent.date]];
//    }];
}
- (void)logWithStr:(NSString *)str{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.logTextView.text = [NSString stringWithFormat:@"%@\n%@",self.logTextView.text,str];
    });
}
@end
