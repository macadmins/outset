//
//  String+additions.swift
//  Outset
//
//  Created by Bart E Reardon on 5/9/2023.
//

import Foundation

extension String {
    func camelCaseToUnderscored() -> String {
        let regex = try? NSRegularExpression(pattern: "([a-z])([A-Z])", options: [])
        let range = NSRange(location: 0, length: utf16.count)
        return regex?.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "$1_$2").lowercased() ?? self
    }
}

func getValueForKey(_ key: String, inArray array: [String: String]) -> String? {
    // short function that treats a [String: String] as a key value pair.
    return array[key]
}
