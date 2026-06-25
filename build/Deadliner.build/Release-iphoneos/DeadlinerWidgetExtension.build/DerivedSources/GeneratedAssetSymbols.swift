import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "create.tasks" asset catalog image resource.
    static let createTasks = DeveloperToolsSupport.ImageResource(name: "create.tasks", bundle: resourceBundle)

    /// The "has.near.tasks" asset catalog image resource.
    static let hasNearTasks = DeveloperToolsSupport.ImageResource(name: "has.near.tasks", bundle: resourceBundle)

    /// The "has.tasks" asset catalog image resource.
    static let hasTasks = DeveloperToolsSupport.ImageResource(name: "has.tasks", bundle: resourceBundle)

    /// The "lifi.logo.v1" asset catalog image resource.
    static let lifiLogoV1 = DeveloperToolsSupport.ImageResource(name: "lifi.logo.v1", bundle: resourceBundle)

    /// The "no.more.tasks" asset catalog image resource.
    static let noMoreTasks = DeveloperToolsSupport.ImageResource(name: "no.more.tasks", bundle: resourceBundle)

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    /// The "create.tasks" asset catalog image.
    static var createTasks: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .createTasks)
#else
        .init()
#endif
    }

    /// The "has.near.tasks" asset catalog image.
    static var hasNearTasks: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .hasNearTasks)
#else
        .init()
#endif
    }

    /// The "has.tasks" asset catalog image.
    static var hasTasks: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .hasTasks)
#else
        .init()
#endif
    }

    /// The "lifi.logo.v1" asset catalog image.
    static var lifiLogoV1: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .lifiLogoV1)
#else
        .init()
#endif
    }

    /// The "no.more.tasks" asset catalog image.
    static var noMoreTasks: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .noMoreTasks)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// The "create.tasks" asset catalog image.
    static var createTasks: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .createTasks)
#else
        .init()
#endif
    }

    /// The "has.near.tasks" asset catalog image.
    static var hasNearTasks: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .hasNearTasks)
#else
        .init()
#endif
    }

    /// The "has.tasks" asset catalog image.
    static var hasTasks: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .hasTasks)
#else
        .init()
#endif
    }

    /// The "lifi.logo.v1" asset catalog image.
    static var lifiLogoV1: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .lifiLogoV1)
#else
        .init()
#endif
    }

    /// The "no.more.tasks" asset catalog image.
    static var noMoreTasks: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .noMoreTasks)
#else
        .init()
#endif
    }

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

