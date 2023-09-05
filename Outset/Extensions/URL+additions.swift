//
//  URL+additions.swift
//  Outset
//
//  Created by Bart E Reardon on 5/9/2023.
//

import Foundation

extension URL {
    var isDirectory: Bool {
       (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
}
