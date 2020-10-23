//
//  BluetoothManager.swift
//  BLE_Demo
//
//  Created by Konstruktion on 01.08.18.
//  Copyright © 2018 EMKA Beschlagteile. All rights reserved.
//

import UIKit
import CoreBluetooth

fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs){
    case let (l?, r?):
        return l > r
    default:
        return rhs < lhs
    }
}

protocol BluetoothManagerDelegate {
    func didConnectPeripheral(deviceName aName : String?)
    func didDisconnectPeripheral()
    func perioheralReady()
    func peripheralNotSupported()
    func showAlert(withTitle aTitle: String, andText aText: String)
}

class BluetoothManager: NSObject, CBPeripheralDelegate, CBCentralManagerDelegate {
    
    //MARK: - Delegate Properties
    var delegate    : BluetoothManagerDelegate?
    var lockStatus  : Bool?
    //var logger      : ELogger?
    
    //MARK: - Class Properties
    fileprivate let MTU = 20
    fileprivate let UARTServiceUUID             : CBUUID
    fileprivate let UARTRXCharacteristicUUID    : CBUUID
    fileprivate let UARTTXCharacteristicUUID    : CBUUID
    
    fileprivate var centralManager              : CBCentralManager
    fileprivate var bluetoothPeripheral         : CBPeripheral?
    fileprivate var uartRXCharacteristic        : CBCharacteristic?
    fileprivate var uartTXCharacteristic        : CBCharacteristic?
    
    fileprivate var connected = false
    
    //MARK: - BluetoothManager API
    
    required init(withManager aManager : CBCentralManager) {
        centralManager = aManager
        UARTServiceUUID             = CBUUID(string: EServiceIdentifiers.uartServiceUUIDString)
        UARTRXCharacteristicUUID    = CBUUID(string: EServiceIdentifiers.uartRXCharacteristicUUIDString)
        UARTTXCharacteristicUUID    = CBUUID(string: EServiceIdentifiers.uartTXCharacteristicUUIDString)
        super.init()
        
        centralManager.delegate = self
    }
    
    /**
     * Connects to the given peripheral.
     *
     * - parameter aPeripheral: target peripheral to connect ti
     */
    func connectPeripheral(peripheral aPeripheral : CBPeripheral) {
        bluetoothPeripheral = aPeripheral
        
        // we assign the bluetoothPeripheral property after we establish a connection, in the callback
        if let name = aPeripheral.name {
            print("Connecting to: \(name)...")
        } else{
            print("Connecting to device...")
        }
        print("centralManager.connect(peripheral, options:nil)")
        centralManager.connect(aPeripheral, options: nil)
        
    }
    
    /**
     * Disconnects or cancels pending connection.
     * The delegate's didDisconnectPeripheral() method will be called when device get disconnected.
     */
    func cancelPeripheralConnection() {
        guard bluetoothPeripheral != nil else {
            delegate?.showAlert(withTitle: "ERROR", andText: "Peripheral not set")
            print("Peripheral not set") //ALERT!!
            return
        }
        if connected {
            print("Disconnecting...")
        } else {
            print("Cancelling connection...")
        }
        print("centralManager.cancelPeripheralConnection(peripheral")
        centralManager.cancelPeripheralConnection(bluetoothPeripheral!)
        
        // In case the previous connection attempt failed before establiching a connection
        if !connected {
            bluetoothPeripheral = nil
            delegate?.didDisconnectPeripheral()
        }
    }
    
    /**
     * Returns true if the peripheral device is connected, false otherwise
     * - Returns: true if device is connected
     */
    func isConnected() -> Bool {
        return connected
    }
    
    /**
     * This method sends the given test to the UART RX characteristic.
     * Depending on whether the characteristic has the Write Without Response or Write properties the behaviour is different.
     * In the latter case the Long Write ma be used. To enable it you have to change the flag below in the code.
     * Otherwise, in both cases, texts longer than 20 (MTU) bytes (not charaters) will be splitted into uo-to 20-byte packets.
     *
     * - parameter aText: text to be sent to the peripheral using Nordic UART Service
     */
    func send(text aText : String) {
        guard self.uartRXCharacteristic != nil else {
            delegate?.showAlert(withTitle: "ERROR", andText: "UART RX Charateristic nor found")
            print("UART RX Charateristic not found")    //ALERT!!
            return
        }
        
        // Check what kind of Write Type is supported. By default it will try Without Reponse.
        // If the RX characteristic have Write property the Write Request type will be used.
        var type = CBCharacteristicWriteType.withoutResponse
        if (self.uartRXCharacteristic!.properties.rawValue & CBCharacteristicProperties.write.rawValue) > 0 {
            type = CBCharacteristicWriteType.withResponse
        }
        
        // In case of Write Without Response the text needs to be splited in up-to 20-bytes packets.
        // When Write Request (with response) is used, the Long Write may be used.
        // It will be handled automatically by the iOS, but must be suppoted in the device side.
        // If your device does support Long Write, change the flag below to true.
        let longWriteSupported = false
        
        // The following code will split the text to packet.
        let textDate = aText.data(using: String.Encoding.utf8)!
        textDate.withUnsafeBytes { (u8Ptr: UnsafePointer<CChar>) in
            var buffer = UnsafeMutableRawPointer(mutating: UnsafeRawPointer(u8Ptr))
            var len = textDate.count
            
            while(len != 0) {
                var part : String
                if len > MTU && (type == CBCharacteristicWriteType.withoutResponse || longWriteSupported == false) {
                    // If the text contains national letters they may be 2-byte long.
                    // If may happen that only 19 (MTU) bytes can be send so that not of them is splited into 2 packets.
                    var builder = NSMutableString(bytes: buffer, length: MTU, encoding: String.Encoding.utf8.rawValue)
                    if builder != nil {
                        // A 20-byte string has been created successfully
                        buffer = buffer + MTU
                        len    = len - MTU
                    } else {
                        // We have to create 19-byte string. Let's ignore some stranger UTF-8 charaters that have more than 2 bytes...
                        builder = NSMutableString(bytes: buffer, length: len, encoding: String.Encoding.utf8.rawValue)
                        buffer  = buffer + (MTU  - 1)
                        len     = len - (MTU  - 1)
                    }
                    
                    part = String(describing: builder!)
                } else {
                    let builder = NSMutableString(bytes: buffer, length: len, encoding: String.Encoding.utf8.rawValue)
                    part = String(describing: builder!)
                    len = 0
                }
                send(text: part, withType: type)
            }
        }
    }
    
    /**
     * Sends the given text to the UART RX characteristic using the given write type.
     * This method does not split the text into parts. If the given write type is withResponse
     * and text is longer than 20-bytes the kong write will be used.
     *
     * - parameters:
     *      - aText: text to be sent to the periphral using Nordic UART Service
     *      - aType: write type to be used
     */
    func send(text aText : String, withType aType : CBCharacteristicWriteType) {
        guard self.uartRXCharacteristic != nil else {
            delegate?.showAlert(withTitle: "ERROR", andText: "UART RX Characteristic not found")
            print("UART RX Characteristic not found")   // ALERT!!
            return
        }
        
        let typeAsString = (aType == .withoutResponse) ? ".withoutResponse" : ".withResponse"
        let data = aText.data(using: String.Encoding.utf8)!
        
        //do some logging
        print("Writing to characteristic: \(uartRXCharacteristic!.uuid.uuidString)")
        print("peripheral.writeValue(0x\(data.hexString), for: \(uartRXCharacteristic!.uuid.uuidString), type: \(typeAsString))")
        
        self.bluetoothPeripheral!.writeValue(data, for: self.uartRXCharacteristic!, type: aType)
        
        // The transmitted data is not available after the method returns. We have to log the text here.
        // The callback peripheral:didWriteValueForCharacteristic:error: is called only when the Write Request type was used,
        // but even if, the data is not available there.
        print("\"\(aText)\" sent")
    }
    
    
    /*/ MARK: - Logger API
     
     func log(withLevel aLevel : ELOGLevel, andMessage aMessage : String) {
     logger?.log(level: aLevel, message: aMessage)
     }
     
     func logError(error anError : Error) {
     if let e = anError as? CBError {
     logger?.log(level: .errorLogLevel, message: "Error \(e.code): \(e.localizedDescription)")
     } else {
     logger?.log(level: .errorLogLevel, message: "Error \(anError.localizedDescription)")
     }
     }*/
    
    // MARK: CBCentralManagerDelegare
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        var state : String
        switch(central.state){
        case .poweredOn:
            state = "Powerer ON"
            break
        case .poweredOff:
            state = "Powered OFF"
            break
        case .resetting:
            state = "Resetting"
            break
        case .unauthorized:
            state = "Unauthorized"
            break
        case .unsupported:
            state = "Unspported"
            break
        case .unknown:
            state = "Unknown"
            break
        }
        
        print("[Callback] Central Manager did update state to: \(state)")
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("[Callback] Central Manager did connect peripheral")
        if let name = peripheral.name {
            print("Connected to: \(name)")
        } else {
            print("Connected to device")
        }
        
        connected = true
        bluetoothPeripheral = peripheral
        bluetoothPeripheral!.delegate = self
        delegate?.didConnectPeripheral(deviceName: peripheral.name)
        print("Discovering services...")
        print("peripheral.discoverServices([\(UARTServiceUUID.uuidString)])")
        peripheral.discoverServices([UARTServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard error == nil else {
            delegate?.showAlert(withTitle: "ERROR", andText: "Central Manager did disconnect peripheral")
            print("[Callback] Central Manager did disconnect peripheral")
            //logError(error: error!)
            return
        }
        print("[Callback] Central Manager did disconnect peripheral successfully")
        print("Disconnected")
        
        connected = false
        delegate?.didDisconnectPeripheral()
        bluetoothPeripheral!.delegate = nil
        bluetoothPeripheral = nil
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard error == nil else {
            delegate?.showAlert(withTitle: "ERROR", andText: "Central Manager did fail to connect to peripheral")
            print("[Callback] Central Manager did fail to connect to peripheral")
            //logError(error: error!)
            return
        }
        print("Failed to connect")
        
        connected = false
        delegate?.didDisconnectPeripheral()
        bluetoothPeripheral!.delegate = nil
        bluetoothPeripheral = nil
    }
    
    //MARK: - CBPeripheralDelegate
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            delegate?.showAlert(withTitle: "ERROR", andText: "Service discovery failed")
            print("Service discovery failed")
            //logError(error: error!)
            //TODO: Disconnect?
            return
        }
        print("Services discovered")
        
        for aService: CBService in peripheral.services! {
            if aService.uuid.isEqual(UARTServiceUUID) {
                print("UART Services found")
                print("Discovering charateristics...")
                print("peripheral.discoverCharacteristics(nil, for:\(aService.uuid.uuidString))")
                bluetoothPeripheral?.discoverCharacteristics(nil, for: aService)
                return
            }
        }
        
        //No UART service  discovered
        print("UART Service not found. Try to turn bluetooth Off and On again to clear the cache.")
        delegate?.peripheralNotSupported()
        cancelPeripheralConnection()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            delegate?.showAlert(withTitle: "ERROR", andText: "Caracteristics discovery failed")
            print("Charateristics discovery failed")    //ALERT!!
            //logError(error: error!)
            return
        }
        print("Characteristics discovered")
        
        if service.uuid.isEqual(UARTServiceUUID) {
            for aCharacteristic : CBCharacteristic in service.characteristics! {
                if aCharacteristic.uuid.isEqual(UARTTXCharacteristicUUID) {
                    print("TX Characteristic found")
                    uartTXCharacteristic = aCharacteristic
                } else if aCharacteristic.uuid.isEqual(UARTRXCharacteristicUUID) {
                    print("RX Characteristic found")
                    uartRXCharacteristic = aCharacteristic
                }
            }
            //Enable notifications on TX Characteristic
            if (uartTXCharacteristic != nil && uartRXCharacteristic != nil) {
                print("Enabling notifications for \(uartTXCharacteristic!.uuid.uuidString)")
                print("peripheral.setNotifyValue(true, for: \(uartTXCharacteristic!.uuid.uuidString))")
                bluetoothPeripheral!.setNotifyValue(true, for: uartTXCharacteristic!)
                //We can return after calling CBPeripheral.setNotifyValue because CBPeripheralDelegate's didUpdateNotificationStateForCharacteristic method will be called automatically.
            } else {
                print("UART service does not have required characteristics. Try to turn Bluetooth Off and On again to clear cache.")
                delegate?.peripheralNotSupported()
                cancelPeripheralConnection()
            }
            /** When we find both RX and TX characteristics, we subscribe to updates to the value of uartTXCharacteristic by calling setNotifyValue()
             *   -we use this characteristic to send data from the peripheral
             *  We also save a reference to the RX characteristc, so we can receive data from the peripheral.
             */
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            delegate?.showAlert(withTitle: "ERROR", andText: "Enabling notifications failed")
            print("Enabling notifications failed")  //ALERT!!
            //logError(error: error!)
            return
        }
        
        if characteristic.isNotifying {
            print("Notifications enabled for characteristic: \(characteristic.uuid.uuidString)")
        } else {
            print("Notifications disabled for characteristic: \(characteristic.uuid.uuidString)")
        }
        
        self.send(text: "S132")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            delegate?.showAlert(withTitle: "ERROR", andText: "Writing value to characteristic has failed")
            print("Writing value to characteristic has failed")     //ALERT!!
            //logError(error: error!)
            return
        }
        print("Data written to characteristic: \(characteristic.uuid.uuidString)")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        guard error == nil else {
            delegate?.showAlert(withTitle: "ERROR", andText: "Writing value to descriptor has failed")
            print("Writing value to descriptor has failed")     //ALERT!!
            //logError(error: error!)
            return
        }
        print("Data written to descriptor: \(descriptor.uuid.uuidString)")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        /** This method is invoked when the peripheral notifies your app that the value of the characteristic for which notifications and indications are enabled (via a successfull call to setNotifyValue(_: for:)) as changed. If successful, the error parameter is nil. If unsuccessful, the error parameter returns the cause of the failure.
         parameters: peripheral - The peripheral providing this information
         characteristic - The characteristic whose value has been retrieved
         error - If an error occured, the cause of the failure
         */
        
        guard error == nil else {
            delegate?.showAlert(withTitle: "ERROR", andText: "Updating characteristic has failed")
            //logError(error: error!)
            return
        }
        
        // try to print a friendly string of received bytes if they can be parsed as UTF8
        guard let bytesReceived = characteristic.value else {
            print("Notification received from: \(characteristic.uuid.uuidString), with empty value")
            print("Empty packet received")
            return
        }
        
        
        
        bytesReceived.withUnsafeBytes { (utf8Bytes: UnsafePointer<CChar>) in
            var len = bytesReceived.count
            if utf8Bytes[len - 1] == 0 {
                len -= 1 // if the string is null terminated, don't pass null terminator into NSMutableString constructor
            }
            
            print("Notification received from: \(characteristic.uuid.uuidString), with value: 0x\(bytesReceived.hexString)")
            //if let validUTF8String = String(utf8String: utf8Bytes) {//  NSMutableString(bytes: utf8Bytes, length: len, encoding: String.Encoding.utf8.rawValue) {
            //print("\"\(validUTF8String)\" received")
            //} else {
            print("\"0x\(bytesReceived.hexString)\" received")
            //}
            if bytesReceived.hexString == "00" {
                print("The lock is closed")
                lockStatus = false
                delegate?.showAlert(withTitle: "STATUS", andText: "The lock is closed. ")
            } else if bytesReceived.hexString == "01" {
                print("The lock is open")
                lockStatus = true
                delegate?.showAlert(withTitle: "STATUS", andText: "The lock is open")
            }
        }
    }
}
