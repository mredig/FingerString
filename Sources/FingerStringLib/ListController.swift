#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
import Foundation
import SwiftPizzaSnips
import SQLite3

public enum Constants {
	public static let defaultDBURL = URL
		.homeDirectory
		.appending(path: ".config")
		.appending(path: "FingerString")
		.appending(path: "store")
		.appendingPathExtension("db")
}

public struct ListController: Sendable {

	public static let defaultDB: FingerStringDB = {
		FingerStringDB(url: Constants.defaultDBURL)
	}()

	let db: FingerStringDB

	public init(db: FingerStringDB) {
		try? FileManager.default.createDirectory(
			at: Constants.defaultDBURL.deletingLastPathComponent(),
			withIntermediateDirectories: true)

		if Constants.defaultDBURL.checkResourceIsAccessible() == false {
			try? Self.createDB()
		}

		self.db = db
	}

	public static func createDB(at location: URL = Constants.defaultDBURL) throws(DBError) {
		var path = location.path(percentEncoded: false).cString(using: .utf8) ?? []
		var pointer: OpaquePointer?// = -1
		let rc = sqlite3_create_fingerstringdb(
			&path,
			Int32(SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE),
			&pointer)

		guard rc == SQLITE_OK else {
			throw .cannotCreateDB
		}

		let db = FingerStringDB(url: location)

		do {
			try db.execute("PRAGMA foreign_keys = ON")
		} catch {
			throw .cannotEnableForeignKeys
		}

		do {
			try db.execute("PRAGMA journal_mode = WAL")
		} catch {
			throw .cannotEnableForeignKeys
		}
	}

	// MARK: - Create
	public func createList(with slug: String, friendlyTitle: String?, description: String?) async throws -> TaskList {
		let create = TaskList(slug: slug.lowercased(), title: friendlyTitle, description: description)
		let new = try await db.insert(create)
		return new
	}

	public func createTask(label: String, note: String?, on listID: TaskList.ID) async throws -> TaskItem {
		guard let list = try await getList(id: listID) else {
			throw CreateError.noMatchingList
		}
		let lastItemOnList = try await getLastTask(on: listID)

		var previousValue: String?
		while true {
			let inputComposite = label + "\(previousValue, default: "")"
			let hash = Insecure.MD5.hash(data: Data(inputComposite.utf8))
			previousValue = hash.toHexString()
			let itemHashID = String(hash.toHexString().prefix(5))
			let create = TaskItem(
				listId: listID,
				prevId: lastItemOnList?.id,
				itemHashId: itemHashID,
				isComplete: false,
				label: label,
				note: note)

			let new: TaskItem
			do {
				new = try await db.insert(create)
			} catch {
				print("Duplicate id, trying again")
				continue
			}

			if var lastItemOnList {
				lastItemOnList.nextId = new.id
				try await db.update(lastItemOnList)
			}

			if list.firstTaskId == nil {
				var listUpdate = list
				listUpdate.firstTaskId = new.id

				try await db.update(listUpdate)
			}
			return new
		}

	}

	// MARK: - Read
	public func getAllLists() async throws -> [TaskList] {
		try await db.taskLists.fetch()
	}

	public func getList(id: TaskList.ID) async throws -> TaskList? {
		try await db.taskLists.find(id)
	}

	public func getList(withSlug slug: String) async throws -> TaskList? {
		try await db.taskLists.find(by: \.slug, slug)
	}

	public func getAllTasksStream(on listID: TaskList.ID) async throws -> AsyncThrowingStream<(index: Int, task: TaskItem), Error> {
		let list = try await getList(id: listID)
		let (stream, continuation) = AsyncThrowingStream.makeStream(of: (index: Int, task: TaskItem).self)

		Task {
			var taskID = list?.firstTaskId
			var currentIndex = 0

			while let currentTaskID = taskID {
				defer { currentIndex += 1 }
				do {
					guard
						let task = try await getTask(id: currentTaskID)
					else { throw ReadError.doesntExist }
					continuation.yield((currentIndex, task))
					taskID = task.nextId
				} catch {
					taskID = nil
					continuation.finish(throwing: error)
				}
			}
			continuation.finish()
		}

		return stream
	}

	public func getAllTasks(on listID: TaskList.ID) async throws -> [TaskItem] {
		var tasks: [TaskItem] = []

		let stream = try await getAllTasksStream(on: listID)

		for try await (_, task) in stream {
			tasks.append(task)
		}

		return tasks
	}

	public func getTask(hashID: String) async throws -> TaskItem? {
		try await db.taskItems.find(by: \.itemHashId, hashID.lowercased())
	}

	public func getTask(id: TaskItem.ID) async throws -> TaskItem? {
		try await db.taskItems.find(id)
	}

	public func getTask(index: Int, on listID: TaskList.ID) async throws -> TaskItem? {
		guard index >= 0 else { return nil }

		let stream = try await getAllTasksStream(on: listID)

		// note the stream is known to continue firing after finding a match. this is a future fix
		for try await (taskIndex, taskItem) in stream {
			guard taskIndex == index else { continue }
			return taskItem
		}

		return nil
	}

	public func getLastTask(on listID: TaskList.ID) async throws -> TaskItem? {
		let stream = try await getAllTasksStream(on: listID)

		var currentTask: TaskItem?
		for try await (_, task) in stream {
			currentTask = task
		}

		return currentTask
	}

	// MARK: - Update
	public enum Change<T> {
		case unchanged
		case change(T)
	}

	@discardableResult
	public func updateTask(
		id: TaskItem.ID,
		label: Change<String> = .unchanged,
		note: Change<String?> = .unchanged,
		isCompleted: Change<Bool> = .unchanged
	) async throws -> TaskItem {
		var task = try await getTask(id: id).unwrap(orThrow: ReadError.doesntExist)

		if case .change(let newValue) = note {
			task.note = newValue
		}

		if case .change(let newValue) = label {
			task.label = newValue
		}

		if case .change(let newValue) = isCompleted {
			task.isComplete = newValue
		}

		try await db.update(task)

		return task
	}

	@discardableResult
	private func updateRootTask(
		_ id: TaskItem.ID?,
		on listID: TaskList.ID
	) async throws -> (previousID: TaskItem.ID?, list: TaskList) {
		guard
			var list = try await getList(id: listID)
		else { throw ReadError.doesntExist }

		let old = list.firstTaskId
		list.firstTaskId = id

		try await db.update(list)

		return (old, list)
	}

	// MARK: - Delete

	public func deleteTask(_ id: TaskItem.ID) async throws {
		guard
			let task = try await getTask(id: id)
		else { return }
		async let previousTaskLoad: TaskItem? = {
			guard let prevId = task.prevId else { return nil }
			return try await getTask(id: prevId)
		}()
		async let nextTaskLoad: TaskItem? = {
			guard let nextId = task.nextId else { return nil }
			return try await getTask(id: nextId)
		}()


		let deletion = {
			try await db.delete(task)
		}

		guard let list = try await getList(id: task.listId) else {
			return try await deletion()
		}

		let previousTask = try await previousTaskLoad
		let nextTask = try await nextTaskLoad

		var updates: [TaskItem] = []
		switch (previousTask, nextTask) {
		case (.some(var previous), .some(var next)):
			// middle of the list
			previous.setNext(&next)
			updates = [previous, next]
		case (nil, nil):
			// it was the only task on the list
			try await updateRootTask(nil, on: list.id)
		case (nil, .some(var next)):
			// it was the first task on the list
			try await updateRootTask(next.id, on: list.id)
			next.prevId = nil
			updates = [next]
		case (.some(var previous), nil):
			// it was the last task on the list
			previous.nextId = nil
			updates = [previous]
		}

		for update in updates {
			try await db.update(update)
		}
		try await deletion()
	}

	public func deleteList(_ id: TaskList.ID) async throws {
		guard
			let list = try await getList(id: id)
		else { return }

		try await db.delete(list)
	}

	public enum CreateError: Error {
		case noMatchingList
	}

	public enum ReadError: Error {
		case doesntExist
	}

	public enum DBError: Error {
		case cannotCreateDB
		case cannotEnableForeignKeys
		case cannotEnableWAL
	}
}
