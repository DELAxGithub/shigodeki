//
//  EmailDisplayUtility.swift
//  shigodeki
//
//  Utility for filtering Apple private relay email addresses
//  Shared across all UI components that display email addresses
//

import Foundation

struct EmailDisplayUtility {
    /// Returns a displayable email address, filtering out Apple private relay addresses
    /// - Parameter rawEmail: The raw email address string
    /// - Returns: The email if displayable, nil if it should be hidden
    static func displayableEmail(_ rawEmail: String) -> String? {
        let email = rawEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else { return nil }
        
        let lowerEmail = email.lowercased()
        
        // Hide Apple ID private relay addresses
        if lowerEmail.contains("privaterelay.appleid") {
            return nil
        }
        
        return email
    }
    
    /// Returns true if the email should be displayed in UI components
    /// - Parameter rawEmail: The raw email address string
    /// - Returns: True if email should be shown, false if it should be hidden
    static func shouldDisplayEmail(_ rawEmail: String) -> Bool {
        return displayableEmail(rawEmail) != nil
    }
}