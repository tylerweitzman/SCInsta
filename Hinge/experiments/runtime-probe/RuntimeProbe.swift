import Foundation
import UIKit
import ObjectiveC.runtime

// Development-only, read-only inspection. Loaded explicitly by LLDB, never by the tweak.
@objc(HingeRuntimeProbe)
final class RuntimeProbe: NSObject {
    private static func fields(_ value: Any) -> [(String, Any)] {
        var result: [(String, Any)] = []
        var mirror: Mirror? = Mirror(reflecting: value)
        while let current = mirror {
            result += current.children.enumerated().map { ($0.element.label ?? String($0.offset), $0.element.value) }
            mirror = current.superclassMirror
        }
        return result
    }

    private static func unwrap(_ value: Any) -> Any {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional, let child = mirror.children.first {
            return unwrap(child.value)
        }
        return value
    }

    private static func controllers() -> [UIViewController] {
        var result: [UIViewController] = []
        var seen = Set<ObjectIdentifier>()
        func visit(_ vc: UIViewController) {
            guard seen.insert(ObjectIdentifier(vc)).inserted else { return }
            result.append(vc)
            vc.children.forEach(visit)
            if let presented = vc.presentedViewController { visit(presented) }
        }
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }.compactMap { $0.rootViewController }.forEach(visit)
        return result
    }

    private static func resolve(_ path: String) -> Any? {
        let parts = path.split(separator: "/").map(String.init)
        guard let first = parts.first,
              let root = controllers().first(where: { NSStringFromClass(type(of: $0)) == first }) else { return nil }
        var value: Any = root
        for part in parts.dropFirst() {
            value = unwrap(value)
            if let index = Int(part), Mirror(reflecting: value).displayStyle == .collection {
                let children = Array(Mirror(reflecting: value).children)
                guard children.indices.contains(index) else { return nil }
                value = children[index].value
            } else {
                guard let field = fields(value).first(where: { $0.0 == part }) else { return nil }
                value = field.1
            }
        }
        return unwrap(value)
    }

    private static func describe(_ value: Any, depth: Int) -> [String: Any] {
        let value = unwrap(value)
        let mirror = Mirror(reflecting: value)
        var result: [String: Any] = ["type": String(reflecting: type(of: value)),
                                    "style": mirror.displayStyle.map { String(describing: $0) } ?? "scalar"]
        if let string = value as? String { result["stringLength"] = string.count; return result }
        if mirror.displayStyle == .class {
            result["address"] = String(describing: Unmanaged.passUnretained(value as AnyObject).toOpaque())
        }
        let children = fields(value)
        result["fieldCount"] = children.count
        if depth > 0 {
            result["fields"] = children.prefix(80).map { name, child in
                ["name": name, "value": describe(child, depth: depth - 1)] as [String: Any]
            }
        }
        return result
    }

    private static func json(_ value: Any) -> NSString {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return "{\"error\":\"serialization failed\"}" }
        return text as NSString
    }

    @objc static func inventory() -> NSString {
        let names = ["Hinge.DiscoveryParentViewController", "Hinge.DiscoveryParentPresenter",
                     "Hinge.DiscoveryProfileViewController", "Hinge.DiscoveryProfilePresenter",
                     "Hinge.DiscoveryInteractor", "Hinge.DiscoveryWireframe", "Hinge.Potential",
                     "Hinge.UserProfile", "RecommendationsCore.RecommendationsRepository",
                     "RecommendationsCore.RecommendationFeed", "RatingsCore.RatingsRepository",
                     "UserProfileCore.UserProfileRepository", "Networking.Network"]
        let classes: [[String: Any]] = names.map { name in
            guard let cls = NSClassFromString(name) else { return ["name": name, "exists": false] }
            var count: UInt32 = 0
            let methods = class_copyMethodList(cls, &count)
            defer { free(methods) }
            let entries: [[String: String]] = (0..<Int(count)).compactMap { index in
                guard let method = methods?[index] else { return nil }
                return ["selector": NSStringFromSelector(method_getName(method)),
                        "encoding": method_getTypeEncoding(method).map(String.init(cString:)) ?? "",
                        "implementation": String(describing: method_getImplementation(method))]
            }
            return ["name": name, "exists": true, "methods": entries]
        }
        return json(["classes": classes, "controllers": controllers().map {
            ["class": NSStringFromClass(type(of: $0)), "viewLoaded": $0.isViewLoaded,
             "children": $0.children.map { NSStringFromClass(type(of: $0)) }]
        }, "bundleVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "",
                    "bundleBuild": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") ?? ""])
    }

    @objc(inspectPath:depth:)
    static func inspect(path: String, depth: Int) -> NSString {
        guard let value = resolve(path) else { return json(["path": path, "error": "path not found"]) }
        return json(["path": path, "value": describe(value, depth: min(max(depth, 0), 4))])
    }
}
