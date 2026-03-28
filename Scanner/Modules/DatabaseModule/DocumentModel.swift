//
//  DocumentModel.swift
//  Scanner
//
//  WCDB ORM model for the documents table.
//

import Foundation
import WCDBSwift

final class DocumentModel: TableCodable {

    var id: Int64 = 0
    var name: String = ""
    var createTime: Date = Date()
    var updateTime: Date = Date()
    /// Relative path from the app's Documents directory to the PDF file.
    var filePath: String = ""
    /// Number of pages (images) in the document.
    var pageCount: Int = 0
    /// Relative path to the first page thumbnail image.
    var thumbnailPath: String = ""

    enum CodingKeys: String, CodingTableKey {
        typealias Root = DocumentModel
        static let objectRelationalMapping = TableBinding(CodingKeys.self)

        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                .id: ColumnConstraintBinding(isPrimary: true, isAutoIncrement: true),
                .name: ColumnConstraintBinding(isNotNull: true)
            ]
        }

        static var indexBindings: [IndexBinding.Subfix: IndexBinding]? {
            return [
                "_createTimeIdx": IndexBinding(indexesBy: createTime)
            ]
        }

        case id
        case name
        case createTime
        case updateTime
        case filePath
        case pageCount
        case thumbnailPath
    }

    var isAutoIncrement: Bool { return true }
    var lastInsertedRowID: Int64 = 0
}

// MARK: - Convenience

extension DocumentModel {

    var pdfURL: URL {
        FileHelper.shared.documentsDirectory.appendingPathComponent(filePath)
    }

    var thumbnailURL: URL {
        FileHelper.shared.documentsDirectory.appendingPathComponent(thumbnailPath)
    }

    var formattedCreateTime: String {
        createTime.formatted()
    }
}
