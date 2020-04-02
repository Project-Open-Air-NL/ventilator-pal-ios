//
//  BLEConstants.swift
//  VentilatorPal
//
//  Created by Tijn Kooijmans on 27/03/2020.
//  Copyright © 2020 Sophisti. All rights reserved.
//

//Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

//The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import Foundation
import CoreBluetooth

enum BLECharacteristicKey: Int {
    case write
    case read
}

class BLEConstants {
    
    static let autoConnect = true;
    
    // even though connecting by broadcasted service UUID is prefered, some peripherals do not
    // broadcasted this and we need to connect by name
    static let connectByName = false;
    
    // set true if we need to perform an initial read on all characteristics after discovery
    static let performInitialRead = false;
    
    static let scanInterval: TimeInterval = 3
    
    static let bleName = ""
  
    static let dataServiceUuid = CBUUID(string: "c1eea6f7-0dda-4c51-84ef-a846c6c93367")
    
    // 128 bit base uuid
    static let advServiceUuid = dataServiceUuid
    
    static let bleCharacteristicKeys = [
        "c2eea6f7-0dda-4c51-84ef-a846c6c93367": BLECharacteristicKey.write,
        "c3eea6f7-0dda-4c51-84ef-a846c6c93367": BLECharacteristicKey.read
    ]
    
    static let pairedUuidKey = "pairedUuidKey"
    static let pairedDeviceIdKey = "pairedDeviceIdKey"
    
    static let centralManagerKey = "MGUCentralManagerIdentifier"

}
