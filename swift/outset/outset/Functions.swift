//
//  Functions.swift
//  outset
//
//  Created by Bart Reardon on 1/12/2022.
//

import Foundation

struct OutsetPreferences: Codable {
    var wait_for_network : Bool = false
    var network_timeout : Int = 180
    var ignored_users : [String] = []
    var override_login_once : [String : Date] = [:]
}

func ensure_working_folders() {
    let working_directories = [
        boot_every_dir,
        boot_once_dir,
        login_every_dir,
        login_once_dir,
        login_privileged_every_dir,
        login_privileged_once_dir,
        on_demand_dir,
        share_dir,
    ]
    
    for directory in working_directories {
        if !check_file_exists(path: directory, isDir: true) {
            //logging.info("%s does not exist, creating now.", directory)
            do {
                try FileManager.default.createDirectory(at: URL(filePath: directory), withIntermediateDirectories: true)
            } catch {
                print("could not create path at \(directory)")
            }
        }
    }
}

func dump_outset_preferences(prefs: OutsetPreferences) {
    //if check_file_exists(path: outset_preferences) {
        //logging.info("Initiating preference file: %s" % outset_preferences)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        do {
            let data = try encoder.encode(prefs)
            try data.write(to: URL(filePath: outset_preferences))
        } catch {
            print("encoding plist failed")
        }
    //}
}

func check_file_exists(path: String, isDir : ObjCBool = false) -> Bool {
    var checkIsDir : ObjCBool = isDir
    return FileManager.default.fileExists(atPath: path, isDirectory: &checkIsDir)
}

func list_folder(path: String) -> [String] {
    do {
        return try FileManager.default.contentsOfDirectory(atPath: path)
    } catch {
        return []
    }
}

func logger(_ log: String, status : String = "info") {
    print(log)
}
    
func load_outset_preferences() -> OutsetPreferences {
    var outsetPrefs = OutsetPreferences() // don't forget to change to var when you refactor this function
    if !check_file_exists(path: outset_preferences) {
        dump_outset_preferences(prefs: OutsetPreferences())
    }
    
    //let importedPrefs = NSDictionary(contentsOfFile: outset_preferences)
    
    //let userPrefs = PropertyListSerialization.propertyList(from: importedPrefs, format: OutsetPreferences) as! OutsetPreferences
    
    let url = URL(filePath: outset_preferences)
    do {
        let data = try Data(contentsOf: url)
        //let importedPrefs = try PropertyListSerialization.propertyList(from: data, format: nil)
        outsetPrefs = try PropertyListDecoder().decode(OutsetPreferences.self, from: data)
        //outsetPrefs = data.withUnsafeBytes { buffer in
        //    buffer.load(as: OutsetPreferences.self)
        //}
    } catch {
        print("plist import failed")
    }
    
    return outsetPrefs
}

func network_up() {
    
}

func wait_for_network(timeout : Double) -> Bool {
    return true
}

func disable_loginwindow() {
    
}

func enable_loginwindow() {
    
}

func get_hardwaremodel() {
    
}

func get_serialnumber() {
    
}

func get_buildversion() {
    
}

func get_osversion() {
    
}

func sys_report() {
    
}

func path_cleanup(pathname : String) {
    // check if folder and clean all files in that folder
}

func mount_dmg(dmg : String) {
    
}

func detach_dmg(dmg_mount : String) {
    
}

func check_perms(pathname : String) {
    
}

func install_package(pkg : String) {
    
}

func install_profile(pathname : String) {
    
}

func run_script(pathname : String) {
    
}

func process_items(_ path: String, delete_items : Bool=false, once : Bool=false, override : [String:Date] = [:]) {
    
}
