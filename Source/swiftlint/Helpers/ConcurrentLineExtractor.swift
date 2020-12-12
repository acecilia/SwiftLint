import Foundation

final class ConcurrentLineExtractor {
    static func extract<T: Hashable>(
        string: String,
        extractOperation: @escaping (String) throws -> (File, T)?
        ) -> [File: Set<T>] {
        let group = DispatchGroup()
        var storage: [File: Set<T>] = [:]
        string.enumerateLines { line, _ in
            group.enter()
            DispatchQueue.global().async {
                guard let (file, item) = try? extractOperation(line) else {
                    group.leave()
                    return
                }
                DispatchQueue.main.async {
                    var items = storage[file] ?? []
                    items.insert(item)
                    storage[file] = items
                    group.leave()
                }
            }
        }
        group.wait()
        return storage
    }
}
