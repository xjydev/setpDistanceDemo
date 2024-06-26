//
//  WBHealthManager.m
//  StepDemo
//
//  Created by jingyuan5 on 2024/3/27.
//HKObserverQuery,HKAnchoredObjectQuery

#import "WBHealthManager.h"
#import <HealthKit/HealthKit.h>

@interface WBHealthManager()
@property (nonatomic, strong)HKHealthStore  *healthStore;
@property (nonatomic, strong) NSMutableArray *healthSteps;
@property (nonatomic, strong) NSMutableArray *healthCalories;
@property (nonatomic, strong) NSMutableArray *healthDistances;
@end

@implementation WBHealthManager
- (instancetype)init {
    self = [super init];
    if (self) {
        self.healthSteps = [NSMutableArray array];
        self.healthDistances = [NSMutableArray array];
        self.healthCalories = [NSMutableArray array];
    }
    return self;
}
-(void)updateData {
    if (![HKHealthStore isHealthDataAvailable]) {
        NSLog(@"---------不支持 HealthKit 框架");
        return;
    }
    HKQuantityType  *step = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    
    HKQuantityType *distance = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceWalkingRunning];
    
    NSSet *typesSet = [NSSet setWithObjects:step,distance, nil];

    [self.healthStore requestAuthorizationToShareTypes:nil readTypes:typesSet completion:^(BOOL success, NSError * _Nullable error) {
        if (!success) {
            NSLog(@"--------请求苹果健康认证失败%@",error);
            return ;
        }
        [self getHealthStepData];
        [self getHealthDistanceData];
    }];
}
- (HKHealthStore *)healthStore {
    if (!_healthStore) {
        _healthStore =  [[HKHealthStore alloc]init];
    }
    return _healthStore;
}
- (void)updateStep:(void (^)(float))handle{
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *now = [NSDate date];
    NSDateComponents *components = [calendar components:NSCalendarUnitHour|NSCalendarUnitMinute|kCFCalendarUnitSecond fromDate:now];
    NSDate *startDate = [calendar dateFromComponents:components];
    NSDate *endDate = [calendar dateByAddingUnit:NSCalendarUnitHour value:1 toDate:startDate options:0];
    
    HKQuantityType *sampleType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    NSPredicate *predicate = [HKQuery predicateForSamplesWithStartDate:startDate endDate:endDate options:HKQueryOptionStrictStartDate];
    
    HKStatisticsQuery *query = [[HKStatisticsQuery alloc] initWithQuantityType:sampleType quantitySamplePredicate:predicate options:HKStatisticsOptionCumulativeSum completionHandler:^(HKStatisticsQuery *query, HKStatistics *result, NSError *error) {
        //        if (!result) {
        //            if (completionHandler) {
        //                completionHandler(0.0f, error);
        //            }
        //            return;
        //        }
        
        double totalStep = [result.sumQuantity doubleValueForUnit:[HKUnit countUnit]];
        NSLog(@" ***************步数统计是：%f",totalStep);
        handle(totalStep);
    }];
    
    [self.healthStore executeQuery:query];
}

- (void)updateDistance:(void (^)(float))handle{
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *now = [NSDate date];
    NSDateComponents *components = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:now];
    NSDate *startDate = [calendar dateFromComponents:components];
    NSDate *endDate = [calendar dateByAddingUnit:NSCalendarUnitHour value:1 toDate:startDate options:0];
    
    HKQuantityType *sampleType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceWalkingRunning];
    NSPredicate *predicate = [HKQuery predicateForSamplesWithStartDate:startDate endDate:endDate options:HKQueryOptionStrictStartDate];
    
    HKStatisticsQuery *query = [[HKStatisticsQuery alloc] initWithQuantityType:sampleType quantitySamplePredicate:predicate options:HKStatisticsOptionCumulativeSum completionHandler:^(HKStatisticsQuery *query, HKStatistics *result, NSError *error) {
        //        if (!result) {
        //            if (completionHandler) {
        //                completionHandler(0.0f, error);
        //            }
        //            return;
        //        }
        
        double totalStep = [result.sumQuantity doubleValueForUnit:[HKUnit meterUnit]];
        NSLog(@" -------------距离统计是：%f",totalStep);
        handle(totalStep);
        
    }];
    
    [self.healthStore executeQuery:query];
}

- (void)updateEnergy:(NSMutableString *)str{
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *now = [NSDate date];
    NSDateComponents *components = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:now];
    NSDate *startDate = [calendar dateFromComponents:components];
    NSDate *endDate = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:startDate options:0];
    
    HKQuantityType *sampleType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierDietaryEnergyConsumed];
    NSPredicate *predicate = [HKQuery predicateForSamplesWithStartDate:startDate endDate:endDate options:HKQueryOptionStrictStartDate];
    
    HKStatisticsQuery *query = [[HKStatisticsQuery alloc] initWithQuantityType:sampleType quantitySamplePredicate:predicate options:HKStatisticsOptionCumulativeSum completionHandler:^(HKStatisticsQuery *query, HKStatistics *result, NSError *error) {
        //        if (!result) {
        //            if (completionHandler) {
        //                completionHandler(0.0f, error);
        //            }
        //            return;
        //        }
        
        double totalStep = [result.sumQuantity doubleValueForUnit:[HKUnit calorieUnit]];
        NSLog(@" -------------卡路里统计是：%f",totalStep);
        [str appendFormat:@"%f \n",totalStep];
    }];
    
    [self.healthStore executeQuery:query];
}

- (void)getHealthStepData{
    HKHealthStore *healthStore = [[HKHealthStore alloc]init];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    // 设置时间支持单位
    NSDateComponents *anchorComponents =
    [calendar components:NSCalendarUnitDay | NSCalendarUnitMonth |
     NSCalendarUnitYear | NSCalendarUnitWeekday fromDate:[NSDate date]];
    
    NSDate *anchorDate = [calendar dateFromComponents:anchorComponents];
    // 获取数据的截止时间 今天
    NSDate *endDate = [NSDate date];
    // 获取数据的起始时间 此处取从今日往前推100天的数据
    NSDate *startDate = [NSDate dateWithTimeIntervalSinceNow:-100*24*60*60];
    
    // 数据类型
    HKQuantityType *type = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    // Your interval: sum by hour
    NSDateComponents *intervalComponents = [[NSDateComponents alloc] init];
    intervalComponents.day = 1;
    // Example predicate 用于获取设置时间段内的数据
    NSPredicate *predicate = [HKQuery predicateForSamplesWithStartDate:startDate endDate:endDate options:HKQueryOptionStrictStartDate];
    
    HKStatisticsCollectionQuery *query = [[HKStatisticsCollectionQuery alloc] initWithQuantityType:type quantitySamplePredicate:predicate options:HKStatisticsOptionCumulativeSum anchorDate:anchorDate intervalComponents:intervalComponents];
    
    query.initialResultsHandler = ^(HKStatisticsCollectionQuery *query, HKStatisticsCollection *result, NSError *error) {
        
        for (HKStatistics *sample in [result statistics]) {
//            NSLog(@"--------------%@ 至 %@ : %@", sample.startDate, sample.endDate, sample.sumQuantity);
            NSDate *date = sample.endDate;
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"yyyy-MM-dd"];
            NSString *dateTime = [formatter stringFromDate:date];
            
            double totalStep = [sample.sumQuantity doubleValueForUnit:[HKUnit countUnit]];
            NSString *appleHealth = @"com.apple.Health";
            
            double editStep  = 0.0;
            for (HKSource *source in sample.sources) {
                if ([source.bundleIdentifier isEqualToString:appleHealth]) {
                    // 获取用户自己添加的数据 并减去，防止用户手动刷数据
                    HKSource *healthSource = source;
                    editStep  = [[sample sumQuantityForSource:healthSource] doubleValueForUnit:[HKUnit countUnit]];
                }
            }
            
            NSInteger step = (NSInteger)totalStep - (NSInteger)editStep;
            NSString *value = [NSString stringWithFormat:@"%ld",step];
            
            NSDictionary *dic = [NSDictionary dictionaryWithObjectsAndKeys:
                                 dateTime,@"dateTime",
                                 value,@"value",nil];
            [self.healthSteps addObject:dic];
//            NSLog(@"gaizaoDateStyle:%@  Dic = %@",self.healthSteps,dic);
        }
        self.healthCalories = self.healthSteps;
        
        NSDictionary *healthSteps = [NSDictionary dictionaryWithObjectsAndKeys:
                                     self.healthSteps,@"healthSteps",
                                     self.healthCalories,@"healthCalories",nil];
        NSLog(@"改造数据格式：%@",healthSteps);

    };
    
    [healthStore executeQuery:query];
}

- (void)getHealthDistanceData{
    HKHealthStore *healthStore = [[HKHealthStore alloc]init];
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *anchorComponents =
    [calendar components:NSCalendarUnitDay | NSCalendarUnitMonth |
     NSCalendarUnitYear | NSCalendarUnitWeekday fromDate:[NSDate date]];
    NSDate *anchorDate = [calendar dateFromComponents:anchorComponents];
    NSDate *endDate = [NSDate date];
    NSDate *startDate = [NSDate dateWithTimeIntervalSinceNow:-100*24*60*60];
    
    HKQuantityType *type = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceWalkingRunning];
    
    // Your interval: sum by hour
    NSDateComponents *intervalComponents = [[NSDateComponents alloc] init];
    intervalComponents.day = 1;
    
    // Example predicate
    NSPredicate *predicate = [HKQuery predicateForSamplesWithStartDate:startDate endDate:endDate options:HKQueryOptionStrictStartDate];
    
    HKStatisticsCollectionQuery *query = [[HKStatisticsCollectionQuery alloc] initWithQuantityType:type quantitySamplePredicate:predicate options:HKStatisticsOptionCumulativeSum anchorDate:anchorDate intervalComponents:intervalComponents];
    query.initialResultsHandler = ^(HKStatisticsCollectionQuery *query, HKStatisticsCollection *result, NSError *error) {
        for (HKStatistics *sample in [result statistics]) {
//            NSLog(@"+++++++++++++++%@ 至 %@ : %@", sample.startDate, sample.endDate, sample.sumQuantity);
            NSDate *date = sample.endDate;
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"yyyy-MM-dd"];
            NSString *dateTime = [formatter stringFromDate:date];
            
            double totalDistance = [sample.sumQuantity doubleValueForUnit:[HKUnit meterUnit]];
            
            NSString *appleHealth = @"com.apple.Health";
            //            double floor = [sample.sumQuantity doubleValueForUnit:[HKUnit yardUnit]];
            double editDistance  = 0.0;
            for (HKSource *source in sample.sources) {
                if ([source.bundleIdentifier isEqualToString:appleHealth]) {
                    // 获取用户自己添加的数据 并减去，防止用户手动刷数据
                    HKSource *healthSource = source;
                    editDistance = [[sample sumQuantityForSource:healthSource] doubleValueForUnit:[HKUnit meterUnit]];
                }
            }
            
            double distance = totalDistance/1000 - editDistance/1000;
            NSString *value = [NSString stringWithFormat:@"%f",distance];
            
            NSDictionary *dic = [NSDictionary dictionaryWithObjectsAndKeys:
                                 dateTime,@"dateTime",
                                 value,@"value",nil];
            [self.healthDistances addObject:dic];
        }
        
        NSLog(@"改造距离格式：%@",self.healthDistances);
    };
    
    [healthStore executeQuery:query];
}

@end
