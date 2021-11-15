import Foundation

private final class MulticastInstance<T> {
    let disposable: Disposable
    var subscribers = Bag<(T) -> Void>()
    var lock = SMutexLock()

    init(disposable: Disposable) {
        self.disposable = disposable
    }
}

public final class Multicast<T> {
    private let lock = SMutexLock()
    private var instances: [String: MulticastInstance<T>] = [:]

    public init() {
    }

    public func get(key: String, signal: Signal<T, Never>) -> Signal<T, Never> {
        return Signal { subscriber in
            var instance: MulticastInstance<T>!
            var beginDisposable: MetaDisposable?
            self.lock.locked {
                if let existing = self.instances[key] {
                    instance = existing
                } else {
                    let disposable = MetaDisposable()
                    instance = MulticastInstance(disposable: disposable)
                    beginDisposable = disposable
                }
            }

            var index: Bag<(T) -> Void>.Index!
            instance.lock.locked {
                index = instance.subscribers.add { next in
                    subscriber.putNext(next)
                }
            }

            if let beginDisposable = beginDisposable {
                beginDisposable.set(signal.start(next: { next in
                    var subscribers: [(T) -> Void]!
                    instance.lock.locked {
                        subscribers = instance.subscribers.copyItems()
                    }
                    for subscriber in subscribers {
                        subscriber(next)
                    }
                }, error: { _ in
                }, completed: {
                    self.lock.locked {
                        self.instances.removeValue(forKey: key)
                    }
                }))
            }

            return ActionDisposable {
                var remove = false
                instance.lock.locked {
                    instance.subscribers.remove(index)
                    if instance.subscribers.isEmpty {
                        remove = true
                    }
                }

                if remove {
                    self.lock.locked {
                        self.instances.removeValue(forKey: key)
                    }
                }
            }
        }
    }
}

public final class MulticastPromise<T> {
    public let subscribers = Bag<(T) -> Void>()
    public var value: T?
    let lock = SMutexLock()
    
    public init() {

    }
}
