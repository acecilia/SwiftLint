import Foundation

public struct AdditionalInfo: Equatable {
    let compilerArguments: [String]
    @LazyWrapper private(set) var buildTimeMetrics: BuildTimeMetrics?

    public init(
        compilerArguments: [String],
        buildTimeMetrics: @autoclosure @escaping () -> BuildTimeMetrics?
    ) {
        self.compilerArguments = compilerArguments
        self._buildTimeMetrics = .init(wrappedValue: buildTimeMetrics())
    }

    public static var empty: AdditionalInfo {
        return AdditionalInfo(compilerArguments: [], buildTimeMetrics: nil)
    }

    var isEmpty: Bool {
        return compilerArguments.isEmpty
            && (buildTimeMetrics?.expressionsBuildTime.isEmpty ?? true)
    }
}

public struct BuildTimeMetrics: Equatable {
    let totalBuildTime: TimeInterval
    let expressionsBuildTime: [ExpressionBuildTime]

    public init(
        totalBuildTime: TimeInterval,
        expressionsBuildTime: [ExpressionBuildTime]
    ) {
        self.totalBuildTime = totalBuildTime
        self.expressionsBuildTime = expressionsBuildTime
    }
}

public struct ExpressionBuildTime: Hashable {
    let buildTime: TimeInterval
    let location: Location
    let expressionType: String

    public init(
        buildTime: TimeInterval,
        location: Location,
        expressionType: String
    ) {
        self.buildTime = buildTime
        self.location = location
        self.expressionType = expressionType
    }
}