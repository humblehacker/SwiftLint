//
//  CyclomaticComplexityRule.swift
//  SwiftLint
//
//  Created by Denis Lebedev on 24/1/16.
//  Copyright © 2016 Realm. All rights reserved.
//

import Foundation
import SourceKittenFramework

public struct CyclomaticComplexityRule: ASTRule, ConfigurationProviderRule {
    public var configuration = SeverityLevelsConfiguration(warning: 10, error: 20)

    public init() {}

    public static let description = RuleDescription(
        identifier: "cyclomatic_complexity",
        name: "Cyclomatic Complexity",
        description: "Complexity of function bodies should be limited.",
        nonTriggeringExamples: [
            "func f1() {\nif true {\nfor _ in 1..5 { } }\nif false { }\n}",
            "func f(code: Int) -> Int {" +
                "switch code {\n case 0: fallthrough\ncase 0: return 1\ncase 0: return 1\n" +
                "case 0: return 1\ncase 0: return 1\ncase 0: return 1\ncase 0: return 1\n" +
                "case 0: return 1\ncase 0: return 1\ndefault: return 1}}",
            "func f1() {" +
            "if true {}; if true {}; if true {}; if true {}; if true {}; if true {}\n" +
                "func f2() {\n" +
                    "if true {}; if true {}; if true {}; if true {}; if true {}\n" +
                "}}"
        ],
        triggeringExamples: [
            "↓func f1() {\n  if true {\n    if true {\n      if false {}\n    }\n" +
                "  }\n  if false {}\n  let i = 0\n\n  switch i {\n  case 1: break\n" +
                "  case 2: break\n  case 3: break\n  case 4: break\n default: break\n  }\n" +
                "  for _ in 1...5 {\n    guard true else {\n      return\n    }\n  }\n}\n"
        ]
    )

    public func validateFile(_ file: File, kind: SwiftDeclarationKind,
                             dictionary: [String: SourceKitRepresentable]) -> [StyleViolation] {
        if !SwiftDeclarationKind.functionKinds().contains(kind) {
            return []
        }

        let complexity = measureComplexity(file, dictionary: dictionary)

        for parameter in configuration.params where complexity > parameter.value {
            let offset = Int(dictionary["key.offset"] as? Int64 ?? 0)
            return [StyleViolation(ruleDescription: type(of: self).description,
                severity: parameter.severity,
                location: Location(file: file, byteOffset: offset),
                reason: "Function should have complexity \(configuration.warning) or less: " +
                        "currently complexity equals \(complexity)")]
        }

        return []
    }

    private func measureComplexity(_ file: File,
                                   dictionary: [String: SourceKitRepresentable]) -> Int {
        var hasSwitchStatements = false

        let complexity = dictionary.substructure.reduce(0) { complexity, subDict in
            guard let kind = subDict["key.kind"] as? String else {
                return complexity
            }

            if let declarationKind = SwiftDeclarationKind(rawValue: kind),
                SwiftDeclarationKind.functionKinds().contains(declarationKind) {
                return complexity
            }

            guard let statementKind = StatementKind(rawValue: kind) else {
                return complexity + measureComplexity(file, dictionary: subDict)
            }

            if statementKind == .switch {
                hasSwitchStatements = true
            }

            return complexity +
                (complexityStatements.contains(statementKind) ? 1 : 0) +
                measureComplexity(file, dictionary: subDict)
        }

        if hasSwitchStatements {
            return reduceSwitchComplexity(complexity, file: file, dictionary: dictionary)
        }

        return complexity
    }

    // Switch complexity is reduced by `fallthrough` cases

    private func reduceSwitchComplexity(_ complexity: Int, file: File,
                                        dictionary: [String: SourceKitRepresentable]) -> Int {
        let bodyOffset = Int(dictionary["key.bodyoffset"] as? Int64 ?? 0)
        let bodyLength = Int(dictionary["key.bodylength"] as? Int64 ?? 0)

        let c = file.contents.bridge()
            .substringWithByteRange(start: bodyOffset, length: bodyLength) ?? ""

        let fallthroughCount = c.components(separatedBy: "fallthrough").count - 1
        return complexity - fallthroughCount
    }

    private let complexityStatements: [StatementKind] = [
        .forEach,
        .if,
        .case,
        .guard,
        .for,
        .repeatWhile,
        .while
    ]

}
