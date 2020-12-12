import Foundation

private enum LazyValue<Value> {
    case uninitialized(() -> Value)
    case initialized(Value)
}

@propertyWrapper
class LazyWrapper<Value> {
    private var lazyValue: LazyValue<Value>

    init(wrappedValue: @autoclosure @escaping () -> Value) {
        lazyValue = .uninitialized(wrappedValue)
    }

    init(factory: @escaping () -> Value) {
        lazyValue = .uninitialized(factory)
    }

    var wrappedValue: Value {
        get {
            switch lazyValue {
            case .uninitialized(let initializer):
                let value = initializer()
                lazyValue = .initialized(value)
                return value
            case .initialized(let value):
                return value
            }
        }
        set {
            lazyValue = .initialized(newValue)
        }
    }
}

extension LazyWrapper: Equatable where Value: Equatable {
    static func == (lhs: LazyWrapper<Value>, rhs: LazyWrapper<Value>) -> Bool {
        return lhs.wrappedValue == rhs.wrappedValue
    }
}
