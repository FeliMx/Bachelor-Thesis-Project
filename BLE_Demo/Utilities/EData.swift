//
//  EData.swift
//  BLE_Demo
//
//  Created by Konstruktion on 01.08.18.
//  Copyright © 2018 EMKA Beschlagteile. All rights reserved.
//

import Foundation

extension Data {
    
    internal var hexString: String {
        let pointer = self.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> UnsafePointer<UInt8> in
            return bytes
        }
        let array = getByteArray(pointer)
        
        return array.reduce("") { (result, byte) -> String in
            result + String(format: "%02x", byte)
        }
    }
    
    fileprivate func getByteArray(_ pointer: UnsafePointer<UInt8>) -> [UInt8] {
        let buffer = UnsafeBufferPointer<UInt8>(start: pointer, count: count)
        return [UInt8](buffer)
    }
}

