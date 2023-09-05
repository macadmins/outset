//
//  Data+additions.swift
//  Outset
//
//  Created by Bart E Reardon on 5/9/2023.
//

import Foundation
import CommonCrypto

extension Data {
    // extension to the Data class that lets us compute sha256
    func sha256() -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(count), &hash)
        }
        return Data(hash)
    }

    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}
