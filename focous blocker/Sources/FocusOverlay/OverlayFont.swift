import CoreText
import Foundation
import SwiftUI

enum OverlayFont {
    static let fallbackName = "Bitcount"
    private(set) static var resolvedName = fallbackName
    private static var didRegister = false

    static func registerIfNeeded() {
        guard !didRegister else { return }
        didRegister = true

        guard let url = Bundle.module.url(forResource: "Bitcount-Variable", withExtension: "ttf") else {
            return
        }

        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)

        if
            let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [[CFString: Any]],
            let first = descriptors.first,
            let postScriptName = first[kCTFontNameAttribute] as? String
        {
            resolvedName = postScriptName
        }
    }

    static func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(resolvedName, size: size).weight(weight)
    }
}
