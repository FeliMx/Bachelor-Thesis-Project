//
//  EPeripheral.swift
//  BLE_Demo
//
//  Created by Konstruktion on 01.08.18.
//  Copyright © 2018 EMKA Beschlagteile. All rights reserved.
//

import UIKit
import CoreBluetooth

@objc class EPeripheral: NSObject {
    
    var peripheral  : CBPeripheral
    var RSSI        : Int32
    var isConnected : Bool
    
    init(withPeripheral aPeripheral: CBPeripheral, andRSSI anRSSI: Int32 = 0, andIsConnected aConnectionStatus: Bool) {
        peripheral = aPeripheral
        RSSI = anRSSI
        isConnected = aConnectionStatus
    }
    
    func name() -> String {
        let peripheralName = peripheral.name
        if peripheral.name == nil {
            return "No name"
        } else {
            return peripheralName!
        }
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        if let otherPeripheral = object as? EPeripheral {
            return peripheral == otherPeripheral.peripheral
        }
        return false
    }
}
