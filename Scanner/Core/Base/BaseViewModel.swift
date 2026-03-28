//
//  BaseViewModel.swift
//  Scanner
//

import Foundation

class BaseViewModel {

    deinit {
        Logger.shared.log("\(type(of: self)) deinit")
    }
}
