@testable import FingerStringLib

extension ListController {
	@discardableResult
	func makeList(_ slug: String = "list") async throws -> TaskList {
		try await createList(with: slug, friendlyTitle: nil, description: nil)
	}

	@discardableResult
	func addTask(_ label: String, to parent: TaskParent, note: String? = nil) async throws -> TaskItem {
		try await createTask(label: label, note: note, on: parent)
	}

	func labels(on parent: TaskParent) async throws -> [String] {
		try await getAllTasks(on: parent).map(\.label)
	}
}
