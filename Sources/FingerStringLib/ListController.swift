#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
import Foundation
import SwiftPizzaSnips
import SQLite3

public struct ListController: Sendable {

	public static let defaultDB: FingerStringDB = {
		let dbLocation = Constants.defaultDBURL
		if dbLocation.checkResourceIsAccessible() == false {
			do {
				try Self.createDB(at: dbLocation)
			} catch {
				print("Error creating new db at \(dbLocation.path(percentEncoded: false)): \(error)")
			}
		}
		return FingerStringDB(url: dbLocation)
	}()

	let db: FingerStringDB

	public init(dbLocation: URL, readOnly: Bool = false) throws {
		try? FileManager.default.createDirectory(
			at: dbLocation.deletingLastPathComponent(),
			withIntermediateDirectories: true)

		if dbLocation.checkResourceIsAccessible() == false {
			try Self.createDB(at: dbLocation)
		}

		self.init(db: FingerStringDB(url: dbLocation, readOnly: readOnly))
	}

	public init(db: FingerStringDB) {
		self.db = db

		do {
			try db.execute("PRAGMA foreign_keys = ON")
		} catch {
			print("Couldn't enable foreign keys")
		}

		do {
			try db.execute("PRAGMA journal_mode = WAL")
		} catch {
			print("Couldn't enable WAL mode")
		}
	}

	public static func createDB(at location: URL = Constants.defaultDBURL) throws(DBError) {
		var path = location.path(percentEncoded: false).cString(using: .utf8) ?? []
		var pointer: OpaquePointer?
		let rc = sqlite3_create_fingerstringdb(
			&path,
			Int32(SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE),
			&pointer)

		guard rc == SQLITE_OK else {
			throw .cannotCreateDB
		}

		// Close the temporary connection handle since we'll be using FingerStringDB
		if let pointer = pointer {
			sqlite3_close(pointer)
		}
	}

	// MARK: - Create
	public func createList(with slug: String, friendlyTitle: String?, description: String?) async throws -> TaskList {
		let create = TaskList(slug: slug.lowercased(), title: friendlyTitle, description: description)
		let new = try await db.insert(create)
		return new
	}

	public func createTask(label: String, note: String?, on taskParent: TaskParent) async throws -> TaskItem {
		let list: TaskList
		let parentTask: TaskItem?
		let lastItemOnList = try await getLastTask(on: taskParent)
		switch taskParent {
		case .list(let id):
			list = try await getList(id: id).unwrap(orThrow: ReadError.doesntExist)
			parentTask = nil
		case .task(let hashID):
			let parentTaskT = try await getTask(hashID: hashID).unwrap(orThrow: ReadError.doesntExist)
			parentTask = parentTaskT
			list = try await getList(id: parentTaskT.listId).unwrap(orThrow: ReadError.doesntExist)
		}

		var previousValue: String?
		while true {
			let inputComposite = label + "\(previousValue, default: "")"
			let hash = Insecure.MD5.hash(data: Data(inputComposite.utf8))
			previousValue = hash.toHexString()
			let itemHashID = String(hash.toHexString().prefix(Constants.hashIDLength))
			let create = TaskItem(
				listId: list.id,
				prevId: lastItemOnList?.id,
				subtaskParentId: parentTask?.id,
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

			if var parentTask, parentTask.firstSubtaskId == nil {
				parentTask.firstSubtaskId = new.id
				try await db.update(parentTask)
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

	public enum TaskParent {
		case list(TaskList.ID)
		case task(hashID: String)
	}
	public func getAllTasksStream(on parent: TaskParent) async throws -> AsyncThrowingStream<(index: Int, task: TaskItem), Error> {
		let firstTaskID = try await {
			switch parent {
			case .list(let listID):
				let list = try await getList(id: listID)
				return list?.firstTaskId
			case .task(let hashID):
				let task = try await getTask(hashID: hashID)
				return task?.firstSubtaskId
			}
		}()
		let (stream, continuation) = AsyncThrowingStream.makeStream(of: (index: Int, task: TaskItem).self)

		Task {
			var taskID = firstTaskID
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

	public func getAllTasks(on taskParent: TaskParent) async throws -> [TaskItem] {
		var tasks: [TaskItem] = []

		let stream = try await getAllTasksStream(on: taskParent)

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

	public func getTask(index: Int, on taskParent: TaskParent) async throws -> TaskItem? {
		guard index >= 0 else { return nil }

		let stream = try await getAllTasksStream(on: taskParent)

		// note the stream is known to continue firing after finding a match. this is a future fix
		for try await (taskIndex, taskItem) in stream {
			guard taskIndex == index else { continue }
			return taskItem
		}

		return nil
	}

	public func getLastTask(on taskParent: TaskParent) async throws -> TaskItem? {
		let stream = try await getAllTasksStream(on: taskParent)

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

	private func updateRootTask(
		_ id: TaskItem.ID?,
		on taskParent: TaskParent
	) async throws {
		switch taskParent {
		case .list(let listID):
			guard
				var list = try await getList(id: listID)
			else { throw ReadError.doesntExist }

			list.firstTaskId = id

			try await db.update(list)
		case .task(let hashID):
			guard var task = try await getTask(hashID: hashID) else {
				throw ReadError.doesntExist
			}

			task.firstSubtaskId = id

			try await db.update(task)
		}
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

		let previousTask = try await previousTaskLoad
		let nextTask = try await nextTaskLoad

		let taskParent = { () async throws -> TaskParent in
			guard let parentTaskID = task.subtaskParentId else {
				return .list(task.listId)
			}
			let parentTask = try await getTask(id: parentTaskID).unwrap(orThrow: ReadError.doesntExist)
			return .task(hashID: parentTask.itemHashId)
		}

		var updates: [TaskItem] = []
		do {
			switch (previousTask, nextTask) {
			case (.some(var previous), .some(var next)):
				// middle of the list
				previous.setNext(&next)
				updates = [previous, next]
			case (nil, nil):
				// it was the only task on the list
				try await updateRootTask(nil, on: taskParent())
			case (nil, .some(var next)):
				// it was the first task on the list
				try await updateRootTask(next.id, on: taskParent())
				next.prevId = nil
				updates = [next]
			case (.some(var previous), nil):
				// it was the last task on the list
				previous.nextId = nil
				updates = [previous]
			}
		} catch {
			print("Error cleaning up deletion: \(error)")
			try await deletion()
			return
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
	}
}
