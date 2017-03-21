//
//  MyWindowController.swift
//  MagicLightBulbLEX
//
//  Created by Edwin Tam on 31/12/2016.
//  Copyright © 2016 ioStation Ltd. All rights reserved.
//  Adopted from MagicLightLEX for LED Lamps
//

import Cocoa
import CoreBluetooth

extension NSColor {
    
    func rgb() -> Int? {
        var fRed : CGFloat = 0
        var fGreen : CGFloat = 0
        var fBlue : CGFloat = 0
        var fAlpha: CGFloat = 0
        self.getRed(&fRed, green: &fGreen, blue: &fBlue, alpha: &fAlpha)
        if (fRed.isNaN || (fRed < 0.0)) {
            fRed = 0.0
        }
        if (fGreen.isNaN || (fGreen < 0.0)) {
            fGreen = 0.0
        }
        if (fBlue.isNaN || (fBlue < 0.0)) {
            fBlue = 0.0
        }
        if (fAlpha.isNaN || (fAlpha < 0.0)) {
            fAlpha = 0.0
        }
        
        let iRed = Int(fRed * 255.0)
        let iGreen = Int(fGreen * 255.0)
        let iBlue = Int(fBlue * 255.0)
        let iAlpha = Int(fAlpha * 255.0)
        //  (Bits 24-31 are alpha, 16-23 are red, 8-15 are green, 0-7 are blue).
        let rgb = (iAlpha << 24) + (iRed << 16) + (iGreen << 8) + iBlue
        return rgb
    }
}

@available(OSX 10.12.0, *)
extension NSTextField: NSAnimationDelegate {

    public func rainbow(_ sender: Any) {
        let animator1 = NSAnimation.init(duration: 10.0, animationCurve: NSAnimationCurve.linear)
        animator1.frameRate = 10.0
        animator1.animationBlockingMode = NSAnimationBlockingMode.nonblocking
        animator1.delegate = self as NSAnimationDelegate?
        for i in 0...100 {
            animator1.addProgressMark(Float(Double(i)/100.0))
        }
        animator1.start()
    }
    
    public func animation(_ animation: NSAnimation, didReachProgressMark progress: NSAnimationProgress) {
        self.textColor = NSColor.init(hue: CGFloat(progress), saturation: 1.0, brightness: 0.8, alpha: 1.0)
    }
}

@available(OSX 10.12.2, *)
class MyWindowController: NSWindowController, NSWindowDelegate, CBCentralManagerDelegate, CBPeripheralDelegate {
    // MARK: Local variables
    let debug = false
    var keepScanning = false
    
    // define our scanning timers
    let timerScanInterval:TimeInterval = 10.0
    var scanTimer:Timer? = nil
    
    var tbAnim:NSViewAnimation? = nil
    
    var LEDConnected = false
    var lastTouchTime = Date()
    let defaultInitialColor = NSColor.init(red:0.0, green:0.0, blue:0.0, alpha:1.0)
    var lastColor=NSColor.init(red:0.0, green:0.0, blue:0.0, alpha:1.0)
    var apple_rgbcolor:NSColor? = nil

    // MARK: Core Bluetooth properties
    var centralManager:CBCentralManager!
    var blePeripheral:CBPeripheral?
    var ledcolorCharacteristic:CBCharacteristic?
    var ledcolorPeripheral:CBPeripheral?
    var ledcolorDescriptor:CBDescriptor?
    var ledcolortempCharacteristic:CBCharacteristic?
    var ledcolortempPeripheral:CBPeripheral?
    var ledcolortempDescriptor:CBDescriptor?

    // MARK: - IB Items
    
    @IBOutlet weak var scanButton: NSButton!
    @IBOutlet weak var colorPicker: NSColorPickerTouchBarItem!
    @IBOutlet weak var messageOnTouchBar: NSTextField!
    
    // MARK: - Window Loaded
    
    override func windowDidLoad() {
        super.windowDidLoad()

        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        centralManager = CBCentralManager(delegate: self, queue: nil)
        self.messageOnTouchBar.stringValue = "Loading"
        self.window?.delegate = self
        self.colorPicker.isEnabled = false
//        tbAnim = NSViewAnimation.init(duration: 2.0, animationCurve: NSAnimationCurve.easeInOut)
    }

    func windowWillClose(_ notification: Notification) {
        quitButtonTouched(self)
    }
    
    // MARK: - Setting output
    
    func setTouchBarMessage(_ message: String?, color: NSColor?) {
        if (self.messageOnTouchBar != nil) {
            if let m = message {
                self.messageOnTouchBar.stringValue = m
            } else {
                self.messageOnTouchBar.stringValue = "Default"
            }
        }
        if (color == nil) {
            self.messageOnTouchBar.textColor = NSColor.lightGray
        } else {
            self.messageOnTouchBar.textColor = color
        }
    }

    func setLEDColor(_ color:NSColor!) {
        if (LEDConnected) { // Act only when connected
            if (abs(lastTouchTime.timeIntervalSince(Date())) > 0.5) {
                lastTouchTime = Date()
                // Handle color touched only per 0.5+ seconds
                var dataArray = [UInt8](repeating: 0, count: 4)
                self.apple_rgbcolor = color
                let rgb = color.rgb()
                dataArray[0] = 0xD0                             //Constant
                dataArray[1] = UInt8((rgb! & 0x00FF0000) >> 16) //R
                dataArray[2] = UInt8((rgb! & 0x0000FF00) >> 8)  //G
                dataArray[3] = UInt8((rgb! & 0x000000FF))       //B
                if (rgb! & 0x00FFFFFF) == 0x00FFFFFF {
                    var colorTemp = [UInt8](repeating: 0, count: 3)
                    colorTemp[0] = 0xA0
                    colorTemp[1] = 0x0F
                    colorTemp[2] = 0x64
                    let data = Data.init(bytes:colorTemp)
                    self.ledcolortempPeripheral?.writeValue(data, for: self.ledcolortempCharacteristic!, type: CBCharacteristicWriteType.withoutResponse)
                } else if (rgb! & 0x00FFFFFF) == 0x007F7F7F {
                    var colorTemp = [UInt8](repeating: 0, count: 3)
                    colorTemp[0] = 0xA0
                    colorTemp[1] = 0x0F
                    colorTemp[2] = 0x32
                    let data = Data.init(bytes:colorTemp)
                    self.ledcolortempPeripheral?.writeValue(data, for: self.ledcolortempCharacteristic!, type: CBCharacteristicWriteType.withoutResponse)
                } else {
                    let data = Data.init(bytes:dataArray)
                    self.ledcolorPeripheral?.writeValue(data, for: self.ledcolorCharacteristic!, type: CBCharacteristicWriteType.withoutResponse)
                }
            }
        }
    }
    
    // MARK: - Response to User Interaction
    
    @IBAction func scanButtonTouched(_ sender: Any) {
        self.handleScanButtonTapped(sender)
    }
    
    @IBAction func colorPicked(_ sender: Any) {
        setLEDColor((sender as! NSColorPickerTouchBarItem).color)
    }
    
    @IBAction func quitButtonTouched(_ sender: Any) {
        if (scanTimer != nil) {
            scanTimer?.invalidate()
            scanTimer = nil
        }
        self.disconnect()
        NSApplication.shared().terminate(self)
    }
    
    // MARK: - Handling User Interaction

    func handleScanButtonTapped(_ sender: Any) {
        if (debug) {print("DEBUG: Handling Scan/Disconnect")}
        // if we don't have a device, start scanning for one...
        if self.blePeripheral == nil {
            keepScanning = true
            resumeScan()
            return
        } else {
            disconnect()
        }
    }
    
    func disconnect() {
        if (debug) {print("DEBUG: Disconnect")}
        if let blePeripheral = self.blePeripheral {
            LEDConnected = false
            self.colorPicker.isEnabled = false
            self.ledcolorCharacteristic = nil
            self.ledcolorPeripheral = nil
            self.centralManager.cancelPeripheralConnection(blePeripheral)
        }
    }
    
    // MARK: - Bluetooth scanning
    
    func pauseScan() {
        // Scanning uses up battery on phone, so pause the scan process for the designated interval.
        if (debug) {print("DEBUG: PAUSING SCAN...")}
        setTouchBarMessage("Stopped", color: nil)

        scanTimer = nil
        self.centralManager.stopScan()
    }
    
    func resumeScan() {
        if keepScanning {
            // Start scanning again...
            if (debug) {print("DEBUG: RESUMING SCAN!")}
            setTouchBarMessage("Scanning...", color: NSColor.blue)
            self.messageOnTouchBar.rainbow(self)
            if (scanTimer == nil) {
                scanTimer = Timer(timeInterval: timerScanInterval, target: self, selector: #selector(pauseScan), userInfo: nil, repeats: false)
                RunLoop.main.add(scanTimer!, forMode: RunLoopMode.commonModes)
            }
//            let blePeripheralAdvertisingUUID = CBUUID(string: Device.MagicLightServiceUUID)
            let optionsDict = ["CBCentralManagerScanOptionAllowDuplicatesKey": false] as Dictionary
            self.centralManager.scanForPeripherals(withServices: nil, options: optionsDict)
        } else {
        }
    }
    
    // MARK: - CBCentralManagerDelegate methods
    
    // Invoked when the central manager’s state is updated.
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        var message = ""
        
        switch central.state {
        case .poweredOff:
            message = "Bluetooth on this device is currently powered off."
        case .unsupported:
            message = "This device does not support Bluetooth Low Energy."
        case .unauthorized:
            message = "This app is not authorized to use Bluetooth Low Energy."
        case .resetting:
            message = "The BLE Manager is resetting; a state update is pending."
        case .unknown:
            message = "The state of the BLE Manager is unknown."
        case .poweredOn:
            message = "Bluetooth LE is turned on and ready for communication."
            
            if (debug) {print(message)}
            setTouchBarMessage("Ready", color: NSColor.lightGray)
            self.keepScanning = true
            _ = Timer(timeInterval: timerScanInterval, target: self, selector: #selector(pauseScan), userInfo: nil, repeats: false)
        }
        
        
    }
    
    
//     Invoked when the central manager discovers a peripheral while scanning.
     
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let blePeripheralServiceUUID = CBUUID(string: Device.MagicLightServiceUUID)
        var serviceUUIDFound = ""
        // kCBAdvDataServiceUUIDs is a NSArray of Service UUIDs
        // Peripheral name is usually in peripheral.name
        // However, it may also be contained in advertisementData with the key "kCBAdvDataLocalName"
        let c = (advertisementData as Dictionary)["kCBAdvDataServiceUUIDs"] as? [CBUUID]
        if (debug) {
            if let d = c?[0].uuidString {
                serviceUUIDFound = String(describing: d)
            }
            print("DEBUG: centralManager didDiscoverPeripheral - Adv Name is \"\(serviceUUIDFound)\"")
        }
        if (c?.count == 1) && (c?[0].isEqual(blePeripheralServiceUUID))! {
            if (debug) {print("DEBUG: MAGICLIGHTBULB FOUND! CONNECTING NOW!!!")}
            // to save power, stop scanning for other devices
            keepScanning = false
            
            // save a reference of our peripheral
            self.blePeripheral = peripheral
            self.blePeripheral!.delegate = self
            
            // Connect to our peripheral
            central.connect(self.blePeripheral!, options: nil)
        }
    }
    
    
//     Invoked when a connection is successfully created with a peripheral.
     
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if (debug) {print("DEBUG: SUCCESSFULLY CONNECTED TO MAGICLIGHTBULB!!!")}
        scanTimer?.invalidate()     // stop scanning timer
        setTouchBarMessage("Connected", color: NSColor.green)
        self.scanButton.title = "Disconnect"
        
        // Now that we've successfully connected to the blePeripheral, let's discover the services.
        let blePeripheralServiceUUID = CBUUID(string: Device.MagicLightServiceUUID)
        peripheral.discoverServices([blePeripheralServiceUUID])
    }

//     Invoked when the central manager fails to create a connection with a peripheral.
     
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if (debug) {print("ERROR: CONNECTION TO MAGICLIGHTBULB FAILED!!!")}
        setTouchBarMessage("Error Conn", color: NSColor.red)
        self.scanButton.title = "Connect"
    }
    
    
//     Invoked when an existing connection with a peripheral is torn down.

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if (debug) {print("DEBUG: DISCONNECTED FROM MAGICLIGHTBULB!!!")}
        setTouchBarMessage("Disconnected", color: nil)
        self.scanButton.title = "Connect"
        if error != nil {
            if (debug) {print("ERROR: DISCONNECTION DETAILS: \(error!.localizedDescription)")}
        }
        self.blePeripheral = nil
        // Todo
        // Save lastColor to defaults for next time to set the LED color automatically
    }
    
    
    //MARK: - CBPeripheralDelegate methods

//      Invoked when discovered the peripheral’s available services.
     
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if error != nil {
            if (debug) {print("ERROR: ERROR IN DISCOVERING SERVICES: \(error?.localizedDescription)")}
            return
        }
        
        if let services = peripheral.services {
            for service in services {
                if (debug) {print("DEBUG: Discovered service \(service)")}
                // If we found the MagicLight, discover its characteristics
                if (service.uuid == CBUUID(string: Device.MagicLightServiceUUID))
                {
                    if (debug) {print("DEBUG: Discovering characteristics")}
                    let LEDColorCharUUIDs = [CBUUID(string: Device.LEDColorCharUUID), CBUUID(string: Device.LEDTempCharUUID)]
                    peripheral.discoverCharacteristics(LEDColorCharUUIDs, for: service)
                }
            }
        }
    }
    
    
//     Invoked when you discover the characteristics of a specified service.
     
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if error != nil {
            if (debug) {print("ERROR: ERROR IN DISCOVERING CHARACTERISTICS: \(error?.localizedDescription)")}
            return
        }
        
        if let characteristics = service.characteristics {
            var found = false
            for characteristic in characteristics {
                if (debug) {print("DEBUG: Discovered characteristics \(characteristic.uuid)")}
                if characteristic.uuid == CBUUID(string: Device.LEDColorCharUUID) {
                    found = true
                    if (debug) {print("DEBUG: Discovered RGB Color characteristics")}
                    self.ledcolorCharacteristic = characteristic
                    self.ledcolorPeripheral = peripheral
                    self.ledcolorDescriptor = characteristic.descriptors?[0]
                    peripheral.readValue(for: characteristic)
                } else if characteristic.uuid == CBUUID(string: Device.LEDTempCharUUID) {
                    found = true
                    if (debug) {print("DEBUG: Discovered Color Temp characteristics")}
                    self.ledcolortempCharacteristic = characteristic
                    self.ledcolortempPeripheral = peripheral
                    self.ledcolortempDescriptor = characteristic.descriptors?[0]
                    peripheral.readValue(for: characteristic)

                }
            }
            if (found) {
                LEDConnected = true
                setTouchBarMessage("MagicLightBulb", color: NSColor.yellow)
                self.colorPicker.isEnabled = true
            }
        }
    }
    
    
//     Invoked when you retrieve a specified characteristic’s value,
//     or when the peripheral device notifies your app that the characteristic’s value has changed.
     
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            if (debug) {print("ERROR: UPDATING VALUE FOR CHARACTERISTIC: \(characteristic) - \(error?.localizedDescription)")}
            return
        }
        if (debug) {print("DEBUG: Characteristic \(characteristic) updated value")}
        // extract the data from the characteristic's value property
        if let dataBytes = characteristic.value {
            if characteristic.uuid == CBUUID(string: Device.LEDColorCharUUID) {
                // Todo:
                // doSomeThingWith(dataBytes)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        // This is a call back from a successful write (only from write_with_notification)
        if error != nil {
            if (debug) {print("ERROR: UPDATING VALUE TO CHARACTERISTIC: \(characteristic) - \(error?.localizedDescription)")}
            return
        }
    }

}

