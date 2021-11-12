import Foundation

public final class Promise<T> {
    private var initializeOnFirstAccess: Signal<T, NoError>?
    private var value: T?
    private var lock = SMutexLock()
    private let disposable = MetaDisposable()
    private let subscribers = Bag<(T) -> Void>()

    public var onDeinit: (() -> Void)?

    public init(initializeOnFirstAccess: Signal<T, NoError>?) {
        self.initializeOnFirstAccess = initializeOnFirstAccess
    }

    public init(_ value: T) {
        self.value = value
    }

    deinit {
        self.onDeinit?()
        self.disposable.dispose()
    }

    public func set(_ signal: Signal<T, NoError>) {
        lock.locked {
            self.value = nil
        }

        self.disposable.set(signal.start(next: { [weak self] next in
            if let strongSelf = self {
                var subscribers: [(T) -> Void]?
                strongSelf.lock.locked {
                    strongSelf.value = next
                    subscribers = strongSelf.subscribers.copyItems()
                }

                subscribers?.forEach { (subscriber) in
                    subscriber(next)
                }
            }
        }))
    }

    public func get() -> Signal<T, NoError> {
        return Signal { [self] subscriber in
            var initializeOnFirstAccessNow: Signal<T, NoError>?
            var currentValue: T?
            var index: Bag.Index = NSNotFound
            lock.locked {
                if let initializeOnFirstAccess = self.initializeOnFirstAccess {
                    initializeOnFirstAccessNow = initializeOnFirstAccess
                    self.initializeOnFirstAccess = nil
                }
                currentValue = self.value
                index = self.subscribers.add { next in
                    subscriber.putNext(next)
                }
            }

            if let currentValue = currentValue {
                subscriber.putNext(currentValue)
            }

            if let initializeOnFirstAccessNow = initializeOnFirstAccessNow {
                self.set(initializeOnFirstAccessNow)
            }

            return ActionDisposable {
                lock.locked {
                    self.subscribers.remove(index)
                }
            }
        }
    }
}

public final class ValuePromise<T: Equatable> {
    private var value: T?
    private var lock = SMutexLock()
    private let subscribers = Bag<(T) -> Void>()
    public let ignoreRepeated: Bool

    public init(_ value: T, ignoreRepeated: Bool = false) {
        self.value = value
        self.ignoreRepeated = ignoreRepeated
    }

    public init(ignoreRepeated: Bool = false) {
        self.ignoreRepeated = ignoreRepeated
    }

    public func set(_ value: T) {
        var subscribers: [(T) -> Void]?
        lock.locked {
            if !self.ignoreRepeated || self.value != value {
                self.value = value
                subscribers = self.subscribers.copyItems()
            } else {
                subscribers = []
            }
        }

        subscribers?.forEach { subscriber in
            subscriber(value)
        }
    }

    public func get() -> Signal<T, NoError> {
        return Signal { [self] subscriber in
            var currentValue: T?
            var index: Bag.Index = NSNotFound
            lock.locked {
                currentValue = self.value
                index = self.subscribers.add { next in
                    subscriber.putNext(next)
                }
            }

            if let currentValue = currentValue {
                subscriber.putNext(currentValue)
            }

            return ActionDisposable {
                lock.locked {
                    self.subscribers.remove(index)
                }
            }
        }
    }
}
