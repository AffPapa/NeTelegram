import Foundation

public enum PhoneNumberInputResult: Equatable, Sendable {
    case accepted(String)
    case empty
    case invalidCharacters
    case invalidCountryCode
    case repeatedCountryCode
    case invalidLength
}

/// Conservative phone input normalization for TDLib's international phone field.
/// It never silently strips letters or guesses whether a country code was pasted.
public enum PhoneNumberInputPolicy {
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
