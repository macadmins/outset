//
//  Network.swift
//  Outset
//
//  Created by Bart E Reardon on 5/9/2023.
//

import Foundation
import SystemConfiguration

func isNetworkUp() -> Bool {
    // https://stackoverflow.com/a/39782859/17584669
    // perform a check to see if the network is available.

    var zeroAddress = sockaddr_in(sin_len: 0, sin_family: 0, sin_port: 0, sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
    zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
    zeroAddress.sin_family = sa_family_t(AF_INET)

    let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
            SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
        }
    }

    var flags: SCNetworkReachabilityFlags = SCNetworkReachabilityFlags(rawValue: 0)
    if SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) == false {
        return false
    }

    let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
    let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
    let ret = (isReachable && !needsConnection)

    return ret
}

func waitForNetworkUp(timeout: Double) -> Bool {
    // used during --boot if "wait_for_network" prefrence is true
    var networkUp = false
    let deadline = DispatchTime.now() + timeout
    while !networkUp && DispatchTime.now() < deadline {
        writeLog("Waiting for network: \(timeout) seconds", logLevel: .debug)
        networkUp = isNetworkUp()
        if !networkUp {
            writeLog("Waiting...", logLevel: .debug)
            Thread.sleep(forTimeInterval: 1)
        }
    }
    if !networkUp && DispatchTime.now() > deadline {
        writeLog("No network connectivity detected after \(timeout) seconds", logLevel: .error)
    }
    return networkUp
}
