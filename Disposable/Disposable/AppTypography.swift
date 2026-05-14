//
//  AppTypography.swift
//  Disposable
//

import SwiftUI
import UIKit

enum AppFontWeight {
    case regular
    case medium
    case bold
    case black
    case italic

    var postScriptName: String {
        switch self {
        case .regular: return "Satoshi-Regular"
        case .medium: return "Satoshi-Medium"
        case .bold: return "Satoshi-Bold"
        case .black: return "Satoshi-Black"
        case .italic: return "Satoshi-Italic"
        }
    }

    var systemWeight: Font.Weight {
        switch self {
        case .regular, .italic: return .regular
        case .medium: return .medium
        case .bold: return .bold
        case .black: return .black
        }
    }

    var uiSystemWeight: UIFont.Weight {
        switch self {
        case .regular, .italic: return .regular
        case .medium: return .medium
        case .bold: return .bold
        case .black: return .black
        }
    }
}

extension Font {
    static func satoshi(size: CGFloat, weight: AppFontWeight = .regular) -> Font {
        .custom(weight.postScriptName, size: size)
    }

    static func satoshi(_ style: TextStyle, weight: AppFontWeight = .regular) -> Font {
        .custom(weight.postScriptName, size: style.defaultPointSize, relativeTo: style)
    }

    static func appTitle() -> Font {
        .satoshi(size: 30, weight: .black)
    }

    static func appButton() -> Font {
        .satoshi(size: 18, weight: .black)
    }
}

extension UIFont {
    static func satoshi(size: CGFloat, weight: AppFontWeight = .regular) -> UIFont {
        UIFont(name: weight.postScriptName, size: size) ?? .systemFont(ofSize: size, weight: weight.uiSystemWeight)
    }
}

private extension Font.TextStyle {
    var defaultPointSize: CGFloat {
        switch self {
        case .largeTitle: return 34
        case .title: return 28
        case .title2: return 22
        case .title3: return 20
        case .headline: return 17
        case .body: return 17
        case .callout: return 16
        case .subheadline: return 15
        case .footnote: return 13
        case .caption: return 12
        case .caption2: return 11
        @unknown default: return 17
        }
    }
}
