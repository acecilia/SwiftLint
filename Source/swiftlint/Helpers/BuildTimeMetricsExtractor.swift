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
        var storage: [File: Set<ExpressionBuildTime>] = [:]
        string.enumerateLines { line, _ in
            guard let groupMatches = buildTimeMetricRegex.groupMatches(in: line) else {
                return
            }

            guard let timeString = groupMatches[safe: 0],
                  let fileInfo = groupMatches[safe: 1],
                  let expressionType = groupMatches[safe: 2] else {
                assertionFailure("This must never happen")
                return
            }

            guard let buildTime = TimeInterval(timeString) else {
                assertionFailure("This must never happen")
                return
            }

            guard let locationGroupMatches = locationRegex.groupMatches(in: fileInfo),
                  let file = locationGroupMatches[safe: 0] else {
                // 0.04ms    <invalid loc>    getter hashValue
                return
            }

            let location = Location(
                file: file,
                line: locationGroupMatches[safe: 1].flatMap { Int($0) },
                character: locationGroupMatches[safe: 2].flatMap { Int($0) }
            )


            let expressionBuildTime = ExpressionBuildTime(buildTime: buildTime, location: location, expressionType: expressionType)
            var existingExpressionBuildTimes = storage[file] ?? []
            existingExpressionBuildTimes.insert(expressionBuildTime)
            storage[file] = existingExpressionBuildTimes
        }

        return storage
    }

    static func getTotalBuildTime(_ string: String) -> TimeInterval? {
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
