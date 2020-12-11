import Foundation
import SwiftLintFramework

struct BuildTimeMetricsExtractor {
    private static let totalBuildTimeRegex = try! NSRegularExpression(pattern: #"\*\* BUILD \w+ \*\* \[([\d.]+) sec\]"#)
    private static let buildTimeMetricRegex = try! NSRegularExpression(pattern: #"^(\d*\.?\d*)ms\t(.+)\t(.*)"#)
    private static let locationRegex = try! NSRegularExpression(pattern: #"(.*):(\d+):(\d+)"#, options: [])

    static func getBuildTimeMetrics(compilerLogs: String) -> AllBuildTimeMetrics? {
        guard let totalBuildTime = getTotalBuildTime(compilerLogs) else {
            return nil
        }
        let items = getBuildTimeItems(compilerLogs)
        return AllBuildTimeMetrics(
            totalBuildTime: totalBuildTime,
            items: items
        )
    }
}

private extension BuildTimeMetricsExtractor {
    static func getBuildTimeItems(_ string: String) -> [File: Set<ExpressionBuildTime>] {
        let group = DispatchGroup()
        var storage: [File: Set<ExpressionBuildTime>] = [:]
        string.enumerateLines { line, _ in
            group.enter()
            DispatchQueue.global().async {
                guard let (file, expressionBuildTime) = findExpressionBuildTime(line: line) else {
                    group.leave()
                    return
                }
                DispatchQueue.main.async {
                    var existingExpressionBuildTimes = storage[file] ?? []
                    existingExpressionBuildTimes.insert(expressionBuildTime)
                    storage[file] = existingExpressionBuildTimes
                    group.leave()
                }
            }
        }
        group.wait()
        return storage
    }

    static func findExpressionBuildTime(line: String) -> (File, ExpressionBuildTime)? {
        guard let groupMatches = buildTimeMetricRegex.groupMatches(in: line) else {
            return nil
        }

        guard let timeString = groupMatches[safe: 0],
              let fileInfo = groupMatches[safe: 1],
              let expressionType = groupMatches[safe: 2] else {
            assertionFailure("This must never happen")
            return nil
        }

        guard let buildTime = TimeInterval(timeString) else {
            assertionFailure("This must never happen")
            return nil
        }

        guard let locationGroupMatches = locationRegex.groupMatches(in: fileInfo),
              let file = locationGroupMatches[safe: 0] else {
            // 0.04ms    <invalid loc>    getter hashValue
            return nil
        }

        let location = Location(
            file: file,
            line: locationGroupMatches[safe: 1].flatMap { Int($0) },
            character: locationGroupMatches[safe: 2].flatMap { Int($0) }
        )

        let expressionBuildTime = ExpressionBuildTime(
            buildTime: buildTime,
            location: location,
            expressionType: expressionType
        )
        return (file, expressionBuildTime)
    }

    static func getTotalBuildTime(_ string: String) -> TimeInterval? {
//        guard let indexOfLastLineBreak = string
//                .trimmingTrailingCharacters(in: .whitespacesAndNewlines)
//                .lastIndex(of: "\n") else {
//            return nil
//        }
//        let lastLine = String(string.suffix(from: indexOfLastLineBreak))
        // Apply regex on the last line and not on the full build log, for better performance
        guard let groupMatches = totalBuildTimeRegex.groupMatches(in: string),
              let totalBuildTimeString = groupMatches.first,
              let totalBuildTimeInSeconds = TimeInterval(totalBuildTimeString)
              else {
            return nil
        }

        return totalBuildTimeInSeconds * 1000
    }
}

extension Array {
    public subscript(safe index: Int) -> Element? {
        guard index >= 0, index < endIndex else {
            return nil
        }

        return self[index]
    }
}

private extension NSRegularExpression {
    func firstMatch(in text: String) -> String? {
        let result = matches(in: text, range: NSRange(text.startIndex..., in: text))
        return result.first.map {
            String(text[Range($0.range, in: text)!])
        }
    }

    func groupMatches(in text: String) -> [String]? {
        guard let match = matches(in: text, range: NSRange(text.startIndex..., in: text)).first else {
            return nil
        }

        return (1 ..< match.numberOfRanges).compactMap {
            let rangeBounds = match.range(at: $0)
            guard let range = Range(rangeBounds, in: text) else {
                return nil
            }
            return String(text[range])
        }
    }
}
