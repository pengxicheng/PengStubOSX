//
//  ViewController.h
//  PengStubOSX
//
//  Created by hengfu on 16/7/20.
//  Copyright © 2016年 hengfu. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreBluetooth/CoreBluetooth.h>
@interface ViewController : NSViewController<CBPeripheralManagerDelegate>

//周边管理者
@property (nonatomic,strong) CBPeripheralManager *peripheralManager;

//中心
@property (nonatomic,strong)CBCentral  *central;

//特征
@property (nonatomic,strong)CBMutableCharacteristic *customCharacteristic;

//服务
@property(nonatomic,strong) CBMutableService *customService;

//向中心发送的数据
@property (strong,nonatomic)NSData *dataToSend;

@property (nonatomic,readwrite) NSInteger sendDataIndex;


//NSUUID
@property(nonatomic,strong)NSUUID *lastDeviceUUID;
@end

