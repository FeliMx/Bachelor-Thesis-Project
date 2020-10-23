//
//  SchlosslistViewController.swift
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


fileprivate func > <T: Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l > r
    default:
        return rhs < lhs
    }
}

protocol SchlosslistDelegate {
    func abmelden()
}

class SchlosslistViewControler: UIViewController, CBCentralManagerDelegate, UITableViewDelegate, UITableViewDataSource, BluetoothManagerDelegate {
    
    let dfuServiceUUIDString    = "00001530-1212-EFDE-1523-785FEABCD123"
    let ANCSServiceUUIDString   = "7905F431-B5CE-4E99-A40F-4B1E122D00D0"
    
    //MARK: - ViewControllerProperties
    var bluetoothCentralManager     : CBCentralManager?
    var bluetoothManager            : BluetoothManager?
    var thisBenutzer                : appBenutzer = appBenutzer()
    var filterUUID                  : CBUUID?
    var peripherals                 : [EPeripheral]
    var timer                       : Timer?
    var delegate                    : SchlosslistDelegate?
    
    @IBOutlet weak var Schlosslist: UITableView!
    @IBOutlet weak var EmptyView: UIView!
    @IBOutlet weak var connectStatus: UILabel!
    @IBOutlet weak var disconnectButton: UIBarButtonItem!
    
    
    @IBAction func abmeldenTapped(_ sender: AnyObject) {
        delegate?.abmelden()
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func disconnectTapped(_ sender: AnyObject) {
        bluetoothManager?.cancelPeripheralConnection()
        self.disconnectButton.title = ""
        self.connectStatus.isHidden = true
    }
    

    
    @objc func timerFire() {
        if peripherals.count > 0 {
            EmptyView.isHidden = true
            Schlosslist.reloadData()
        }
    }
    
    init(_ coder: NSCoder? = nil ) {
        peripherals = []
        if let coder = coder {
            super.init(coder: coder)!
        } else {
            super.init(nibName: nil, bundle: nil)
        }
    }
    
    required convenience init(coder: NSCoder) {
        self.init(coder)
    }
    
    func getRSSIImage(RSSI anRSSIValue: Int32) -> UIImage {
        var image: UIImage
        
        if (anRSSIValue < -90 ) {
            image = UIImage(named: "Signal_0")!
        } else if (anRSSIValue < -70 ) {
            image = UIImage(named: "Signal_1")!
        } else if (anRSSIValue < -50 ) {
            image = UIImage(named: "Signal_2")!
        } else {
            image = UIImage(named: "Signal_3")!
        }
        
        return image
    }
    
    func getConnectedPeripherals() -> [CBPeripheral] {
        guard let aBluetoothManager = bluetoothCentralManager else {
            return []
        }
        
        var retrievedPeripherals : [CBPeripheral]
        
        if filterUUID == nil {
            let dfuServiceUUID      = CBUUID(string: dfuServiceUUIDString)
            let ancsServiceUUID     = CBUUID(string: ANCSServiceUUIDString)
            retrievedPeripherals    = aBluetoothManager.retrieveConnectedPeripherals(withServices: [dfuServiceUUID, ancsServiceUUID])
        } else {
            retrievedPeripherals    = aBluetoothManager.retrieveConnectedPeripherals(withServices: [filterUUID!])
        }
        
        return retrievedPeripherals
    }
    
    /**
     * Starts scanning for peripherals with rscServiceUUID.
     * - parameter enable: If YES, this method will enable scanning for bridge devices, if NO it will stop scanning
     * - returns: true if success, false if Bluetooth Manager is not in CBCentralManagerStatePowerOn state.
     */
    func scanForPerioherals(_ enable:Bool) -> Bool {
        guard bluetoothCentralManager?.state == .poweredOn else {
            return false
        }
        
        DispatchQueue.main.async {
            if enable == true {
                let options: NSDictionary = NSDictionary(objects: [NSNumber(value: true as Bool)], forKeys: [CBCentralManagerScanOptionAllowDuplicatesKey as NSCopying])
                if  self.filterUUID != nil {
                    self.bluetoothCentralManager?.scanForPeripherals(withServices: [self.filterUUID!], options: options as? [String : AnyObject])
                } else {
                    self.bluetoothCentralManager?.scanForPeripherals(withServices: nil, options: options as? [String : AnyObject])
                }
                self.timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.timerFire), userInfo: nil, repeats: true)
                /** Creates a timer and schedules it on the current run loop in the default mode
                 *  Parameters: timeInterval: The number of seconds between firings of he timer. if ti is less than or equal 0.0, this method chooses the nonnegative value of 0.1 milliseconds instead.
                 target: The object to which to send the message specified by aSelector when the tmer fires. The timer maintains a strng reference to target until it is invalidated.
                 selector: The message to send to target when the timer fires.
                 userInfo: The user info for the timer.
                 repeats: If true, the timer will repeatedly reschedule itself until invalidated. If false, the timer will be invalidated after it fires
                 *  Return: A new NSTImer object, configured according to the specified parameters
                 *  Discusion: After ti seconds have eplased, the timer fires, sending the message selector to target
                 *
                 *  In this case, the UITableView reload every second.
                 */
                
            } else {
                self.timer?.invalidate()    //Stops the timer form ever firing again and requests its removal from its run loop.
                self.timer = nil
                self.bluetoothCentralManager?.stopScan()
            }
        }
        
        return true
    }
    
    //MARK: - ViewController Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        Schlosslist.delegate = self
        Schlosslist.dataSource = self
        
        self.disconnectButton.title = ""
        self.connectStatus.isHidden = true
        
        if thisBenutzer.schlossAnzahl > 0 {
            self.EmptyView.isHidden = true
        }
        
        let centralQueue = DispatchQueue(label: "de.emka.BLESSchloss", attributes: [])
        bluetoothCentralManager = CBCentralManager(delegate: self, queue: centralQueue)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.statusBarStyle = .default
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        let success = self.scanForPerioherals(false)       //stop scanning
        if !success {
            print("Bluetooth is powered off!")
        }
        
        UIApplication.shared.statusBarStyle = .lightContent
        super.viewWillDisappear(animated)
    }
    
    //MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Tella the data source to return the number of rows in a given section of a table.
        return thisBenutzer.schlossAnzahl
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Asks the data source for a cell to insert in a particular location of the table view.
        let aCell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        // Returns a rusable table-view cell object for the specified reuse identifier and adds it to the table.
        
        // update cell content
        let aSchloss = thisBenutzer.schlossList[indexPath.row]
        
        aCell.textLabel?.text = aSchloss.Name
        aCell.detailTextLabel?.text = "Beschreibung: \(aSchloss.Beschreibung)"
        
        for aperipheral in peripherals {
            if aperipheral.name() == aSchloss.serialNummer {
                if aperipheral.isConnected == true {
                    aCell.imageView!.image = UIImage(named: "Connected")
                } else {
                    let RSSIImage = self.getRSSIImage(RSSI: aperipheral.RSSI)
                    aCell.imageView!.image = RSSIImage
                }
                break
            } else {
                aCell.imageView?.image = UIImage(named: "Signal_0")!
            }
        }
        
        return aCell
    }
    
    //MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Tells the delegate that the specified row is now selected
        
        bluetoothCentralManager!.stopScan()
        // Call delegate method
        let theSchlossSN = thisBenutzer.schlossList[indexPath.row].serialNummer
        
        self.connectStatus.text = "connected to: \(thisBenutzer.schlossList[indexPath.row].Name)"
        
        var a = 0
        for ape in peripherals {
            if ape.name() == theSchlossSN {
                break
            }
            a += 1
        }
        
        if a < peripherals.count {
            if self.bluetoothManager == nil {
                let peripheral = peripherals[a].peripheral
                
                self.centralManagerDidSelectPeripheral(withManager: bluetoothCentralManager!, andPeripheral: peripheral)
            } else {
                self.send(value: "S131")
            }
        } else {
            showAlert(withTitle: "Not Find", andText: "The selected Lock isn't nearby")
            // show alert if the lock is not nearby
        }
    }
    
    
    //MARK: - CBCentralManagerdelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // Automatically called on the CBcentralManager delegte
        let alertVC = UIAlertController(title: "Not Avaliable", message: "Bluetooth is powered off!", preferredStyle: UIAlertControllerStyle.alert)
        let action = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: { (action: UIAlertAction) -> Void in
            self.dismiss(animated: true, completion: nil)
        })
        alertVC.addAction(action)
        
        guard central.state == .poweredOn else {
            self.present(alertVC, animated: true, completion: nil)
            return
        }
        
        let connectedPeripherals = self.getConnectedPeripherals()
        var newScannedPeripherals: [EPeripheral] = []
        connectedPeripherals.forEach { (connectedPeripheral: CBPeripheral) in
            let connected = connectedPeripheral.state == .connected
            let scannedPeripheral = EPeripheral(withPeripheral: connectedPeripheral, andIsConnected: connected)
            newScannedPeripherals.append(scannedPeripheral)
        }
        peripherals = newScannedPeripherals
        let success = self.scanForPerioherals(true)
        if !success {
            self.present(alertVC, animated: true, completion: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // called when the central manager discovers a peripheral while scanning. Also, once peripheral is connected, cancel scanning.
        
        // Scanner uses other queue to send events. We must edit UI in the main queue
        DispatchQueue.main.async(execute: {
            var sensor = EPeripheral(withPeripheral: peripheral, andRSSI: RSSI.int32Value, andIsConnected: false )
            if ((self.peripherals.contains(sensor)) == false) {
                self.peripherals.append(sensor)
            } else {
                sensor = self.peripherals[self.peripherals.index(of: sensor)!]
                sensor.RSSI = RSSI.int32Value
            }
        })
    }
    
    
    //MARK: - centralManagerDidSelectPeripheral
    func centralManagerDidSelectPeripheral(withManager aManager: CBCentralManager, andPeripheral aPeripheral: CBPeripheral) {
        
        bluetoothManager = BluetoothManager(withManager: aManager)
        bluetoothManager!.delegate = self
        
        bluetoothManager!.connectPeripheral(peripheral: aPeripheral)
        
        self.disconnectButton.title = "disconnect"
        self.connectStatus.isHidden = false
        
    }
    
    // MARK: - BluetoothManagerDelegate
    func perioheralReady() {
        print("Peripheral is ready")
    }
    
    func peripheralNotSupported() {
        print("Peripheral is not supported")
    }
    
    func didConnectPeripheral(deviceName aName: String?) {
        // Scanner uses other queue to send events. We must edit UI in the main queue
        print("Connect success")
        
        }
    
    func didDisconnectPeripheral() {
        // Scanner uses other queue to send events. We must edit UI in the main queue
        self.showAlert(withTitle: "Disconnected", andText: "The Lock is successfully disconnected. ")
        bluetoothManager = nil
    }
    
    func showAlert(withTitle aTitle: String, andText aText: String) {
        // show alert with message of error or status
        let alertVC = UIAlertController(title: aTitle, message: aText, preferredStyle: UIAlertControllerStyle.alert)
        let action = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: {(action: UIAlertAction) -> Void in
            alertVC.dismiss(animated: true, completion: nil)
        })
        alertVC.addAction(action)
        self.present(alertVC, animated: true, completion: nil)
    }
    
    
    // MARK: - UART API
    func send(value aValue: String) {
        if self.bluetoothManager != nil {
            bluetoothManager?.send(text: aValue)
        }
    }
    
    
}
