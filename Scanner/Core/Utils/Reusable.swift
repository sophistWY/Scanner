//
//  Reusable.swift
//  Scanner
//
//  Protocols for type-safe cell configuration and reuse.
//

import UIKit

/// Any cell that can be configured with a specific model type.
protocol Configurable {
    associatedtype Model
    func configure(with model: Model)
}

/// Protocol for nib-based cells.
protocol NibLoadable: AnyObject {
    static var nib: UINib { get }
}

extension NibLoadable {
    static var nib: UINib {
        return UINib(nibName: String(describing: self), bundle: nil)
    }
}

/// Convenience: register a nib-based cell.
extension UITableView {
    func register<T: UITableViewCell>(nibCellType: T.Type) where T: NibLoadable {
        register(T.nib, forCellReuseIdentifier: String(describing: T.self))
    }
}

extension UICollectionView {
    func register<T: UICollectionViewCell>(nibCellType: T.Type) where T: NibLoadable {
        register(T.nib, forCellWithReuseIdentifier: String(describing: T.self))
    }
}
