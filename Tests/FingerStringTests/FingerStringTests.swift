import Testing
@testable import FingerStringLib

@Suite struct ListControllerSmokeTests {
	@Test func createAndFetchList() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.createList(with: "Groceries", friendlyTitle: "Groceries", description: nil)

		#expect(list.slug == "groceries")
		let fetched = try await controller.getList(withSlug: "groceries")
		#expect(fetched?.id == list.id)
	}

	@Test func storesAreIsolated() async throws {
		let a = try TestSupport.makeController()
		let b = try TestSupport.makeController()
		_ = try await a.createList(with: "only-a", friendlyTitle: nil, description: nil)

		#expect(try await a.getAllLists().count == 1)
		#expect(try await b.getAllLists().isEmpty)
	}

	@Test func subtasksAndDelete() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.createList(with: "l", friendlyTitle: nil, description: nil)
		let parent = try await controller.createTask(label: "parent", note: nil, on: .list(list.id))
		let child = try await controller.createTask(label: "child", note: nil, on: .task(hashID: parent.itemHashId))

		#expect(try await controller.getAllTasks(on: .task(hashID: parent.itemHashId)).count == 1)
		try await controller.deleteTask(child.id)
		#expect(try await controller.getAllTasks(on: .task(hashID: parent.itemHashId)).isEmpty)
	}
}
