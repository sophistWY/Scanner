//
//  WCDBManager.swift
//  Scanner
//
//  Singleton database manager wrapping WCDB operations.
//

import Foundation
import WCDBSwift

final class WCDBManager {

    static let shared = WCDBManager()

    private let database: Database
    private let documentTable = "documents"

    private init() {
        let dbPath = FileHelper.shared.documentsDirectory.appendingPathComponent("Scanner.db").path
        database = Database(withPath: dbPath)
        createTables()
    }

    // MARK: - Table Setup

    private func createTables() {
        do {
            try database.create(table: documentTable, of: DocumentModel.self)
            Logger.shared.log("Database tables created", level: .info)
        } catch {
            Logger.shared.log("Database creation error: \(error.localizedDescription)", level: .error)
        }
    }

    // MARK: - Insert

    @discardableResult
    func insertDocument(_ document: DocumentModel) -> Bool {
        do {
            try database.insert(objects: document, intoTable: documentTable)
            Logger.shared.log("Document inserted: \(document.name)", level: .info)
            return true
        } catch {
            Logger.shared.log("Insert error: \(error.localizedDescription)", level: .error)
            return false
        }
    }

    // MARK: - Query

    func getAllDocuments(orderBy order: OrderBy) -> [DocumentModel] {
        do {
            let docs: [DocumentModel] = try database.getObjects(
                fromTable: documentTable,
                orderBy: [order]
            )
            return docs
        } catch {
            Logger.shared.log("Query error: \(error.localizedDescription)", level: .error)
            return []
        }
    }

    func getDocument(byId id: Int64) -> DocumentModel? {
        do {
            let doc: DocumentModel? = try database.getObject(
                fromTable: documentTable,
                where: DocumentModel.Properties.id == id
            )
            return doc
        } catch {
            Logger.shared.log("Query by id error: \(error.localizedDescription)", level: .error)
            return nil
        }
    }

    // MARK: - Update

    @discardableResult
    func updateDocumentName(_ name: String, forId id: Int64) -> Bool {
        do {
            let update = DocumentModel()
            update.name = name
            update.updateTime = Date()
            try database.update(
                table: documentTable,
                on: DocumentModel.Properties.name, DocumentModel.Properties.updateTime,
                with: update,
                where: DocumentModel.Properties.id == id
            )
            return true
        } catch {
            Logger.shared.log("Update error: \(error.localizedDescription)", level: .error)
            return false
        }
    }

    @discardableResult
    func updateDocumentContent(id: Int64, filePath: String, thumbnailPath: String, pageCount: Int) -> Bool {
        do {
            let update = DocumentModel()
            update.filePath = filePath
            update.thumbnailPath = thumbnailPath
            update.pageCount = pageCount
            update.updateTime = Date()
            try database.update(
                table: documentTable,
                on: DocumentModel.Properties.filePath,
                    DocumentModel.Properties.thumbnailPath,
                    DocumentModel.Properties.pageCount,
                    DocumentModel.Properties.updateTime,
                with: update,
                where: DocumentModel.Properties.id == id
            )
            return true
        } catch {
            Logger.shared.log("Update content error: \(error.localizedDescription)", level: .error)
            return false
        }
    }

    // MARK: - Delete

    @discardableResult
    func deleteDocument(byId id: Int64) -> Bool {
        do {
            try database.delete(
                fromTable: documentTable,
                where: DocumentModel.Properties.id == id
            )
            Logger.shared.log("Document deleted: id=\(id)", level: .info)
            return true
        } catch {
            Logger.shared.log("Delete error: \(error.localizedDescription)", level: .error)
            return false
        }
    }

    @discardableResult
    func deleteAllDocuments() -> Bool {
        do {
            try database.delete(fromTable: documentTable)
            return true
        } catch {
            Logger.shared.log("Delete all error: \(error.localizedDescription)", level: .error)
            return false
        }
    }

    // MARK: - Count

    func documentCount() -> Int {
        do {
            let count = try database.getValue(
                on: DocumentModel.Properties.id.count(),
                fromTable: documentTable
            )
            return Int(count.int64Value)
        } catch {
            return 0
        }
    }
}
