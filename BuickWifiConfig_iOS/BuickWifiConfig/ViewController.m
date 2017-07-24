//
//  ViewController.m
//  BuickWifiConfig
//
//  Created by yangxinlei on 2017/4/25.
//  Copyright © 2017年 qunar. All rights reserved.
//

#import "ViewController.h"
#import "UIView+YYAdd.h"
#import "Helper.h"
#import "BabyBluetooth.h"
#import "YYKitMacro.h"
#import "PeripheralInfo.h"
@import CoreBluetooth;

// UI
#define kFontSize           20.0f
#define kHorizontalMargin   30.0f
#define kHorizontalGap      30.0f
#define kTopMargin          100.0f
#define kVerticalGap        50.0f
#define kPickerViewHeight   300.0f
#define kScreenHeight       [UIScreen mainScreen].bounds.size.height
#define kScreenWidth        [UIScreen mainScreen].bounds.size.width
#define kDefaultFont        [UIFont systemFontOfSize:kFontSize]

// wifi & bluetooth
#define kDefaultWifiPasswd          @"12345678"
#define kTargetPeripheralName       @"raspberrypi"
#define channelA                    @"channelA"
#define channelB                    @"channelB"

// logger stuff
#define formateStr(str, ...)        [NSString stringWithFormat:str, ##__VA_ARGS__]
#define addFLog(str, ...)           [self addLog:formateStr(str, ##__VA_ARGS__)];

@interface ViewController () <UIPickerViewDelegate, UIPickerViewDataSource>

// UI
@property (nonatomic, strong) UILabel *chooseWifiLabel;
@property (nonatomic, strong) UILabel *passwdLabel;
@property (nonatomic, strong) UITextField *chooseWifiTextField;
@property (nonatomic, strong) UITextField *passwdTextField;
@property (nonatomic, strong) UIButton *submitButton;
@property (nonatomic, strong) UIPickerView *wifiPickerView;
@property (nonatomic, strong) UITextView *debuggerView;

// bluetooth
@property (nonatomic, strong) BabyBluetooth *baby;
@property (nonatomic, strong) NSMutableSet *discoverdPeripherals;
@property (nonatomic, strong) PeripheralInfo *peripheralInfo;

@end

@implementation ViewController

#pragma mark - lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.view setBackgroundColor:[UIColor whiteColor]];
    
    // 初始化UI
    [self setupView:self.view];
}

#pragma mark - UI

- (void)setupView:(UIView *)parrentView
{
    [parrentView addSubview:self.chooseWifiLabel];
    [parrentView addSubview:self.passwdLabel];
    [parrentView addSubview:self.chooseWifiTextField];
    [parrentView addSubview:self.passwdTextField];
    [parrentView addSubview:self.submitButton];
}

#pragma mark - delegate & data source

#pragma mark UIPickerViewDelegate
- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    return @"abc";
}
- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    [self.chooseWifiTextField setText:@"abc"];
    [pickerView removeFromSuperview];
}

#pragma mark UIPickerViewDataSource
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return 1;
}

#pragma mark BabyBluetooth blocks
- (void)setupBabyDelegates:(BabyBluetooth *)baby
{
    @weakify(self)
    [baby setBlockOnCentralManagerDidUpdateState:^(CBCentralManager *central) {
        if (central.state == CBCentralManagerStatePoweredOn) {
            @strongify(self)
            [self addLog:@"设备打开成功，开始扫描设备"];
        }
    }];
    
    //设置扫描到设备的委托
    [baby setBlockOnDiscoverToPeripherals:^(CBCentralManager *central, CBPeripheral *peripheral, NSDictionary *advertisementData, NSNumber *RSSI) {
        @strongify(self)
        if (! [self.discoverdPeripherals containsObject:peripheral])
        {
            [self.discoverdPeripherals addObject:peripheral];
            
            if ([peripheral.name isEqualToString:kTargetPeripheralName])
            {
                addFLog(@"找到设备:%@", peripheral.name);
                [self.baby cancelScan];
                addFLog(@"开始连接设备");
                [self startServicesDiscover:self.baby withPeripheral:peripheral];
                
            }
            else
            {
                addFLog(@"发现设备:%@", peripheral.name);
            }
        }
    }];
    
    //设置查找设备的过滤器
    [baby setFilterOnDiscoverPeripherals:^BOOL(NSString *peripheralName, NSDictionary *advertisementData, NSNumber *RSSI) {
        
        //最常用的场景是查找某一个前缀开头的设备
        //        if ([peripheralName hasPrefix:@"Pxxxx"] ) {
        //            return YES;
        //        }
        //        return NO;
        
        //设置查找规则是名称大于0 ， the search rule is peripheral.name length > 0
        if (peripheralName.length >0) {
            return YES;
        }
        return NO;
    }];
    
    
    [baby setBlockOnCancelAllPeripheralsConnectionBlock:^(CBCentralManager *centralManager) {
        @strongify(self)
        addFLog(@"setBlockOnCancelAllPeripheralsConnectionBlock");
    }];
    
    [baby setBlockOnCancelScanBlock:^(CBCentralManager *centralManager) {
        @strongify(self)
        addFLog(@"停止扫描");
    }];
    
    //扫描选项->CBCentralManagerScanOptionAllowDuplicatesKey:忽略同一个Peripheral端的多个发现事件被聚合成一个发现事件
    NSDictionary *scanForPeripheralsWithOptions = @{CBCentralManagerScanOptionAllowDuplicatesKey:@YES};
    //连接设备->
    [baby setBabyOptionsWithScanForPeripheralsWithOptions:scanForPeripheralsWithOptions connectPeripheralWithOptions:nil scanForPeripheralsWithServices:nil discoverWithServices:nil discoverWithCharacteristics:nil];
}

- (void)setupBabyDelegatesForServiceDiscover:(BabyBluetooth *)baby
{
    @weakify(self)
    @weakify(baby)
    
    BabyRhythm *rhythm = [[BabyRhythm alloc]init];
    
    //设置设备连接成功的委托,同一个baby对象，使用不同的channel切换委托回调
    [baby setBlockOnConnectedAtChannel:channelA block:^(CBCentralManager *central, CBPeripheral *peripheral) {
        @strongify(self)
        addFLog(@"设备：%@--连接成功",peripheral.name);
    }];
    
    //设置设备连接失败的委托
    [self.baby setBlockOnFailToConnectAtChannel:channelA block:^(CBCentralManager *central, CBPeripheral *peripheral, NSError *error) {
        @strongify(self)
        addFLog(@"设备：%@--连接失败",peripheral.name);
    }];
    
    //设置设备断开连接的委托
    [self.baby setBlockOnDisconnectAtChannel:channelA block:^(CBCentralManager *central, CBPeripheral *peripheral, NSError *error) {
        @strongify(self)
        addFLog(@"设备：%@--断开连接",peripheral.name);
    }];
    
    //设置发现设备的Services的委托
    [self.baby setBlockOnDiscoverServicesAtChannel:channelA block:^(CBPeripheral *peripheral, NSError *error) {
        for (CBService *s in peripheral.services) {
            @strongify(self)
            addFLog(@"发现CBService: %@",s);
            self.peripheralInfo = [PeripheralInfo new];
            [self.peripheralInfo setServiceUUID:s.UUID];
        }
        
        [rhythm beats];
    }];
    
    //设置发现设service的Characteristics的委托
    [baby setBlockOnDiscoverCharacteristicsAtChannel:channelA block:^(CBPeripheral *peripheral, CBService *service, NSError *error) {
        @strongify(self)
        addFLog(@"===service uuid:%@",service.UUID);
        if (self.peripheralInfo.serviceUUID == service.UUID)
        {
            for (int row=0; row < service.characteristics.count; row++)
            {
                CBCharacteristic *c = service.characteristics[row];
                [self.peripheralInfo.characteristics addObject:c];
            }
            
            CBCharacteristic *characteristic = self.peripheralInfo.characteristics[0];
            @strongify(baby)
            [baby notify:peripheral
          characteristic:characteristic
                   block:^(CBPeripheral *peripheral, CBCharacteristic *characteristics, NSError *error) {
                       NSLog(@"notify block");
                       NSLog(@"new value %@",characteristics.value);
                       NSString *valueStr = [[NSString alloc] initWithData:characteristics.value encoding:NSUTF8StringEncoding];
                       NSLog(@"🚩xxx---\n%@\n---xxx🦋", valueStr);
                       
                       [self addLog:@"got notify"];
                       [self addLog:valueStr];
                       
                   }];
        
            addFLog(@"curInfo.characteristics: %@", self.peripheralInfo.characteristics);
            
            NSString *wifiName = self.chooseWifiTextField.text;
            NSString *wifiPass = self.passwdTextField.text;
            
            NSDictionary *wifiInfo = @{@"name": wifiName, @"passwd":wifiPass};
            NSData *data = [NSJSONSerialization dataWithJSONObject:wifiInfo options:0 error:nil];
            [peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
            
            addFLog(@"wifi信息已发送");
        }
    }];
    //设置读取characteristics的委托
    [baby setBlockOnReadValueForCharacteristicAtChannel:channelA block:^(CBPeripheral *peripheral, CBCharacteristic *characteristics, NSError *error) {
        @strongify(self)
        addFLog(@"characteristic name:%@ value is:%@",characteristics.UUID,characteristics.value);
    }];
    //设置发现characteristics的descriptors的委托
    [baby setBlockOnDiscoverDescriptorsForCharacteristicAtChannel:channelA block:^(CBPeripheral *peripheral, CBCharacteristic *characteristic, NSError *error) {
        @strongify(self)
        addFLog(@"===characteristic name:%@",characteristic.service.UUID);
        for (CBDescriptor *d in characteristic.descriptors) {
            addFLog(@"CBDescriptor name is :%@",d.UUID);
        }
    }];
    //设置读取Descriptor的委托
    [baby setBlockOnReadValueForDescriptorsAtChannel:channelA block:^(CBPeripheral *peripheral, CBDescriptor *descriptor, NSError *error) {
        @strongify(self)
        addFLog(@"Descriptor name:%@ value is:%@",descriptor.characteristic.UUID, descriptor.value);
    }];
    
    //读取rssi的委托
    [baby setBlockOnDidReadRSSI:^(NSNumber *RSSI, NSError *error) {
        @strongify(self)
        addFLog(@"setBlockOnDidReadRSSI:RSSI:%@",RSSI);
    }];
    
    
    //设置写数据成功的block
    [baby setBlockOnDidWriteValueForCharacteristicAtChannel:channelA block:^(CBCharacteristic *characteristic, NSError *error) {
        @strongify(self)
        addFLog(@"setBlockOnDidWriteValueForCharacteristicAtChannel characteristic:%@ and new value:%@",characteristic.UUID, characteristic.value);
    }];
    
    //设置通知状态改变的block
    [baby setBlockOnDidUpdateNotificationStateForCharacteristicAtChannel:channelA block:^(CBCharacteristic *characteristic, NSError *error) {
        @strongify(self)
        addFLog(@"uid:%@,isNotifying:%@",characteristic.UUID,characteristic.isNotifying?@"on":@"off");
    }];
    
    //设置beats break委托
    [rhythm setBlockOnBeatsBreak:^(BabyRhythm *bry) {
        @strongify(self)
        addFLog(@"setBlockOnBeatsBreak call");
        
        //如果完成任务，即可停止beat,返回bry可以省去使用weak rhythm的麻烦
        //        if (<#condition#>) {
        //            [bry beatsOver];
        //        }
        
    }];
    
    //设置beats over委托
    [rhythm setBlockOnBeatsOver:^(BabyRhythm *bry) {
        @strongify(self)
        addFLog(@"setBlockOnBeatsOver call");
    }];
    
    //扫描选项->CBCentralManagerScanOptionAllowDuplicatesKey:忽略同一个Peripheral端的多个发现事件被聚合成一个发现事件
    NSDictionary *scanForPeripheralsWithOptions = @{CBCentralManagerScanOptionAllowDuplicatesKey:@YES};
    /*连接选项->
     CBConnectPeripheralOptionNotifyOnConnectionKey :当应用挂起时，如果有一个连接成功时，如果我们想要系统为指定的peripheral显示一个提示时，就使用这个key值。
     CBConnectPeripheralOptionNotifyOnDisconnectionKey :当应用挂起时，如果连接断开时，如果我们想要系统为指定的peripheral显示一个断开连接的提示时，就使用这个key值。
     CBConnectPeripheralOptionNotifyOnNotificationKey:
     当应用挂起时，使用该key值表示只要接收到给定peripheral端的通知就显示一个提
     */
    NSDictionary *connectOptions = @{CBConnectPeripheralOptionNotifyOnConnectionKey:@YES,
                                     CBConnectPeripheralOptionNotifyOnDisconnectionKey:@YES,
                                     CBConnectPeripheralOptionNotifyOnNotificationKey:@YES};
    
    [baby setBabyOptionsAtChannel:channelA scanForPeripheralsWithOptions:scanForPeripheralsWithOptions connectPeripheralWithOptions:connectOptions scanForPeripheralsWithServices:nil discoverWithServices:nil discoverWithCharacteristics:nil];
    

}

#pragma mark - actions

- (void)chooseWifi:(UITextField *)sender
{
}

- (void)submit:(UIButton *)sender
{
    NSString *wifiName = self.chooseWifiTextField.text;
    if (wifiName == nil || wifiName.length == 0)
    {
        [self.chooseWifiTextField setTintColor:[UIColor redColor]];
        [self.chooseWifiTextField becomeFirstResponder];
        return ;
    }
    
    NSString *wifiPasswd = self.passwdTextField.text;
    if (wifiPasswd == nil || wifiPasswd.length == 0)
    {
        [self.passwdTextField setTintColor:[UIColor redColor]];
        [self.passwdTextField becomeFirstResponder];
        return ;
    }
    
    [self.chooseWifiTextField resignFirstResponder];
    [self.passwdTextField resignFirstResponder];
    [self.chooseWifiTextField setTintColor:[UIColor cyanColor]];
    [self.passwdTextField setTintColor:[UIColor cyanColor]];
    
    [self.view addSubview:self.debuggerView];
    
    // send by bluetooth
    addFLog(@"启动蓝牙");
    [self setupBabyDelegates:self.baby];
    
    //停止之前的连接
    [self.baby cancelAllPeripheralsConnection];
    //设置委托后直接可以使用，无需等待CBCentralManagerStatePoweredOn状态。
    self.baby.scanForPeripherals().begin();
    
}

- (void)startServicesDiscover:(BabyBluetooth *)baby withPeripheral:(CBPeripheral *)peripheral
{
    [self setupBabyDelegatesForServiceDiscover:baby];
    
    baby.having(peripheral).and.channel(channelA).then.connectToPeripherals().discoverServices().discoverCharacteristics().readValueForCharacteristic().discoverDescriptorsForCharacteristic().readValueForDescriptors().begin();
}

#pragma mark - getters & setters

// UI
- (UILabel *)chooseWifiLabel
{
    if (_chooseWifiLabel == nil)
    {
        _chooseWifiLabel = [[UILabel alloc] initWithFrame:CGRectMake(kHorizontalMargin, kTopMargin, 0, 0)];
        [_chooseWifiLabel setText:@"wifi名称"];
        [_chooseWifiLabel setFont:[UIFont systemFontOfSize:kFontSize]];
        [_chooseWifiLabel sizeToFit];
    }
    
    return _chooseWifiLabel;
}

- (UILabel *)passwdLabel
{
    if (_passwdLabel == nil)
    {
        _passwdLabel = [[UILabel alloc] initWithFrame:CGRectMake(kHorizontalMargin, kTopMargin + kVerticalGap, 0, 0)];
        [_passwdLabel setText:@"wifi密码"];
        [_passwdLabel setFont:kDefaultFont];
        [_passwdLabel sizeToFit];
    }
    
    return _passwdLabel;
}

- (UITextField *)chooseWifiTextField
{
    if (! _chooseWifiTextField)
    {
        CGFloat xStart = self.chooseWifiLabel.right + kHorizontalGap;
        CGFloat xEnd = kScreenWidth - kHorizontalGap;
        _chooseWifiTextField = [[UITextField alloc] initWithFrame:CGRectMake(xStart, self.chooseWifiLabel.top, xEnd - xStart, self.chooseWifiLabel.height)];
        [_chooseWifiTextField setFont:kDefaultFont];
        [_chooseWifiTextField setBorderStyle:UITextBorderStyleRoundedRect];
        [_chooseWifiTextField setTintColor:[UIColor blueColor]];
        
        NSString *curWifiName = [Helper getWifiName];
        [_chooseWifiTextField setText:curWifiName];
        [_chooseWifiTextField setClearButtonMode:UITextFieldViewModeWhileEditing];
        
        [_chooseWifiTextField addTarget:self action:@selector(chooseWifi:) forControlEvents:UIControlEventTouchDown];
    }
    return _chooseWifiTextField;
}

- (UITextField *)passwdTextField
{
    if (! _passwdTextField)
    {
        CGFloat xStart = self.passwdLabel.right + kHorizontalGap;
        CGFloat xEnd = kScreenWidth - kHorizontalGap;
        _passwdTextField = [[UITextField alloc] initWithFrame:CGRectMake(xStart, self.passwdLabel.top, xEnd - xStart, self.passwdLabel.height)];
        [_passwdTextField setFont:kDefaultFont];
        [_passwdTextField setBorderStyle:UITextBorderStyleRoundedRect];
        [_passwdTextField setTintColor:[UIColor blueColor]];
        [_passwdTextField setKeyboardType:UIKeyboardTypeNumberPad];
        
        [_passwdTextField setText:kDefaultWifiPasswd];
        [_passwdTextField setClearButtonMode:UITextFieldViewModeWhileEditing];
    }
    return _passwdTextField;
}

- (UIButton *)submitButton
{
    if (! _submitButton)
    {
        _submitButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [_submitButton setTitle:@"确定" forState:UIControlStateNormal];
        [[_submitButton titleLabel] setFont:kDefaultFont];
        [_submitButton sizeToFit];
        
        [_submitButton setLeft: (kScreenWidth - _submitButton.width) / 2];
        [_submitButton setTop: self.passwdLabel.bottom + kVerticalGap];
        
        [_submitButton addTarget:self action:@selector(submit:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _submitButton;
}

- (UIPickerView *)wifiPickerView
{
    if (! _wifiPickerView)
    {
        _wifiPickerView = [[UIPickerView alloc] initWithFrame:CGRectMake(0.0, kScreenHeight - kPickerViewHeight, kScreenWidth, kPickerViewHeight)];
        [_wifiPickerView setBackgroundColor:[UIColor lightGrayColor]];
        [_wifiPickerView setDelegate:self];
        [_wifiPickerView setDataSource:self];
    }
    
    return _wifiPickerView;
}

- (UITextView *)debuggerView
{
    if (! _debuggerView)
    {
        _debuggerView = [[UITextView alloc] initWithFrame:CGRectMake(0.0, kScreenHeight - kPickerViewHeight - 100.0, kScreenWidth, kPickerViewHeight)];
        [_debuggerView setBackgroundColor:[UIColor colorWithRed:0.92 green:0.92 blue:0.92 alpha:1.0]];
    }
    
    return _debuggerView;
}

- (BabyBluetooth *)baby
{
    if (! _baby)
    {
        _baby = [BabyBluetooth shareBabyBluetooth];
    }
    
    return _baby;
}

- (NSMutableSet *)discoverdPeripherals
{
    if (! _discoverdPeripherals)
    {
        _discoverdPeripherals = [NSMutableSet setWithCapacity:10];
    }
    return _discoverdPeripherals;
}

#pragma mark - private helper methods

- (void)addLog:(NSString *)log
{
    [self.debuggerView setText:[NSString stringWithFormat:@"%@%@\n", self.debuggerView.text, log]];
    
    // scroll to end
    NSRange tailRange = NSMakeRange(self.debuggerView.text.length - 1, 1);
    [self.debuggerView scrollRangeToVisible:tailRange];
}

@end
