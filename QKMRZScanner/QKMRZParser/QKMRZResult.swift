//
//  QKMRZResult.swift
//  QKMRZParser
//
//  Created by Matej Dorcak on 14/10/2018.
//

import Foundation

public struct QKMRZResult {
    
    public let documentType: String
    public let countryCode: String
    public let surnames: String
    public let givenNames: String
    public let documentNumber: String
    public let nationalityCountryCode: String
    public let birthdate: Date? // `nil` if formatting failed
    public let sex: String? // `nil` if formatting failed
    public let expiryDate: Date? // `nil` if formatting failed
    public let personalNumber: String
    public let personalNumber2: String? // `nil` if not provided
    public var mrzCode: [String]
    
    public let isDocumentNumberValid: Bool
    public let isBirthdateValid: Bool
    public let isExpiryDateValid: Bool
    public let isPersonalNumberValid: Bool?
    public let allCheckDigitsValid: Bool
    
    public static func == (lhs: QKMRZResult, rhs: QKMRZResult) -> Bool {
        if lhs.documentType == lhs.documentType &&
            lhs.countryCode == lhs.countryCode &&
            lhs.surnames == lhs.surnames &&
            lhs.givenNames == lhs.givenNames &&
            lhs.documentNumber == lhs.documentNumber &&
            lhs.nationalityCountryCode == lhs.nationalityCountryCode &&
            lhs.birthdate == lhs.birthdate &&
            lhs.sex == lhs.sex &&
            lhs.expiryDate == lhs.expiryDate &&
            lhs.personalNumber == lhs.personalNumber &&
            lhs.personalNumber2 == lhs.personalNumber2 &&
            lhs.mrzCode == lhs.mrzCode
            {
            return true
        }
        return false
    }
}
