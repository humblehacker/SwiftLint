//
//  ObjectLiteralRule.swift
//  SwiftLint
//
//  Created by Marcelo Fabri on 12/25/16.
//  Copyright © 2016 Realm. All rights reserved.
//

import Foundation
import SourceKittenFramework

public struct ObjectLiteralRule: ASTRule, ConfigurationProviderRule, OptInRule {

    public var configuration = SeverityConfiguration(.warning)

    public init() {}

    public static let description = RuleDescription(
        identifier: "object_literal",
        name: "Object Literal",
        description: "Prefer object literals over image and color inits.",
        nonTriggeringExamples: [
            "let image = #imageLiteral(resourceName: \"image.jpg\")",
            "let color = #colorLiteral(red: 0.9607843161, green: 0.7058823705, blue: 0.200000003, alpha: 1)",
            "let image = UIImage(named: aVariable)",
            "let image = UIImage(named: \"interpolated \\(variable)\")",
            "let color = UIColor(red: value, green: value, blue: value, alpha: 1)",
            "let image = NSImage(named: aVariable)",
            "let image = NSImage(named: \"interpolated \\(variable)\")",
            "let color = NSColor(red: value, green: value, blue: value, alpha: 1)"
        ],
        triggeringExamples: ["", ".init"].flatMap { (method: String) -> [String] in
            ["UI", "NS"].flatMap { (prefix: String) -> [String] in
                [
                    "let image = ↓\(prefix)Image\(method)(named: \"foo\")",
                    "let color = ↓\(prefix)Color\(method)(red: 0.3, green: 0.3, blue: 0.3, alpha: 1)",
                    "let color = ↓\(prefix)Color\(method)(red: 100 / 255.0, green: 50 / 255.0, blue: 0, alpha: 1)",
                    "let color = ↓\(prefix)Color\(method)(white: 0.5, alpha: 1)"
                ]
            }
        }
    )

    public func validateFile(_ file: File, kind: SwiftExpressionKind,
                             dictionary: [String : SourceKitRepresentable]) -> [StyleViolation] {
        guard kind == .call,
            let offset = (dictionary["key.offset"] as? Int64).flatMap({ Int($0) }),
            isImageNamedInit(dictionary, file: file) || isColorInit(dictionary, file: file) else {
            return []
        }

        return [
            StyleViolation(ruleDescription: type(of: self).description,
                           severity: configuration.severity,
                           location: Location(file: file, byteOffset: offset))
        ]
    }

    private func isImageNamedInit(_ dictionary: [String : SourceKitRepresentable], file: File) -> Bool {
        guard let name = dictionary["key.name"] as? String,
            initsForClasses(["UIImage", "NSImage"]).contains(name),
            case let arguments = dictionary.enclosedArguments,
            arguments.flatMap({ $0["key.name"] as? String }) == ["named"],
            let argument = arguments.first,
            case let kinds = kindsFor(argument, file: file),
            kinds == [.string] else {
                return false
        }

        return true
    }

    private func isColorInit(_ dictionary: [String : SourceKitRepresentable], file: File) -> Bool {
        guard let name = dictionary["key.name"] as? String,
            initsForClasses(["UIColor", "NSColor"]).contains(name),
            case let arguments = dictionary.enclosedArguments,
            case let argumentsNames = arguments.flatMap({ $0["key.name"] as? String }),
            argumentsNames == ["red", "green", "blue", "alpha"] || argumentsNames == ["white", "alpha"],
            validateColorKinds(arguments: arguments, file: file) else {
                return false
        }

        return true
    }

    private func initsForClasses(_ names: [String]) -> [String] {
        return names.flatMap { name in
            [
                name,
                name + ".init"
            ]
        }
    }

    private func validateColorKinds(arguments: [[String: SourceKitRepresentable]], file: File) -> Bool {
        for dictionary in arguments where kindsFor(dictionary, file: file) != [.number] {
            return false
        }

        return true
    }

    private func kindsFor(_ argument: [String: SourceKitRepresentable], file: File) -> Set<SyntaxKind> {
        guard let offset = (argument["key.bodyoffset"] as? Int64).flatMap({ Int($0) }),
            let length = (argument["key.bodylength"] as? Int64).flatMap({ Int($0) }) else {
                return Set()
        }

        let range = NSRange(location: offset, length: length)
        return Set(file.syntaxMap.tokensIn(range).flatMap({ SyntaxKind(rawValue: $0.type) }))
    }
}
