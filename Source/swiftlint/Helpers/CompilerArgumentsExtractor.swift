import Foundation
import SourceKittenFramework

struct CompilerArgumentsExtractor {
//    static func allCompilerInvocations(compilerLogs: String) -> [String] {
//        var compilerInvocations = [String]()
//        compilerLogs.enumerateLines { line, _ in
//            if let swiftcIndex = line.range(of: "swiftc ")?.upperBound, line.contains(" -module-name ") {
//                let invocation = line[swiftcIndex...]
//                    .components(separatedBy: " ")
//                    .expandingResponseFiles
//                    .joined(separator: " ")
//                compilerInvocations.append(invocation)
//            }
//        }
//
//        return compilerInvocations
//    }

    static func allCompilerInvocations(compilerLogs: String) -> [CompilerInvocation] {
        let compilerInvocations = ConcurrentLinesExtractor.extract(
            string: compilerLogs,
            extractOperation: getCompilerInvocation
        )
        return compilerInvocations
    }

    private static func getCompilerInvocation(line: String) -> CompilerInvocation? {
        guard let swiftcIndex = line.range(of: "swiftc ")?.upperBound, line.contains(" -module-name ") else {
            return nil
        }

        let elements = line[swiftcIndex...]
            .components(separatedBy: " ")
            .expandingResponseFiles
        return CompilerInvocation(elements: elements)
    }

    static func compilerArgumentsForFile(_ sourceFile: String, compilerInvocations: [CompilerInvocation]) -> [String]? {
        let escapedSourceFile = sourceFile.replacingOccurrences(of: " ", with: "\\ ")
        guard let compilerInvocation = compilerInvocations.first(
            where: { $0.elements.first(where: { $0.contains(escapedSourceFile) }) != nil }
        ) else {
            return nil
        }

        return parseCLIArguments(compilerInvocation)
    }

    /**
     Filters compiler arguments from `xcodebuild` to something that SourceKit/Clang will accept.

     - parameter args: Compiler arguments, as parsed from `xcodebuild`.

     - returns: Filtered compiler arguments.
     */
    static func filterCompilerArguments(_ args: [String]) -> [String] {
        let args = args + ["-D", "DEBUG"]
        var shouldFilterNextElement = false
        let result: [String] = args.compactMap {
            if $0 == "-output-file-map" {
                shouldFilterNextElement = true
                return nil
            }

            if shouldFilterNextElement {
                shouldFilterNextElement = false
                return nil
            }

            guard [
                "-parseable-output",
                "-incremental",
                "-serialize-diagnostics",
                "-emit-dependencies"
            ].contains($0) else {
                return nil
            }

            if $0 == "-O" {
                return "-Onone"
            }

            if $0 == "-DNDEBUG=1" {
                return "-DDEBUG=1"
            }

            // https://github.com/realm/SwiftLint/issues/3365
            return $0.replacingOccurrences(of: "\\=", with: "=")
        }
        return result
    }
}

// MARK: - Private

#if !os(Linux)
private extension Scanner {
    func scanUpToString(_ string: String) -> String? {
        var result: NSString?
        let success = scanUpTo(string, into: &result)
        if success {
            return result?.bridge()
        }
        return nil
    }

    func scanString(_ string: String) -> String? {
        var result: NSString?
        let success = scanString(string, into: &result)
        if success {
            return result?.bridge()
        }
        return nil
    }
}
#endif

private func parseCLIArguments(_ invocation: CompilerInvocation) -> [String] {
    let escapedSpacePlaceholder = "\u{0}"
    let scanner = Scanner(string: invocation.elements.joined(separator: " "))
    var str = ""
    var didStart = false
    while let result = scanner.scanUpToString("\"") {
        if didStart {
            str += result.replacingOccurrences(of: " ", with: escapedSpacePlaceholder)
            str += " "
        } else {
            str += result
        }
        _ = scanner.scanString("\"")
        didStart.toggle()
    }
    return CompilerArgumentsExtractor.filterCompilerArguments(
        str.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "\\ ", with: escapedSpacePlaceholder)
            .components(separatedBy: " ")
            .map { $0.replacingOccurrences(of: escapedSpacePlaceholder, with: " ") }
    )
}

private extension Array where Element == String {
    /// Return the full list of compiler arguments, replacing any response files with their contents.
    var expandingResponseFiles: [String] {
        return flatMap { arg -> [String] in
            guard arg.starts(with: "@") else {
                return [arg]
            }
            let responseFile = String(arg.dropFirst())
            return (try? String(contentsOf: URL(fileURLWithPath: responseFile))).flatMap {
                $0.trimmingCharacters(in: .newlines)
                  .components(separatedBy: "\n")
                  .expandingResponseFiles
            } ?? [arg]
        }
    }
}
