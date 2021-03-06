//
//  MRZFieldFormatter.swift
//  QKMRZParser
//
//  Created by Matej Dorcak on 14/10/2018.
//

import Foundation

class MRZFieldFormatter {
    let ocrCorrection: Bool
    
    fileprivate let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "GMT+0:00")
        return formatter
    }()
    
    init(ocrCorrection: Bool) {
        self.ocrCorrection = ocrCorrection
    }
    
    // MARK: Main
    func field(_ fieldType: MRZFieldType, from string: inout String, at startIndex: Int, length: Int, checkDigitFollows: Bool = false, isCountryHaveRules: String? = nil) -> MRZField {
        let endIndex = (startIndex + length)
        var rawValue = string.substring(startIndex, to: (endIndex - 1))
        let checkDigit = checkDigitFollows ? replaceLetters(in: string.substring(endIndex, to: endIndex)) : nil
        
        if ocrCorrection {
            rawValue = correct(rawValue, fieldType: fieldType)
            let startIndex = string.index(string.startIndex, offsetBy: startIndex)
            var endIndex = string.index(startIndex, offsetBy: length-1)
            var caractersArray = Array(rawValue)
            if checkDigit != nil {
                caractersArray.append(contentsOf: Array(checkDigit!))
                endIndex = string.index(startIndex, offsetBy: length)
            }
            string.replaceSubrange(startIndex...endIndex, with: caractersArray)
            
        }
        if isCountryHaveRules != nil && fieldType == .documentNumber {
            rawValue = correctForCountry(rawValue, countryCode: isCountryHaveRules!)
            let startIndex = string.index(string.startIndex, offsetBy: startIndex)
            let endIndex = string.index(startIndex, offsetBy: length)
            string.replaceSubrange(startIndex..<endIndex, with: Array(rawValue))
        }
        if isCountryHaveRules != nil && (fieldType == .personalNumber) {
            rawValue = correctForCountryPersonalNumber(rawValue, countryCode: isCountryHaveRules!)
            let startIndex = string.index(string.startIndex, offsetBy: startIndex)
            let endIndex = string.index(startIndex, offsetBy: length)
            string.replaceSubrange(startIndex..<endIndex, with: Array(rawValue))
        }
        
        var finalField = MRZField(value: format(rawValue, as: fieldType), rawValue: rawValue, checkDigit: checkDigit)
        if (fieldType == .personalNumber) && !(finalField.isValid ?? false) {
            rawValue = rawValue.replace("O", with: "0")
            let startIndex = string.index(string.startIndex, offsetBy: startIndex)
            let endIndex = string.index(startIndex, offsetBy: length)
            string.replaceSubrange(startIndex..<endIndex, with: Array(rawValue))
            finalField = MRZField(value: format(rawValue, as: fieldType), rawValue: rawValue, checkDigit: checkDigit)
        }
        
        if (fieldType == .documentNumber && !(finalField.isValid ?? false)) {
            rawValue = correctDocumtnNumberBruteForce(docNumber: rawValue, checkDigit: checkDigit!)
            let startIndex = string.index(string.startIndex, offsetBy: startIndex)
            let endIndex = string.index(startIndex, offsetBy: length)
            string.replaceSubrange(startIndex..<endIndex, with: Array(rawValue))
            finalField = MRZField(value: format(rawValue, as: fieldType), rawValue: rawValue, checkDigit: checkDigit)
        }
        
        return finalField
    }
    
    func format(_ string: String, as fieldType: MRZFieldType) -> Any? {
        switch fieldType {
        case .names:
            return names(from: string)
        case .birthdate:
            return birthdate(from: string)
        case .sex:
            return sex(from: string)
        case .expiryDate:
            return expiryDate(from: string)
        case .documentType, .documentNumber, .countryCode, .nationality, .personalNumber, .optionalData, .hash:
            return text(from: string)
        }
    }
    
    func correct(_ string: String, fieldType: MRZFieldType) -> String {
        switch fieldType {
        case .birthdate, .expiryDate, .hash:
            return replaceLetters(in: string)
        case .names, .documentType:
            return replaceDigits(in: string)
        case .sex:
            return string.replace("P", with: "F")
        case .countryCode, .nationality:
            return string.replace("0", with: "D")
        default:
            return string
        }
    }
    func correctForCountryPersonalNumber(_ string: String, countryCode: String) -> String {
        if countryCode == "NLD" {
            return replaceLetters(in: string)
        }
        return string
    }
    func correctForCountry(_ string: String, countryCode: String) -> String {
        let cCode = countryCode.replace("<", with: "")
        if cCode == "NLD" || cCode == "D" {
            return string.replace("O", with: "0")
        }
        return string
    }
    // MARK: Value Formatters
    private func names(from string: String) -> (primary: String, secondary: String) {
        let identifiers = string.trimmingFillers().components(separatedBy: "<<").map({ $0.replace("<", with: " ") })
        let secondaryID = identifiers.indices.contains(1) ? identifiers[1] : ""
        return (primary: identifiers[0], secondary: secondaryID)
    }
    
    private func sex(from string: String) -> String? {
        switch string {
        case "M": return "M"
        case "F": return "F"
        case "X": return "X"
        case "<": return "UNSPECIFIED" // X
        default: return nil
        }
    }
    
    private func birthdate(from string: String) -> Date? {
        guard CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: string)) else {
            return nil
        }
        
        let currentYear = Calendar.current.component(.year, from: Date()) - 2000
        let parsedYear = Int(string.substring(0, to: 1))!
        let centennial = (parsedYear > currentYear) ? "19" : "20"
        
        return dateFormatter.date(from: centennial + string)
    }
    
    private func expiryDate(from string: String) -> Date? {
        guard CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: string)) else {
            return nil
        }
        
        let parsedYear = Int(string.substring(0, to: 1))!
        let centennial = (parsedYear >= 70) ? "19" : "20"
        
        return dateFormatter.date(from: centennial + string)
    }
    
    private func text(from string: String) -> String {
        return string.trimmingFillers().replace("<", with: " ")
    }
    
    // MARK: Utils
    private func replaceDigits(in string: String) -> String {
        return string
            .replace("0", with: "O")
            .replace("1", with: "I")
            .replace("2", with: "Z")
            .replace("3", with: "B")
            .replace("8", with: "B")
            .replace("5", with: "S")
    }
    
    private func replaceLetters(in string: String) -> String {
        return string
            .replace("O", with: "0")
            .replace("Q", with: "0")
            .replace("U", with: "0")
            .replace("D", with: "0")
            .replace("I", with: "1")
            .replace("Z", with: "2")
            .replace("B", with: "8")
            .replace("S", with: "5")
    }
    
    private func correctDocumtnNumberBruteForce(docNumber: String, checkDigit: String) -> String {
        
        let charsArray = Array(docNumber)
        let ziroOcount = charsArray.reduce(0, { (result, char) in
            if char == "0" || char == "O" {
                return result + 1
            }
            return result
        })
        
        let allVariants = permutationsWithRepetitionFrom(["0", "O"], taking: ziroOcount)
        
        var stringToValidate = ""
        var indexChar = 0
        
        for variant in allVariants {
            stringToValidate = ""
            indexChar = 0
            for char in charsArray {
                if char == "0" || char == "O" {
                    stringToValidate.append(variant[indexChar])
                    indexChar += 1
                }
                else {
                    stringToValidate.append(char)
                }
            }
        
            if MRZField.isValueValid(stringToValidate, checkDigit: checkDigit) {
                return stringToValidate
            }
        }
        
        return docNumber
    }
    private func permutationsWithRepetitionFrom<T>(_ elements: [T], taking: Int) -> [[T]] {
        guard elements.count >= 0 && taking > 0 else { return [[]] }
        
        if taking == 1 {
            return elements.map {[$0]}
        }
        
        var permutations = [[T]]()
        for element in elements {
            permutations += permutationsWithRepetitionFrom(elements, taking: taking - 1).map {[element] + $0}
        }
        
        return permutations
    }
    
}
