//
//  ViewController.m
//  PengStubOSX
//
//  Created by hengfu on 16/7/20.
//  Copyright © 2016年 hengfu. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@property (weak) IBOutlet NSImageView *pImageView;

@property (nonatomic,strong) NSMutableData *pData;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.pData = [[NSMutableData alloc] init];

    // Do any additional setup after loading the view.
    //设置waish
    self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
    
    //初始化数据
    self.dataToSend = [@"snadjfkhaw加大困难的是咖啡euijferlfmn ksxncjxznvjeajfrnjadnfjasfndsafnjsadkfnjsa" dataUsingEncoding:NSUTF8StringEncoding];
}

#pragma mark
- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    switch (peripheral.state) {
        case CBPeripheralManagerStatePoweredOn:
            {
                NSLog(@"power on");
                [self setupService];
            }
            
            break;
        case CBPeripheralManagerStatePoweredOff:
            {
                NSLog(@"power Off");
            }
            
            break;
        default:
            break;
    }

}

- (void)setupService
{
    CBUUID *characteristicUUID = [CBUUID UUIDWithString:@"FFF2"];
    
    //Create the characteristic
    self.customCharacteristic = [[CBMutableCharacteristic alloc] initWithType:characteristicUUID properties:CBCharacteristicPropertyNotify | CBCharacteristicPropertyRead | CBCharacteristicPropertyWrite value:nil permissions:CBAttributePermissionsReadable | CBAttributePermissionsWriteable];
    //create the service uuid
    CBUUID *servieceUUID = [CBUUID UUIDWithString:@"FFF3"];
    //create the serviece and adds charecteristic to it
    self.customService = [[CBMutableService alloc] initWithType:servieceUUID primary:YES];
    [self.customService setCharacteristics:@[self.customCharacteristic]];
    //And  add it to the peripheral manager
    [self.peripheralManager addService:self.customService];
    
}

//当执行addService方法后执行如下回调
- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error
{
    if (error) {
        NSLog(@"%s,erro = %@",__PRETTY_FUNCTION__,error.localizedDescription);
    }else{
        [self.peripheralManager startAdvertising:@{CBAdvertisementDataLocalNameKey:@"Pengdada",CBAdvertisementDataServiceUUIDsKey:@[[CBUUID UUIDWithString:@"FFF3"]]}];
    }
    

}

//cetral订阅了charateristic值，当更新值得时候peripheral会调用
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    self.central = central;
    //NSUUID		*_identifier;
    if (_lastDeviceUUID == central.identifier) {
        return;
    }
    _lastDeviceUUID = central.identifier;
    self.sendDataIndex = 0;
    [self sendData];

}

#pragma mark -向客户端发消息，订阅只能发送20个字节
- (void)sendData
{
    //标记是否为最后的一次发送
    static BOOL sendingEOM = NO;
    if (sendingEOM) {
        //只发送“EOM”表示结束
        BOOL didsend = [self.peripheralManager updateValue:[@"EOM" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:self.customCharacteristic onSubscribedCentrals:@[self.central]];
        //1、1最后一次发送成功
        if (didsend) {
            sendingEOM = NO;
            NSLog(@"Sent:EOM");
        }
        return;
    }
    //2、不是最后一次发送，且数据为空，则返回
    if (self.sendDataIndex >= self.dataToSend.length) {
        return;
    }
    //3、数据尚未发送完成，继续发送直到完成
    BOOL didSend = YES;
    while (didSend) {
        //3.1计算剩余多大数据量需要发送
        NSInteger amountTosend = self.dataToSend.length - self.sendDataIndex;
        //不能大于20个字节
        if (amountTosend > 20) {
            amountTosend = 20;
            //3.2 copy出我们想要发送的数据
            NSData *chunk = [NSData dataWithBytes:self.dataToSend.bytes + self.sendDataIndex length:20];
            //3.3发送
            didSend = [self.peripheralManager updateValue:chunk forCharacteristic:self.customCharacteristic onSubscribedCentrals:@[self.central]];
            //3.4如果没有发送成功，重新发送
            if (!didSend) {
                NSLog(@"SEND ERROR");
                return;
            }
            NSString *stringFromData = [[NSString alloc] initWithData:chunk encoding:NSUTF8StringEncoding];
            NSLog(@"Sent: %@ ",stringFromData);
            //3.5 发送成功，修改已经发送成功数据index值
            self.sendDataIndex += self.dataToSend.length;
            //3.6如果是最后一次需要发送
            if (self.sendDataIndex >= self.dataToSend.length) {
                //3.6.1 把标识是否为最后一次发送改为yes
                sendingEOM = YES;
                //3.6.2 发送
                BOOL eomSent = [self.peripheralManager updateValue:[@"EOM" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:self.customCharacteristic onSubscribedCentrals:@[self.central]];
                if (eomSent) {
                    //3.6.3 发送成功，则我们已经完成这个功能
                    sendingEOM = NO;
                    NSLog(@"Send:EOM");
                }
                return;
            }
        }
    }

}

//peripheral再次准备好发送Characteristic值的更新时候调用
- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral
{
    NSLog(@"peripheral再次准备好发送Characteristic值的更新时候调用");
    [self sendData];

}

//当central取消订阅Characteristic这个特征的值后调用方法
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic
{
   NSLog(@"central=%@设备拒绝请求,%s,",central,__PRETTY_FUNCTION__);

}

//读characteristics请求
- (void) peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request
{
    if (request.characteristic.properties & CBCharacteristicPropertyRead) {
        NSData *data = request.characteristic.value;
//        Byte spaceBytes1[] = {0x1B, 0x24, 150 % 256, 0};
//        NSData *data = [NSData dataWithBytes:spaceBytes1 length:sizeof(spaceBytes1)];
//        [request setValue:data];
        NSLog(@"data:%@",data);

        if (data && data.length < 20 ) {
            NSLog(@"data.length < 20");
//            NSDateFormatter *formt = [NSDateFormatter new];
//            formt.dateFormat = @"ss";
//            data = [[formt stringFromDate:[NSDate new]] dataUsingEncoding:NSUTF8StringEncoding];
//            NSLog(@"[formt stringFromDate:[NSDate new]]:%@",[formt stringFromDate:[NSDate new]]);
            
//            Byte *testByte = (Byte *)[data bytes];
//            
//            int b = 10 - testByte[0];
//            Byte spaceBytes[] = {b};
//            data = [NSData dataWithBytes:spaceBytes length:sizeof(spaceBytes)];
            [request setValue:data];
        }else{
            NSLog(@"data.length > 20 or data.length = 0");
            if (data) {
//                data = [@"谢谢惠顾，欢迎下次光临!谢谢惠顾，欢迎下次光临!谢谢惠顾，欢迎下次光临!谢谢惠顾，欢迎下次光临!谢谢惠顾，欢迎下次光临!谢谢惠顾，欢迎下次光临!谢谢惠顾，欢迎下次光临!谢谢惠顾，欢迎下次光临!谢谢惠顾，欢迎下次光临!谢谢惠顾，欢迎下次光临!谢谢惠顾，欢迎下次光临!谢谢惠顾，欢迎下次光临!谢谢惠顾，欢迎下次光临!谢谢惠顾，欢迎下次光临!谢谢惠顾，欢迎下次光临!" dataUsingEncoding:NSUTF8StringEncoding];
                [request setValue:data];
            }
        
        }

        //对请求作出成功响应
        [peripheral respondToRequest:request withResult:CBATTErrorSuccess];
    }else{
        //错误的响应
        [peripheral respondToRequest:request withResult:CBATTErrorWriteNotPermitted];
    }

}

//写characteristics请求
-(void) peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray<CBATTRequest *> *)requests
{
    NSLog(@"didReceiveWriteRequests");
    CBATTRequest *request = requests[0];
    //判断是否有写数据的权限
    if (request.characteristic.properties & CBCharacteristicPropertyWrite) {
        //需要转换成CBMutableCharacteristic对象才能进行写值
        CBMutableCharacteristic *c =(CBMutableCharacteristic *)request.characteristic;
        c.value = request.value;
        NSLog(@"c.value:%@",c.value);
        if (c.value) {
            [self reseiveImageData:c.value];
        }
//        NSData *data = [@"谢谢惠顾，欢迎下次光临!谢谢惠顾，欢迎下次光临!谢谢惠顾，欢迎下次光临!谢谢惠顾，欢迎下次光临!谢谢惠顾，欢迎下次光临!谢谢惠顾，欢迎下次光临!谢谢惠顾，欢迎下次光临!谢谢惠顾，欢迎下次光临!谢谢惠顾，欢迎下次光临!谢谢惠顾，欢迎下次光临!谢谢惠顾，欢迎下次光临!谢谢惠顾，欢迎下次光临!谢谢惠顾，欢迎下次光临!谢谢惠顾，欢迎下次光临!谢谢惠顾，欢迎下次光临!" dataUsingEncoding:NSUTF8StringEncoding];
//        [request setValue:data];
        [peripheral respondToRequest:request withResult:CBATTErrorSuccess];
    }else{
        [peripheral respondToRequest:request withResult:CBATTErrorWriteNotPermitted];
    }

}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

- (void)reseiveImageData:(NSData *)data
{
    //前面包长度
    int page = 3;
    //1、1截取前面3个字节进行判断，是开始还是中间
    NSString *rangStr = [NSString stringWithFormat:@"%i,%i",0,page];
    NSString *mrangStr = [NSString stringWithFormat:@"%i,%i",page,(int)([data length] - page)];
    NSData *sData = [data subdataWithRange:NSRangeFromString(rangStr)];
    NSData *mData = [data subdataWithRange:NSRangeFromString(mrangStr)];
    NSLog(@"sData%@",sData);
    Byte *sByte = (Byte *)[sData bytes];
    int a = sByte[0];
    int b = sByte[1];
    int c = sByte[2];
    if (a == b && b == c) {
        switch (b) {
            case 1:
            {
                //1、如果是第一个数据，将之前的数据清除
                self.pData  = [[NSMutableData alloc] init];
                [self.pData appendData:mData];
                
                
            }
                break;
            case 2:
            {
                //2、如果是中间的数据，直接添加
                [self.pData appendData:mData];
                
            }
                break;
            case 3:
            {
                //3、如果是最后的数据，添加后显示图片
                [self.pData appendData:mData];
                [self setBleImage:self.pData];
                
            }
                break;
                
            default:
                NSLog(@"other");
                break;
        }
        
    }else
    {
        NSLog(@"异常数据");
    
    }
   
    


}

- (IBAction)resetImage:(id)sender {
    NSLog(@"修复图片");
    [self.pImageView setImage:[NSImage imageNamed:@"LOGO_login"]];
    
}

- (void)setBleImage:(NSData *)data
{
    NSLog(@"设置蓝牙发过来的图片");
    [self.pImageView setImage:[[NSImage alloc] initWithData:data]];


}
@end


