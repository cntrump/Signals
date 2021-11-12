import Foundation

final class SMutexLock {
    private var lock = os_unfair_lock()

    public func locked(_ f: () -> Void) {
        let _: Any? = self
        os_unfair_lock_lock(&lock)
        f()
        os_unfair_lock_unlock(&lock)
    }
}
