import Foundation

public final class Atomic<T> {
    private var lock: SMutexLock
    private var value: T

    public init(value: T) {
        self.lock = SMutexLock()
        self.value = value
    }

    @discardableResult 
    public func with<R>(_ f: (T) -> R) -> R {
        var result: R?
        lock.locked {
            result = f(self.value)
        }

        return result!
    }

    @discardableResult
    public func modify(_ f: (T) -> T) -> T {
        var result: T?
        lock.locked {
            result = f(self.value)
            self.value = result!
        }

        return result!
    }

    @discardableResult
    public func swap(_ value: T) -> T {
        var previous: T?
        lock.locked {
            previous = self.value
            self.value = value
        }

        return previous!
    }
}
