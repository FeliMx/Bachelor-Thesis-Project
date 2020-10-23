//
//  ViewController.swift
//  BLE_Demo
//
//  Created by Konstruktion on 30.07.18.
//  Copyright © 2018 EMKA Beschlagteile. All rights reserved.
//

import UIKit
import SwiftSocket

protocol BenutzerDelegate {
    func benutzerTransmission(witheBenutzer aBenutzer: appBenutzer)
}

class LoginViewController: UIViewController {
    
    var socketClient: TCPClient?
    var benutzer = appBenutzer()
    var benutzerDelegate: BenutzerDelegate?
    
    @IBOutlet weak var benutzername: UITextField!
    @IBOutlet weak var passwort: UITextField!
    
    @IBAction func LoginTapped(_ sender: Any) {
        let Benutzername: String! = benutzername!.text
        let Passwort: String! = passwort!.text
        self.benutzer.Benutzername = Benutzername
        
       // let dd: [UInt8] = [50,44,49,50,44,49,50,51,52,53,54,55,56,44,76,97,116,99,104,49,44,76,97,116,99,104,32,97,110,32,66,117,101,114,111,35]
       // self.infoFragen(data: dd)
        
        processClientSocket(Benutzername: Benutzername!, Passwort: Passwort!)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func processClientSocket(Benutzername b: String!, Passwort p: String!){
        socketClient = TCPClient(address: "192.168.110.137", port: 1983)
        
        

        switch self.socketClient!.connect(timeout: 1) {
        case .success:
            DispatchQueue.main.async {
                self.alert(msg: "connect success", after: {})
            }
            
            let msgtosend0 = "0,\(b!),\(p!)#"
            _ = self.socketClient!.send(string: msgtosend0)
            print(msgtosend0)
            // send Benutzername und Passwort to Webserver
            while true {
                if let receiveData = self.socketClient!.read(1024 * 10) {
                    
                    self.processList(withData: receiveData)
                }
                if self.benutzer.schlossList.count == self.benutzer.schlossAnzahl { break }
            }
            
        case .failure(let error):
            DispatchQueue.main.async {
                self.alert(msg: error.localizedDescription, after: {})
            }
        }
        
        
        /*let receiveData0 = socketClient?.read(1024 * 10)
        //received data from server
        
        if receiveData0![0] == 0 && receiveData0![3] == 0{
                _ = self.socketClient!.send(string: "1")
                let receiveData1 = self.socketClient?.read(1024 * 10)
                let count = Int(receiveData1![2])
                processList(count: count)
        }*/
    }
    
    
    func processList(withData raData: [Byte]) {
        
        var msg: String = ""
        for s in raData {
            msg += String(UnicodeScalar(s))
        }
        print(msg)
        
        switch raData[0] {
        case 48:
            self.anmelden(data: raData)
        case 49:
            self.anzahlFragen(data: raData)
        case 50:
            self.infoFragen(data: raData)
        default:
            self.alert(msg: "Wrong Data", after: {})
        }
        
    }
    
    func anmelden(data aData: [Byte]) {
        if aData[2] == 48 {
            self.alert(msg: "Login success", after: {})
            _ = self.socketClient!.send(string: "1#")
        } else {
            self.alert(msg: "Benutzername oder Passwort falsch!", after: {})
        }
    }
    
    func anzahlFragen(data aData: [Byte]) {
        var anzahl : Int = 0
        if aData[3] == 35 {
            anzahl = Int(aData[2]) - 48
        } else if aData[4] == 35 {
            anzahl = (Int(aData[2]) - 48) * 10 + Int(aData[3]) - 48
        } else if aData[5] == 35 {
            anzahl = (Int(aData[2]) - 48) * 100 + (Int(aData[3]) - 48) * 10 + Int(aData[4]) - 48
        } else {
            self.alert(msg: "Wrong!", after:{})
        }
        
        self.benutzer.schlossAnzahl = anzahl
        
        for n in 0...(anzahl - 1) {
            _ = self.socketClient?.send(string: "2,\(n)#")
            while true {
                if let receiveData = self.socketClient!.read(1024 * 10) {
                    var msg: String = ""
                    for s in receiveData {
                        msg += String(UnicodeScalar(s))
                    }
                    print(msg)
                    
                    infoFragen(data: receiveData)
                    break
                }
                
            }
        }
    }
    
    func infoFragen(data aData: [Byte]){
        // get Index in the received Information
        var aIndex: String = ""
        var cot = 2
        while aData[cot] != 44 {
            cot += 1
        }
        for l in 2...(cot - 1) {
            aIndex += String(UnicodeScalar(aData[l]))
        }
        
        // get serial Nummer in the received Information
        var aSerialNummer: String = ""
        var cof = cot + 1
        while aData[cof] != 44 {
            cof += 1
        }
        for n in (cot + 1)...(cof - 1) {
            aSerialNummer += String(UnicodeScalar(aData[n]))
        }
        
        // get Name in the received Information
        var aName: String = ""
        var cou = cof + 1
        while aData[cou] != 44 {
            cou += 1
        }
        for m in (cof + 1)...(cou - 1) {
            aName += String(UnicodeScalar(aData[m]))
        }
        
        // get Beschreibung in the Infromation
        var aBeschreibung: String = ""
        var con = cou + 1
        while aData[con] != 35 {
            con += 1
        }
        for o in (cou+1)...(con - 1) {
            aBeschreibung += String(UnicodeScalar(aData[o]))
        }
        
        // add this schloss to the Benutzer Object
        self.benutzer.addSchloss(withIndex: aIndex, andSerialNummer: aSerialNummer, andName: aName, andBeschreibung: aBeschreibung)
        self.benutzer.printSchloss()
        
    }
    
    func alert(msg:String, after:()->(Void)) {
        let alertController = UIAlertController(title: "", message: msg, preferredStyle: .alert)
        self.present(alertController, animated: true, completion: nil)
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.5) {
            alertController.dismiss(animated: false, completion: nil)
        }
    }


}

