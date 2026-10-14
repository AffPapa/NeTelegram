import Foundation

public enum PhoneNumberInputResult: Equatable, Sendable {
    case accepted(String)
    case empty
    case invalidCharacters
    case invalidCountryCode
    case repeatedCountryCode
    case invalidLength
}

/// Separates the macOS region hint from an explicit country selection. A
/// locale suggestion can be shown in the UI, but never supplies a calling
/// code for national-number normalization until the user chooses a country.
public struct PhoneCountrySelectionState: Equatable, Sendable {
    public let suggestedRegionCode: String?
    public private(set) var selectedRegionCode: String?
    public private(set) var selectedCallingCode: String

    public init(suggestedRegionCode: String?) {
        self.suggestedRegionCode = suggestedRegionCode
        self.selectedRegionCode = nil
        self.selectedCallingCode = ""
    }

    public mutating func select(regionCode: String, callingCode: String) {
        selectedRegionCode = regionCode
        selectedCallingCode = callingCode
    }

    public mutating func clearSelection() {
        selectedRegionCode = nil
        selectedCallingCode = ""
    }
}

/// Conservative phone input normalization for TDLib's international phone field.
/// It never silently strips letters or guesses whether a country code was pasted.
public enum PhoneNumberInputPolicy {
    /// Controls whether the phone-entry action is currently available. A
    /// national number requires an explicitly selected country; an explicit
    /// international number can be entered even before the country catalog
    /// finishes loading.
    public static func canContinue(
        _ raw: String,
        selectedCallingCode: String,
        countryCatalogAvailable: Bool
    ) -> Bool {
        let input = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard countryCatalogAvailable || input.hasPrefix("+") else { return false }
        if case .accepted = validate(input, selectedCallingCode: selectedCallingCode) {
            return true
        }
        return false
    }

    public static func validate(_ raw: String, selectedCallingCode: String) -> PhoneNumberInputResult {
        let input = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return .empty }
        let isInternational = input.first == "+"
        let hasSelectedCallingCode = !selectedCallingCode.isEmpty
            && selectedCallingCode.allSatisfy({ $0.isASCII && $0.isNumber })
        guard isInternational || hasSelectedCallingCode else { return .invalidCountryCode }
        let body = isInternational ? String(input.dropFirst()) : input
        var digits = ""
        for character in body {
            if let value = character.wholeNumberValue, (0...9).contains(value) {
                digits.append(String(value))
            } else if character.isWhitespace || "().-".contains(character) {
                continue
            } else {
                return .invalidCharacters
            }
        }
        guard !digits.isEmpty else { return .empty }

        if !isInternational, digits.hasPrefix(selectedCallingCode), digits.count >= selectedCallingCode.count + 4 {
            return .repeatedCountryCode
        }
        let normalized = isInternational ? digits : selectedCallingCode + digits
        guard (4...15).contains(normalized.count) else { return .invalidLength }
        return .accepted("+" + normalized)
    }
}
