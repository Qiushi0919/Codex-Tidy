import Foundation

public struct ReleaseVersion: Comparable, Sendable {
    private let core: [Int]
    private let prerelease: [String]?

    public init?(_ rawValue: String) {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.lowercased().hasPrefix("v") {
            value.removeFirst()
        }
        value = String(value.split(separator: "+", maxSplits: 1, omittingEmptySubsequences: false)[0])

        let sections = value.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let parsedCore = sections[0].split(separator: ".").compactMap { Int($0) }
        guard !parsedCore.isEmpty, parsedCore.count == sections[0].split(separator: ".").count else { return nil }

        core = parsedCore
        if sections.count == 2, !sections[1].isEmpty {
            prerelease = sections[1].split(separator: ".").map(String.init)
        } else {
            prerelease = nil
        }
    }

    public static func < (lhs: ReleaseVersion, rhs: ReleaseVersion) -> Bool {
        let componentCount = max(lhs.core.count, rhs.core.count)
        for index in 0..<componentCount {
            let left = index < lhs.core.count ? lhs.core[index] : 0
            let right = index < rhs.core.count ? rhs.core[index] : 0
            if left != right { return left < right }
        }

        switch (lhs.prerelease, rhs.prerelease) {
        case (nil, nil):
            return false
        case (nil, _):
            return false
        case (_, nil):
            return true
        case let (left?, right?):
            return prereleaseIsLess(left, than: right)
        }
    }

    private static func prereleaseIsLess(_ lhs: [String], than rhs: [String]) -> Bool {
        for index in 0..<max(lhs.count, rhs.count) {
            guard index < lhs.count else { return true }
            guard index < rhs.count else { return false }

            let left = lhs[index]
            let right = rhs[index]
            if left == right { continue }

            switch (Int(left), Int(right)) {
            case let (leftNumber?, rightNumber?):
                return leftNumber < rightNumber
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return left.localizedStandardCompare(right) == .orderedAscending
            }
        }
        return false
    }
}
