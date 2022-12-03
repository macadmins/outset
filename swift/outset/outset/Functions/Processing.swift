//
//  Processing.swift
//  outset
//
//  Created by Bart Reardon on 3/12/2022.
//

import Foundation

func process_items(_ path: String, delete_items : Bool=false, once : Bool=false, override : [String:Date] = [:]) {
    // Processes scripts/packages to run
    if !check_file_exists(path: path) {
        logger("\(path) does not exist. Exiting")
        exit(1)
    }
    
    var items_to_process : [String] = []
    var packages : [String] = []
    var scripts : [String] = []
    var profiles : [String] = []
    var runOnceDict : RunOncePlist = RunOncePlist()
    
    items_to_process = list_folder(path: path)
    
    for pathname in items_to_process {
        if check_permissions(pathname: pathname) {
            if ["pkg", "mpkg", "dmg"].contains(pathname.lowercased().suffix(3)) {
                packages.append(pathname)
            } else if pathname.lowercased().hasSuffix("mobileconfig") {
                profiles.append(pathname)
            } else {
                scripts.append(pathname)
            }
        } else {
            logger("Bad permissions: \(pathname)", status: "error")
        }
    }
    
    if once {
        runOnceDict = load_runonce(plist: run_once_plist)
    }
    
    for package in packages {
        if once {
            if !runOnceDict.override_login_once.contains(where: {$0.key == package}) {
                if install_package(pkg: package) {
                    runOnceDict.override_login_once.updateValue(Date(), forKey: package)
                }
            } else {
                if override.contains(where: {$0.key == package}) {
                    if override[package]! > runOnceDict.override_login_once[package]! {
                        if install_package(pkg: package) {
                            runOnceDict.override_login_once.updateValue(Date(), forKey: package)
                        }
                    }
                }
            }
        } else {
            _ = install_package(pkg: package)
        }
        if delete_items {
            path_cleanup(pathname: package)
        }
    }
    
    /*
    for profile in profiles {
        // NO PROFILE SUPPORT
    }
     */
    
    for script in scripts {
        if once {
            if !runOnceDict.override_login_once.contains(where: {$0.key == script}) {
                let (output, error, status) = shell(script)
                if status != 0 {
                    logger(error, status: "error")
                } else {
                    runOnceDict.override_login_once.updateValue(Date(), forKey: script)
                    logger(output)
                }
            } else {
                if override.contains(where: {$0.key == script}) {
                    if override[script]! > runOnceDict.override_login_once[script]! {
                        let (output, error, status) = shell(script)
                        if status != 0 {
                            logger(error, status: "error")
                        } else {
                            runOnceDict.override_login_once.updateValue(Date(), forKey: script)
                            if !output.isEmpty {
                                logger(output, status: "debug")
                            }
                        }
                    }
                }
            }
        } else {
            let (_, error, status) = shell(script)
            if status != 0 {
                logger(error, status: "error")
            }
        }
        if delete_items {
            path_cleanup(pathname: script)
        }
    }
    
    if !runOnceDict.override_login_once.isEmpty {
        logger("Writing login-once preference file: \(run_once_plist)", status: "debug")
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        do {
            let data = try encoder.encode(runOnceDict)
            try data.write(to: URL(fileURLWithPath: run_once_plist))
        } catch {
            logger("Writing to \(run_once_plist) failed", status: "error")
        }
    }
    
}


func install_package(pkg : String) -> Bool {
    // Installs pkg onto boot drive
    if is_root() {
        var pkg_to_install : String = ""
        var dmg_mount : String = ""
        
        if pkg.lowercased().hasSuffix("dmg") {
            dmg_mount = mount_dmg(dmg: pkg)
            for files in list_folder(path: dmg_mount) {
                if ["pkg", "mpkg"].contains(files.lowercased().suffix(3)) {
                    pkg_to_install = dmg_mount
                }
            }
        } else if ["pkg", "mpkg"].contains(pkg.lowercased().suffix(3)) {
            pkg_to_install = pkg
        }
        logger("Installing \(pkg_to_install)")
        let cmd = "/usr/sbin/installer -pkg \(pkg_to_install) -target /"
        let (output, error, status) = shell(cmd)
        if status != 0 {
            logger(error, status: "error")
        } else {
            logger(output)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5)) {
            if !dmg_mount.isEmpty {
                logger(detach_dmg(dmg_mount: dmg_mount))
            }
        }
        return true
    } else {
        logger("Unable to process \(pkg)", status: "warning")
        logger("Must be root to install packages", status: "warning")
    }
    return false
}

func install_profile(pathname : String) -> Bool {
    return false
}

