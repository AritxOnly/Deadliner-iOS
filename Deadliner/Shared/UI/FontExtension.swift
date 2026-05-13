//
//  FontExtension.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/5/11.
//
import SwiftUI
import UIKit
import CoreText

public enum FontVariationAxis: Int, CustomStringConvertible {
    case weight = 2003265652      // wght
    case width = 2003072104       // wdth
    case opticalSize = 1869640570 // opsz
    case grad = 1196572996        // GRAD
    case slant = 1936486004       // slnt

    case xtra = 1481921089        // XTRA
    case xopq = 1481592913        // XOPQ
    case yopq = 1498370129        // YOPQ
    case ytlc = 1498696771        // YTLC
    case ytuc = 1498699075        // YTUC
    case ytas = 1498693971        // YTAS
    case ytde = 1498694725        // YTDE
    case ytfi = 1498695241        // YTFI

    public var description: String {
        switch self {
        case .weight: return "Weight"
        case .width: return "Width"
        case .opticalSize: return "Optical Size"
        case .grad: return "Grade"
        case .slant: return "Slant"
        case .xtra: return "XTRA"
        case .xopq: return "XOPQ"
        case .yopq: return "YOPQ"
        case .ytlc: return "YTLC"
        case .ytuc: return "YTUC"
        case .ytas: return "YTAS"
        case .ytde: return "YTDE"
        case .ytfi: return "YTFI"
        }
    }
}

public extension UIFont {
    static func variableFont(
        name: String,
        size: CGFloat,
        axes: [FontVariationAxis: Double] = [:]
    ) -> UIFont {
        let variationDict: [NSNumber: NSNumber] = Dictionary(
            uniqueKeysWithValues: axes.map {
                (NSNumber(value: $0.key.rawValue), NSNumber(value: $0.value))
            }
        )

        let descriptor = UIFontDescriptor(fontAttributes: [
            .name: name,
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): variationDict
        ])

        return UIFont(descriptor: descriptor, size: size)
    }
}

public extension Font {
    static func inter(
        _ size: CGFloat,
        axes: [FontVariationAxis: Double] = [:]
    ) -> Font {
        let uiFont = UIFont.variableFont(
            name: "Inter",
            size: size,
            axes: axes
        )

        return Font(uiFont)
    }
}
