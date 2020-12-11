import Foundation

final class ConcurrentLinesExtractor {
     static func extract<T: Hashable>(
        string: String,
        extractOperation: @escaping (String) -> T?
        ) -> [T] {
        let group = DispatchGroup()
        var storage: [T] = []
        string.enumerateLines { line, _ in
            group.enter()
            DispatchQueue.global().async {
                guard let item = extractOperation(line) else {
                    group.leave()
                    return
                }
                DispatchQueue.main.async {
                    storage.append(item)
                    group.leave()
                }
            }
        }
        group.wait()
        return storage
    }
}
