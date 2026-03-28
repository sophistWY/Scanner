//
//  BaseViewModel.swift
//  Scanner
//
//  Provides a base class and protocol for all ViewModels.
//

import Foundation

/// Implement this protocol when a ViewModel has clearly separable
/// input actions and output observables (useful for testing / composition).
protocol ViewModelType {
    associatedtype Input
    associatedtype Output

    func transform(input: Input) -> Output
}

/// Base class for all ViewModels. Provides lifecycle logging.
/// Subclass this and optionally conform to ViewModelType.
class BaseViewModel {

    deinit {
        Logger.shared.log("\(type(of: self)) deinit")
    }
}
