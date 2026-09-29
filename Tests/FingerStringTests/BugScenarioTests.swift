import Testing
import FingerStringLib

// Recreates `bug.sh` (a list with completed tasks, several parents with subtasks, then deleting every
// subtask of one parent and adding new tasks afterwards) as library-level tests.

// MARK: - Helpers
extension ListController {
	/// Labels in display order, one line per task, with a tab per subtask level.
	/// Mirrors `list-view`: completed tasks are hidden along with their subtasks unless `includeCompleted` is set.
	func outline(
		on parent: TaskParent,
		includeCompleted: Bool = false,
		indent: String = ""
	) async throws -> [String] {
		var lines: [String] = []
		for task in try await getAllTasks(on: parent) {
			guard includeCompleted || task.isComplete == false else { continue }
			lines.append(indent + task.label)
			guard task.firstSubtaskId != nil else { continue }
			lines += try await outline(
				on: .task(hashID: task.itemHashId),
				includeCompleted: includeCompleted,
				indent: indent + "\t")
		}
		return lines
	}
}

// MARK: - Fixture (steps 1-17 of bug.sh)
private struct ZionFixture {
	let controller: ListController
	let list: TaskList
	let documentation: TaskItem
	let testing: TaskItem
	let media: TaskItem
	let notifications: TaskItem
	let additional: TaskItem
	let reminders: TaskItem
	let mediaSubtasks: [TaskItem]
	let notificationSubtasks: [TaskItem]
	let reminderSubtasks: [TaskItem]

	var listParent: ListController.TaskParent { .list(list.id) }

	static func make() async throws -> ZionFixture {
		let controller = try TestSupport.makeController()
		let list = try await controller.createList(with: "zion-project", friendlyTitle: "zion-project", description: "zion-project")
		let parent = ListController.TaskParent.list(list.id)

		let documentation = try await controller.addTask("Documentation (COMPLETE)", to: parent)
		try await controller.updateTask(id: documentation.id, isCompleted: .change(true))
		let testing = try await controller.addTask("Testing (COMPLETE)", to: parent)
		try await controller.updateTask(id: testing.id, isCompleted: .change(true))

		let media = try await controller.addTask("Priority 4: Media Support", to: parent)
		var mediaSubtasks: [TaskItem] = []
		for label in ["File upload implementation", "Media download with caching", "Thumbnail generation"] {
			mediaSubtasks.append(try await controller.addTask(label, to: .task(hashID: media.itemHashId)))
		}

		let notifications = try await controller.addTask("Priority 5: Notifications", to: parent)
		var notificationSubtasks: [TaskItem] = []
		for label in ["Push notification setup", "Notification settings UI/API"] {
			notificationSubtasks.append(try await controller.addTask(label, to: .task(hashID: notifications.itemHashId)))
		}

		let additional = try await controller.addTask("Priorities 6-10: Additional Features", to: parent)

		let reminders = try await controller.addTask("Reminders & Outstanding Items", to: parent)
		var reminderSubtasks: [TaskItem] = []
		for label in [
			"Update CONTEXT_SUMMARY.md documentation stats",
			"Review Rust SDK naming/architecture infractions",
			"Regenerate undocumented symbols list",
		] {
			reminderSubtasks.append(try await controller.addTask(label, to: .task(hashID: reminders.itemHashId)))
		}

		return ZionFixture(
			controller: controller,
			list: list,
			documentation: documentation,
			testing: testing,
			media: media,
			notifications: notifications,
			additional: additional,
			reminders: reminders,
			mediaSubtasks: mediaSubtasks,
			notificationSubtasks: notificationSubtasks,
			reminderSubtasks: reminderSubtasks)
	}
}

private let mediaOutline = [
	"Priority 4: Media Support",
	"\tFile upload implementation",
	"\tMedia download with caching",
	"\tThumbnail generation",
]
private let notificationsOutline = [
	"Priority 5: Notifications",
	"\tPush notification setup",
	"\tNotification settings UI/API",
]
private let integrationOutline = [
	"Integrate Zion into Element X main app",
	"\tCreate integration plan",
	"\tReplace client initialization",
	"\tMigrate room list implementation",
	"\tMigrate timeline/messaging",
	"\tIntegration testing & validation",
]

// MARK: - Small tests
@Suite struct BugScenarioTests {
	@Test func completedTasksAtHeadDoNotBreakTheChain() async throws {
		let fixture = try await ZionFixture.make()
		let controller = fixture.controller

		#expect(try await controller.getList(id: fixture.list.id)?.firstTaskId == fixture.documentation.id)
		#expect(try await controller.getAllTasks(on: fixture.listParent).count == 6)
		try await controller.integrityProblems(inList: fixture.list.id)
	}

	@Test func listViewHidesCompletedTasks() async throws {
		let fixture = try await ZionFixture.make()

		let visible = try await fixture.controller.outline(on: fixture.listParent)

		#expect(visible == mediaOutline + notificationsOutline + [
			"Priorities 6-10: Additional Features",
			"Reminders & Outstanding Items",
			"\tUpdate CONTEXT_SUMMARY.md documentation stats",
			"\tReview Rust SDK naming/architecture infractions",
			"\tRegenerate undocumented symbols list",
		])
	}

	@Test func listViewShowingCompletedIncludesThem() async throws {
		let fixture = try await ZionFixture.make()

		let all = try await fixture.controller.outline(on: fixture.listParent, includeCompleted: true)

		#expect(all.prefix(2) == ["Documentation (COMPLETE)", "Testing (COMPLETE)"])
		#expect(all.count == 14)
	}

	@Test func parentsKeepTheirOwnSubtasks() async throws {
		let fixture = try await ZionFixture.make()
		let controller = fixture.controller

		#expect(try await controller.labels(on: .task(hashID: fixture.media.itemHashId)) == mediaOutline.dropFirst().map { String($0.dropFirst()) })
		#expect(try await controller.getAllTasks(on: .task(hashID: fixture.notifications.itemHashId)).count == 2)
		#expect(try await controller.getAllTasks(on: .task(hashID: fixture.additional.itemHashId)).isEmpty)
		#expect(try await controller.getAllTasks(on: .task(hashID: fixture.reminders.itemHashId)).count == 3)
	}

	@Test func deleteFirstSubtaskOfThree() async throws {
		let fixture = try await ZionFixture.make()
		let controller = fixture.controller
		let remindersParent = ListController.TaskParent.task(hashID: fixture.reminders.itemHashId)

		try await controller.deleteTask(fixture.reminderSubtasks[0].id)

		#expect(try await controller.labels(on: remindersParent) == [
			"Review Rust SDK naming/architecture infractions",
			"Regenerate undocumented symbols list",
		])
		#expect(try await controller.getTask(id: fixture.reminders.id)?.firstSubtaskId == fixture.reminderSubtasks[1].id)
		try await controller.integrityProblems(inList: fixture.list.id)
	}

	@Test func deleteFirstSubtaskTwiceInARow() async throws {
		let fixture = try await ZionFixture.make()
		let controller = fixture.controller
		let remindersParent = ListController.TaskParent.task(hashID: fixture.reminders.itemHashId)

		try await controller.deleteTask(fixture.reminderSubtasks[0].id)
		try await controller.deleteTask(fixture.reminderSubtasks[1].id)

		#expect(try await controller.labels(on: remindersParent) == ["Regenerate undocumented symbols list"])
		#expect(try await controller.getTask(id: fixture.reminders.id)?.firstSubtaskId == fixture.reminderSubtasks[2].id)
		#expect(try await controller.getTask(id: fixture.reminderSubtasks[2].id)?.prevId == nil)
		try await controller.integrityProblems(inList: fixture.list.id)
	}

	@Test func deleteEverySubtaskLeavesParentEmpty() async throws {
		let fixture = try await ZionFixture.make()
		let controller = fixture.controller
		let remindersParent = ListController.TaskParent.task(hashID: fixture.reminders.itemHashId)

		for subtask in fixture.reminderSubtasks {
			try await controller.deleteTask(subtask.id)
		}

		#expect(try await controller.getAllTasks(on: remindersParent).isEmpty)
		#expect(try await controller.getTask(id: fixture.reminders.id)?.firstSubtaskId == nil)
		#expect(try await controller.getTask(id: fixture.reminders.id) != nil)
		try await controller.integrityProblems(inList: fixture.list.id)
	}

	@Test func deletingSubtasksDoesNotTouchOtherParents() async throws {
		let fixture = try await ZionFixture.make()
		let controller = fixture.controller

		for subtask in fixture.reminderSubtasks {
			try await controller.deleteTask(subtask.id)
		}

		#expect(try await controller.outline(on: .task(hashID: fixture.media.itemHashId)) == mediaOutline.dropFirst().map { String($0.dropFirst()) })
		#expect(try await controller.getAllTasks(on: .task(hashID: fixture.notifications.itemHashId)).count == 2)
		#expect(try await controller.getAllTasks(on: fixture.listParent).count == 6)
	}

	@Test func parentWithDeletedSubtasksAcceptsNewOnes() async throws {
		let fixture = try await ZionFixture.make()
		let controller = fixture.controller
		let remindersParent = ListController.TaskParent.task(hashID: fixture.reminders.itemHashId)
		for subtask in fixture.reminderSubtasks {
			try await controller.deleteTask(subtask.id)
		}

		let fresh = try await controller.addTask("fresh", to: remindersParent)

		#expect(try await controller.labels(on: remindersParent) == ["fresh"])
		#expect(try await controller.getTask(id: fixture.reminders.id)?.firstSubtaskId == fresh.id)
		try await controller.integrityProblems(inList: fixture.list.id)
	}

	@Test func newTopLevelTaskAfterSubtaskDeletionsJoinsTheEnd() async throws {
		let fixture = try await ZionFixture.make()
		let controller = fixture.controller
		for subtask in fixture.reminderSubtasks {
			try await controller.deleteTask(subtask.id)
		}

		let integration = try await controller.addTask("Integrate Zion into Element X main app", to: fixture.listParent)

		#expect(try await controller.getLastTask(on: fixture.listParent)?.id == integration.id)
		#expect(try await controller.getTask(id: fixture.reminders.id)?.nextId == integration.id)
		#expect(integration.prevId == fixture.reminders.id)
		try await controller.integrityProblems(inList: fixture.list.id)
	}

	@Test func newParentWithFiveSubtasksAfterDeletions() async throws {
		let fixture = try await ZionFixture.make()
		let controller = fixture.controller
		for subtask in fixture.reminderSubtasks {
			try await controller.deleteTask(subtask.id)
		}

		let integration = try await controller.addTask("Integrate Zion into Element X main app", to: fixture.listParent)
		for label in [
			"Create integration plan",
			"Replace client initialization",
			"Migrate room list implementation",
			"Migrate timeline/messaging",
			"Integration testing & validation",
		] {
			try await controller.addTask(label, to: .task(hashID: integration.itemHashId))
		}

		#expect(try await controller.outline(on: .task(hashID: integration.itemHashId)).count == 5)
		try await controller.integrityProblems(inList: fixture.list.id)
	}

	// MARK: - Mega test
	/// Follows `bug.sh` step by step, checking chain integrity and the visible outline at each stage.
	@Test func followsBugScript() async throws {
		let controller = try TestSupport.makeController()

		// 1. Create list
		let list = try await controller.createList(with: "zion-project", friendlyTitle: "zion-project", description: "zion-project")
		let listParent = ListController.TaskParent.list(list.id)
		try await controller.integrityProblems(inList: list.id)

		// 2-5. Two tasks, each marked complete
		let task1 = try await controller.addTask("Documentation (COMPLETE)", to: listParent)
		try await controller.updateTask(id: task1.id, isCompleted: .change(true))
		let task2 = try await controller.addTask("Testing (COMPLETE)", to: listParent)
		try await controller.updateTask(id: task2.id, isCompleted: .change(true))
		#expect(try await controller.outline(on: listParent).isEmpty)
		try await controller.integrityProblems(inList: list.id)

		// 6-9. Media Support with three subtasks
		let task3 = try await controller.addTask("Priority 4: Media Support", to: listParent)
		let task3Parent = ListController.TaskParent.task(hashID: task3.itemHashId)
		try await controller.addTask("File upload implementation", to: task3Parent)
		try await controller.addTask("Media download with caching", to: task3Parent)
		try await controller.addTask("Thumbnail generation", to: task3Parent)

		// 10-12. Notifications with two subtasks
		let task4 = try await controller.addTask("Priority 5: Notifications", to: listParent)
		let task4Parent = ListController.TaskParent.task(hashID: task4.itemHashId)
		try await controller.addTask("Push notification setup", to: task4Parent)
		try await controller.addTask("Notification settings UI/API", to: task4Parent)

		// 13. Task without subtasks
		try await controller.addTask("Priorities 6-10: Additional Features", to: listParent)

		// 14-17. Reminders with three subtasks
		let task5 = try await controller.addTask("Reminders & Outstanding Items", to: listParent)
		let task5Parent = ListController.TaskParent.task(hashID: task5.itemHashId)
		let subtask1 = try await controller.addTask("Update CONTEXT_SUMMARY.md documentation stats", to: task5Parent)
		let subtask2 = try await controller.addTask("Review Rust SDK naming/architecture infractions", to: task5Parent)
		let subtask3 = try await controller.addTask("Regenerate undocumented symbols list", to: task5Parent)

		// 18. View the list
		let remindersOutline = [
			"Reminders & Outstanding Items",
			"\tUpdate CONTEXT_SUMMARY.md documentation stats",
			"\tReview Rust SDK naming/architecture infractions",
			"\tRegenerate undocumented symbols list",
		]
		let additionalOutline = ["Priorities 6-10: Additional Features"]
		#expect(try await controller.outline(on: listParent) == mediaOutline + notificationsOutline + additionalOutline + remindersOutline)
		try await controller.integrityProblems(inList: list.id)

		// 19. Delete first subtask of Reminders
		try await controller.deleteTask(subtask1.id)
		#expect(try await controller.outline(on: listParent) == mediaOutline + notificationsOutline + additionalOutline + [
			"Reminders & Outstanding Items",
			"\tReview Rust SDK naming/architecture infractions",
			"\tRegenerate undocumented symbols list",
		])
		try await controller.integrityProblems(inList: list.id)

		// 20. Delete the (new) first subtask
		try await controller.deleteTask(subtask2.id)
		#expect(try await controller.outline(on: listParent) == mediaOutline + notificationsOutline + additionalOutline + [
			"Reminders & Outstanding Items",
			"\tRegenerate undocumented symbols list",
		])
		try await controller.integrityProblems(inList: list.id)

		// 21. Delete the last remaining subtask
		try await controller.deleteTask(subtask3.id)
		#expect(try await controller.outline(on: listParent) == mediaOutline + notificationsOutline + additionalOutline + [
			"Reminders & Outstanding Items",
		])
		#expect(try await controller.getTask(id: task5.id)?.firstSubtaskId == nil)
		try await controller.integrityProblems(inList: list.id)

		// 22-27. New top-level task with five subtasks
		let task6 = try await controller.addTask("Integrate Zion into Element X main app", to: listParent)
		let task6Parent = ListController.TaskParent.task(hashID: task6.itemHashId)
		for label in integrationOutline.dropFirst().map({ String($0.dropFirst()) }) {
			try await controller.addTask(label, to: task6Parent)
		}

		// 28. Final view
		#expect(try await controller.outline(on: listParent) == mediaOutline
			+ notificationsOutline
			+ additionalOutline
			+ ["Reminders & Outstanding Items"]
			+ integrationOutline)
		#expect(try await controller.getAllTasks(on: listParent).count == 7)
		// 7 top-level tasks + 3 (media) + 2 (notifications) + 0 (reminders) + 5 (integration) subtasks
		#expect(try await controller.getAllTasks().count == 17)
		try await controller.integrityProblems(inList: list.id)
	}
}
