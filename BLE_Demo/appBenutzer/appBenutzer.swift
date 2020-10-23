//
//  appBenutzer.swift
//  BLE_Demo
//
//  Created by Konstruktion on 30.07.18.
//  Copyright © 2018 EMKA Beschlagteile. All rights reserved.
//

import Foundation

class appBenutzer {
    var Benutzername: String = "No User"
    var schlossAnzahl: Int = -1
    var schlossList: [Schloss] = []
    
    
    func addSchloss(withIndex aIndex: String, andSerialNummer aSerialNummer: String, andName aName: String, andBeschreibung aBeschreibung: String){
        self.schlossAnzahl += 1
        var aSchloss = Schloss()
        aSchloss.index = aIndex
        aSchloss.serialNummer = aSerialNummer
        aSchloss.Name = aName
        aSchloss.Beschreibung = aBeschreibung
        
        schlossList += [aSchloss]
    }
    
    func printSchloss() {
        for aSchloss in self.schlossList {
            print("Index: \(aSchloss.index), SerialNummer: \(aSchloss.serialNummer), Name: \(aSchloss.Name), Beschreibung: \(aSchloss.Beschreibung)")
        }
    }
    
    func printBenutzer() {
        print("Benutzer: \(self.Benutzername) hat \(String(schlossAnzahl)) Schlössen, sind: ")
        self.printSchloss()
    }
    

}

struct Schloss {
    var index           : String = ""
    var serialNummer    : String = ""
    var Name            : String = ""
    var Beschreibung    : String = ""
}
