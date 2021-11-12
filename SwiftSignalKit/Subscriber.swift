import Foundation

public final class Subscriber<T, E> {
    private var next: ((T) -> Void)!
    private var error: ((E) -> Void)!
    private var completed: (() -> Void)!

    private var lock = SMutexLock()
    private var terminated = false
    internal var disposable: Disposable!

    public init(next: ((T) -> Void)! = nil, error: ((E) -> Void)! = nil, completed: (() -> Void)! = nil) {
        self.next = next
        self.error = error
        self.completed = completed
    }

    deinit {
        var freeDisposable: Disposable?
        lock.locked {
            if let disposable = self.disposable {
                freeDisposable = disposable
                self.disposable = nil
            }
        }
        if let freeDisposableValue = freeDisposable {
            withExtendedLifetime(freeDisposableValue, {
            })
            freeDisposable = nil
        }
    }

    internal func assignDisposable(_ disposable: Disposable) {
        var dispose = false
        lock.locked {
            if self.terminated {
                dispose = true
            } else {
                self.disposable = disposable
            }
        }

        if dispose {
            disposable.dispose()
        }
    }

    internal func markTerminatedWithoutDisposal() {
        lock.locked {
            if !self.terminated {
                self.terminated = true
                self.next = nil
                self.error = nil
                self.completed = nil
            }
        }
    }

    public func putNext(_ next: T) {
        var action: ((T) -> Void)! = nil
        lock.locked {
            if !self.terminated {
                action = self.next
            }
        }

        if action != nil {
            action(next)
        }
    }

    public func putError(_ error: E) {
        var action: ((E) -> Void)! = nil

        var disposeDisposable: Disposable?

        lock.locked {
            if !self.terminated {
                action = self.error
                self.next = nil
                self.error = nil
                self.completed = nil
                self.terminated = true
                disposeDisposable = self.disposable
                self.disposable = nil

            }
        }

        if action != nil {
            action(error)
        }

        if let disposeDisposable = disposeDisposable {
            disposeDisposable.dispose()
        }
    }

    public func putCompletion() {
        var action: (() -> Void)! = nil

        var disposeDisposable: Disposable?

        var next: ((T) -> Void)?
        var error: ((E) -> Void)?
        var completed: (() -> Void)?

        lock.locked {
            if !self.terminated {
                action = self.completed
                next = self.next
                self.next = nil
                error = self.error
                self.error = nil
                completed = self.completed
                self.completed = nil
                self.terminated = true

                disposeDisposable = self.disposable
                self.disposable = nil
            }
        }

        if let next = next {
            withExtendedLifetime(next, {})
        }
        if let error = error {
            withExtendedLifetime(error, {})
        }
        if let completed = completed {
            withExtendedLifetime(completed, {})
        }

        if action != nil {
            action()
        }

        if let disposeDisposable = disposeDisposable {
            disposeDisposable.dispose()
        }
    }
}
