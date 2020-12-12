import Foundation
import SourceKittenFramework

public struct BuildTimeRule: ConfigurationProviderRule, AnalyzerRule, AutomaticTestableRule {
    public var configuration = SeverityConfiguration(.warning)

    public init() {}

    public static let description = RuleDescription(
        identifier: "build_time",
        name: "Build Time",
        description: "Build time should be under a reasonable value",
        kind: .performance,
        nonTriggeringExamples: [],
        triggeringExamples: [],
        requiresFileOnDisk: true
    )

    public func validate(file: SwiftLintFile, additionalInfo: AdditionalInfo) -> [StyleViolation] {
        guard let buildTimeMetrics = additionalInfo.buildTimeMetrics else {
            return []
        }

        let adjustedTotalBuildTime = buildTimeMetrics.totalBuildTime / 100

        return buildTimeMetrics.expressionsBuildTime.compactMap {
            let percentage = $0.buildTime / adjustedTotalBuildTime
            guard percentage > 0.2 else {
                return nil
            }

            return StyleViolation(
                ruleDescription: Self.description,
                severity: configuration.severity,
                location: $0.location,
                reason: "Build time was \($0.buildTime)ms - \(buildTimeMetrics.totalBuildTime)ms - (\(String(format: "%.3f", percentage))%)"
            )
        }
    }
}