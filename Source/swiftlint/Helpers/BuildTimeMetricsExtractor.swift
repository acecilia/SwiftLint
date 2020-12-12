import Foundation
import SwiftLintFramework
import Commandant

extension BuildTimeMetricsExtractor {
    enum Error: Swift.Error {
        case totalBuildTimeNotFound
        case unexpectedExpressionBuildTime(line: String)
        case unexpectedFileLocation(line: String)
    }
}

final class BuildTimeMetricsExtractor {
    private let compilerLogs: String
    private (set) lazy var allBuildTimeMetrics = try? Self.getBuildTimeMetrics(compilerLogs: compilerLogs).get()

    init(compilerLogs: String) {
        self.compilerLogs = compilerLogs
    }

    func buildTimeMetricts(forFile path: String?) -> BuildTimeMetrics? {
        guard let path = path else {
            return nil
        }

        guard let allBuildTimeMetrics = allBuildTimeMetrics else {
            return nil
        }

        return BuildTimeMetrics(
            totalBuildTime: allBuildTimeMetrics.totalBuildTime,
            expressionsBuildTime: Array(allBuildTimeMetrics.items[path] ?? [])
        )
    }
}

private extension BuildTimeMetricsExtractor {
    static let totalBuildTimeRegex = try! NSRegularExpression(pattern: #"\*\* BUILD \w+ \*\* \[([\d.]+) sec\]"#)
    static let buildTimeMetricRegex = try! NSRegularExpression(pattern: #"^(\d*\.?\d*)ms\t(.+)\t(.*)"#)
    static let locationRegex = try! NSRegularExpression(pattern: #"(.*):(\d+):(\d+)"#)

    static func getBuildTimeMetrics(compilerLogs: String) -> Result<AllBuildTimeMetrics, CommandantError<Swift.Error>> {
        do {
            let totalBuildTime = try getTotalBuildTime(compilerLogs)
            let items = getBuildTimeItems(compilerLogs)
            let allBuildTimeMetrics = AllBuildTimeMetrics(
                totalBuildTime: totalBuildTime,
                items: items
            )
            return .success(allBuildTimeMetrics)
        } catch {
            return .failure(.commandError(error))
        }
    }

    static func getBuildTimeItems(_ string: String) -> [File: Set<ExpressionBuildTime>] {
        let storage = ConcurrentLineExtractor.extract(string: string, extractOperation: extractExpressionBuildTime)
        return storage
    }

    static func extractExpressionBuildTime(line: String) throws -> (File, ExpressionBuildTime)? {
        guard let groupMatches = buildTimeMetricRegex.groupMatches(in: line) else {
            // This line does not contain built time metrics
            return nil
        }

        guard let timeString = groupMatches[safe: 0],
              let fileInfo = groupMatches[safe: 1],
              let expressionType = groupMatches[safe: 2] else {
            fatalError("This must never happen: if the regex matched, then all this groups must be found")
        }

        guard let buildTime = TimeInterval(timeString) else {
            throw BuildTimeMetricsExtractor.Error.unexpectedExpressionBuildTime(line: line)
        }

        guard let locationGroupMatches = locationRegex.groupMatches(in: fileInfo) else {
            // Here we get rid of time metrics with invalid localizations. For exmaple:
            // 0.04ms    <invalid loc>    getter hashValue
            return nil
        }

        guard let file = locationGroupMatches[safe: 0],
              let lineString = locationGroupMatches[safe: 1],
              let characterString = locationGroupMatches[safe: 2] else {
            fatalError("This must never happen: if the regex matched, then all this groups must be found")
        }

        guard let lineNumber = Int(lineString), let characterNumber = Int(characterString) else {
            throw BuildTimeMetricsExtractor.Error.unexpectedFileLocation(line: line)
        }

        let location = Location(file: file, line: lineNumber, character: characterNumber)
        let expressionBuildTime = ExpressionBuildTime(
            buildTime: buildTime,
            location: location,
            expressionType: expressionType
        )
        return (file, expressionBuildTime)
    }

    static func getTotalBuildTime(_ string: String) throws -> TimeInterval {
        guard let groupMatches = totalBuildTimeRegex.groupMatches(in: string),
              let totalBuildTimeString = groupMatches.first,
              let totalBuildTimeInSeconds = TimeInterval(totalBuildTimeString)
              else {
            throw BuildTimeMetricsExtractor.Error.totalBuildTimeNotFound
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
    func groupMatches(in text: String) -> [String]? {
        guard let match = matches(in: text, range: NSRange(text.startIndex..., in: text)).first else {
            return nil
        }

        return (1 ..< match.numberOfRanges).map {
            let rangeBounds = match.range(at: $0)
            let range = Range(rangeBounds, in: text)!
            return String(text[range])
        }
    }
}
