//
//  UITableView+Extensions.swift
//  Scanner
//

import UIKit

// MARK: - Cell Registration & Dequeue

extension UITableView {

    func register<T: UITableViewCell>(cellType: T.Type) {
        register(T.self, forCellReuseIdentifier: String(describing: T.self))
    }

    func dequeueReusableCell<T: UITableViewCell>(for indexPath: IndexPath, cellType: T.Type = T.self) -> T {
        guard let cell = dequeueReusableCell(withIdentifier: String(describing: T.self), for: indexPath) as? T else {
            fatalError("Failed to dequeue cell: \(String(describing: T.self))")
        }
        return cell
    }
}

// MARK: - UICollectionView

extension UICollectionView {

    func register<T: UICollectionViewCell>(cellType: T.Type) {
        register(T.self, forCellWithReuseIdentifier: String(describing: T.self))
    }

    func dequeueReusableCell<T: UICollectionViewCell>(for indexPath: IndexPath, cellType: T.Type = T.self) -> T {
        guard let cell = dequeueReusableCell(withReuseIdentifier: String(describing: T.self), for: indexPath) as? T else {
            fatalError("Failed to dequeue cell: \(String(describing: T.self))")
        }
        return cell
    }
}
