//
//  Properties.swift
//  outset
//
//  Created by Bart Reardon on 1/12/2022.
//

import Foundation

public extension Bundle {
    
    /**
     Gets the contents of the specified plist file.
     
     - parameter plistName: property list where defaults are declared
     - parameter bundle: bundle where defaults reside
     
     - returns: dictionary of values
     */
    static func contentsOfFile(plistName: String, bundle: Bundle? = nil) -> [String : AnyObject] {
        let fileParts = plistName.components(separatedBy: ".")
        
        guard fileParts.count == 2,
              let resourcePath = (bundle ?? Bundle.main).path(forResource: fileParts[0], ofType: fileParts[1]),
            let contents = NSDictionary(contentsOfFile: resourcePath) as? [String : AnyObject]
            else { return [:] }
        
        return contents
    }
    
    /**
     Gets the contents of the specified bundle URL.
     
     - parameter bundleURL: bundle URL where defaults reside
     - parameter plistName: property list where defaults are declared
     
     - returns: dictionary of values
     */
    static func contentsOfFile(bundleURL: NSURL, plistName: String = "Root.plist") -> [String : AnyObject] {
        // Extract plist file from bundle
        guard let contents = NSDictionary(contentsOf: bundleURL.appendingPathComponent(plistName)!)
            else { return [:] }
        
        // Collect default values
        guard let preferences = contents.value(forKey: "PreferenceSpecifiers") as? [String: AnyObject]
            else { return [:] }
        
        return preferences
    }
    
    /**
     Gets the contents of the specified bundle name.
     
     - parameter bundleName: bundle name where defaults reside
     - parameter plistName: property list where defaults are declared
     
     - returns: dictionary of values
     */
    static func contentsOfFile(bundleName: String, plistName: String = "Root.plist") -> [String : AnyObject] {
        guard let bundleURL = Bundle.main.url(forResource: bundleName, withExtension: "bundle")
            else { return [:] }
        
        return contentsOfFile(bundleURL: bundleURL as NSURL, plistName: plistName)
    }
    
    /**
     Gets the contents of the specified bundle.
     
     - parameter bundle: bundle where defaults reside
     - parameter bundleName: bundle name where defaults reside
     - parameter plistName: property list where defaults are declared
     
     - returns: dictionary of values
     */
    static func contentsOfFile(bundle: Bundle, bundleName: String = "Settings", plistName: String = "Root.plist") -> [String : AnyObject] {
        guard let bundleURL = bundle.url(forResource: bundleName, withExtension: "bundle")
            else { return [:] }
        
        return contentsOfFile(bundleURL: bundleURL as NSURL, plistName: plistName)
    }
    
}
