//
//  Regex.swift
//  MRZScanner
//
//  Created by Dmitriy Nikolin on 03.09.2020.
//  Copyright © 2020 dnikolin. All rights reserved.
//

import Foundation

extension NSRegularExpression {
    func matches(_ string: String) -> Bool {
        let range = NSRange(location: 0, length: string.utf16.count)
        return firstMatch(in: string, options: [], range: range) != nil
    }
}
