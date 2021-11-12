import Foundation

public protocol Disposable: AnyObject {
    func dispose()
}

final class _EmptyDisposable: Disposable {
    func dispose() {
    }
}

public let EmptyDisposable: Disposable = _EmptyDisposable()

public final class ActionDisposable: Disposable {
    private var lock = SMutexLock()

    private var action: (() -> Void)?

    public init(action: @escaping() -> Void) {
        self.action = action
    }

    deinit {
        var freeAction: (() -> Void)?
        lock.locked {
            freeAction = self.action
            self.action = nil
        }

        if let freeAction = freeAction {
            withExtendedLifetime(freeAction, {})
        }
    }

    public func dispose() {
        var disposeAction: (() -> Void)?

        lock.locked {
            disposeAction = self.action
            self.action = nil
        }

        disposeAction?()
    }
}

public final class MetaDisposable: Disposable {
    private var lock = SMutexLock()
    private var disposed = false
    private var disposable: Disposable! = nil

    public init() {
    }

    deinit {
        var freeDisposable: Disposable?
        lock.locked {
            if let disposable = self.disposable {
                freeDisposable = disposable
                self.disposable = nil
            }
        }
        if let freeDisposable = freeDisposable {
            withExtendedLifetime(freeDisposable, { })
        }
    }

    public func set(_ disposable: Disposable?) {
        var previousDisposable: Disposable! = nil
        var disposeImmediately = false

        lock.locked {
            disposeImmediately = self.disposed
            if !disposeImmediately {
                previousDisposable = self.disposable
                if let disposable = disposable {
                    self.disposable = disposable
                } else {
                    self.disposable = nil
                }
            }
        }

        if previousDisposable != nil {
            previousDisposable.dispose()
        }

        if disposeImmediately {
            if let disposable = disposable {
                disposable.dispose()
            }
        }
    }

    public func dispose() {
        var disposable: Disposable! = nil

        lock.locked {
            if !self.disposed {
                self.disposed = true
                disposable = self.disposable
                self.disposable = nil
            }
        }

        if disposable != nil {
            disposable.dispose()
        }
    }
}

public final class DisposableSet: Disposable {
    private var lock = SMutexLock()
    private var disposed = false
    private var disposables: [Disposable] = []

    public init() {
    }
    
    deinit {
        lock.locked {
            self.disposables.removeAll()
        }
    }

    public func add(_ disposable: Disposable) {
        var disposeImmediately = false

        lock.locked {
            if self.disposed {
                disposeImmediately = true
            } else {
                self.disposables.append(disposable)
            }
        }

        if disposeImmediately {
            disposable.dispose()
        }
    }

    public func remove(_ disposable: Disposable) {
        lock.locked {
            if let index = self.disposables.firstIndex(where: { $0 === disposable }) {
                self.disposables.remove(at: index)
            }
        }
    }

    public func dispose() {
        var disposables: [Disposable] = []
        lock.locked {
            if !self.disposed {
                self.disposed = true
                disposables = self.disposables
                self.disposables = []
            }
        }

        disposables.forEach { disposable in
            disposable.dispose()
        }
    }
}

public final class DisposableDict<T: Hashable>: Disposable {
    private var lock = SMutexLock()
    private var disposed = false
    private var disposables: [T: Disposable] = [:]

    deinit {
        lock.locked {
            self.disposables.removeAll()
        }
    }

    public func set(_ disposable: Disposable?, forKey key: T) {
        var disposeImmediately = false
        var disposePrevious: Disposable?

        lock.locked {
            if self.disposed {
                disposeImmediately = true
            } else {
                disposePrevious = self.disposables[key]
                if let disposable = disposable {
                    self.disposables[key] = disposable
                }
            }
        }

        if disposeImmediately {
            disposable?.dispose()
        }
        disposePrevious?.dispose()
    }

    public func dispose() {
        var disposables: [T: Disposable] = [:]
        lock.locked {
            if !self.disposed {
                self.disposed = true
                disposables = self.disposables
                self.disposables = [:]
            }
        }

        disposables.values.forEach { disposable in
            disposable.dispose()
        }
    }
}
