import Foundation

precedencegroup PipeRight {
    associativity: left
    higherThan: DefaultPrecedence
}

infix operator |> : PipeRight

@discardableResult public func |> <T, U>(value: T, function: ((T) -> U)) -> U {
    return function(value)
}

@discardableResult public func |> <T, U>(value: T, function: ((T) throws -> U)) throws -> U {
    return try function(value)
}

#if compiler(>=5.5.1)
@available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
@discardableResult public func |> <T, U>(value: T, function: ((T) async -> U)) async -> U {
    return await function(value)
}

@available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
@discardableResult public func |> <T, U>(value: T, function: ((T) async throws -> U)) async throws -> U {
    return try await function(value)
}
#endif

private final class SubscriberDisposable<T, E>: Disposable {
    private let subscriber: Subscriber<T, E>
    private let disposable: Disposable

    init(subscriber: Subscriber<T, E>, disposable: Disposable) {
        self.subscriber = subscriber
        self.disposable = disposable
    }

    func dispose() {
        subscriber.markTerminatedWithoutDisposal()
        disposable.dispose()
    }
}

public final class Signal<T, E> {
    private let generator: (Subscriber<T, E>) -> Disposable

    public init(_ generator: @escaping(Subscriber<T, E>) -> Disposable) {
        self.generator = generator
    }

    @discardableResult
    public func start(next: ((T) -> Void)! = nil, error: ((E) -> Void)! = nil, completed: (() -> Void)! = nil) -> Disposable {
        let subscriber = Subscriber<T, E>(next: next, error: error, completed: completed)
        let disposable = self.generator(subscriber)
        subscriber.assignDisposable(disposable)
        return SubscriberDisposable(subscriber: subscriber, disposable: disposable)
    }

    public static func single(_ value: T) -> Signal<T, E> {
        return Signal<T, E> { subscriber in
            subscriber.putNext(value)
            subscriber.putCompletion()

            return EmptyDisposable
        }
    }

    public static func complete() -> Signal<T, E> {
        return Signal<T, E> { subscriber in
            subscriber.putCompletion()

            return EmptyDisposable
        }
    }

    public static func fail(_ error: E) -> Signal<T, E> {
        return Signal<T, E> { subscriber in
            subscriber.putError(error)

            return EmptyDisposable
        }
    }

    public static func never() -> Signal<T, E> {
        return Signal<T, E> { _ in
            return EmptyDisposable
        }
    }
}
