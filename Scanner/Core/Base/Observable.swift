//
//  Observable.swift
//  Scanner
//
//  Lightweight MVVM binding without Combine/RxSwift.
//  Always dispatches observer callbacks on the main thread.
//

import Foundation

final class Observable<T> {
    typealias Observer = (T) -> Void

    private var observers: [(id: UUID, observer: Observer)] = []

    var value: T {
        didSet { notifyObservers() }
    }

    init(_ value: T) {
        self.value = value
    }

    /// Bind an observer and fire immediately with current value.
    /// Returns a token that can be used to unbind later.
    @discardableResult
    func bind(_ observer: @escaping Observer) -> UUID {
        let id = UUID()
        observers.append((id: id, observer: observer))
        dispatchOnMain { observer(self.value) }
        return id
    }

    /// Bind an observer without firing immediately.
    @discardableResult
    func bindNoFire(_ observer: @escaping Observer) -> UUID {
        let id = UUID()
        observers.append((id: id, observer: observer))
        return id
    }

    /// Remove a specific observer by token.
    func unbind(_ id: UUID) {
        observers.removeAll { $0.id == id }
    }

    /// Remove all observers.
    func unbindAll() {
        observers.removeAll()
    }

    // MARK: - Private

    private func notifyObservers() {
        let current = value
        dispatchOnMain {
            self.observers.forEach { $0.observer(current) }
        }
    }

    private func dispatchOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
}
