import ArgumentParser
import FingerString
import Foundation

@main
struct FingerStringCLI: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "fingerstring",
		abstract: "A task list management tool",
		subcommands: [
			ListCommand.self,
			ItemCommand.self,
		]
	)
}

// MARK: - List Commands

struct ListCommand: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "list",
		abstract: "Manage task lists"
	)

	@Subcommand
	var subcommand: Subcommand

	enum Subcommand: AsyncParsableCommand {
		case create(CreateList)
		case view(ViewList)
		case delete(DeleteList)
		case all(ListAll)
	}
}

struct CreateList: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		abstract: "Create a new list"
	)

	@Argument(help: "Slug for the list (alphanumeric, dots, dashes, underscores)")
	var slug: String

	@Option(help: "Friendly title for the list")
	var title: String?

	@Option(help: "Description for the list")
	var description: String?

	func run() async throws {
		let db = try await FingerStringDatabase.create()
		let list = try await db.createList(
			slug: slug,
			title: title,
			description: description
		)
		print("Created list '\(list.slug)'")
		if let title = list.title {
			print("  Title: \(title)")
		}
	}
}

struct ViewList: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		abstract: "View a list and its items"
	)

	@Argument(help: "Slug of the list to view")
	var slug: String

	func run() async throws {
		let db = try await FingerStringDatabase.create()
		guard let list = try await db.getList(slug: slug) else {
			print("List not found: \(slug)")
			return
		}

		print("📋 \(list.slug)")
		if let title = list.title {
			print("   \(title)")
		}
		if let description = list.description {
			print("   \(description)")
		}
		print()

		let items = try await db.getItems(listSlug: slug)
		if items.isEmpty {
			print("   (empty)")
		} else {
			for item in items {
				printItem(item, db: db, indent: "   ")
			}
		}
	}

	private func printItem(
		_ item: ListItem,
		db: FingerStringDatabase,
		indent: String
	) {
		print("\(indent)• [\(item.itemID)] \(item.label)")
		if let note = item.note {
			print("\(indent)  \(note)")
		}
	}
}

struct DeleteList: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		abstract: "Delete a list"
	)

	@Argument(help: "Slug of the list to delete")
	var slug: String

	@Flag(help: "Skip confirmation")
	var force: Bool = false

	func run() async throws {
		if !force {
			print("Delete list '\(slug)'? (yes/no)")
			guard let input = readLine(),
				  input.lowercased() == "yes" else {
				print("Cancelled")
				return
			}
		}

		let db = try await FingerStringDatabase.create()
		try await db.deleteList(slug: slug)
		print("Deleted list '\(slug)'")
	}
}

struct ListAll: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "all",
		abstract: "List all lists"
	)

	func run() async throws {
		let db = try await FingerStringDatabase.create()
		let lists = try await db.getAllLists()

		if lists.isEmpty {
			print("No lists found")
			return
		}

		print("📚 Task Lists:")
		for list in lists {
			print("  • \(list.slug)", terminator: "")
			if let title = list.title {
				print(" - \(title)", terminator: "")
			}
			print()
		}
	}
}

// MARK: - Item Commands

struct ItemCommand: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "item",
		abstract: "Manage list items"
	)

	@Subcommand
	var subcommand: Subcommand

	enum Subcommand: AsyncParsableCommand {
		case add(AddItem)
		case delete(DeleteItem)
		case move(MoveItem)
	}
}

struct AddItem: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		abstract: "Add an item to a list"
	)

	@Argument(help: "Slug of the target list")
	var listSlug: String

	@Argument(help: "Label for the item")
	var label: String

	@Option(help: "Optional note for the item")
	var note: String?

	@Option(help: "Parent item ID for sub-items")
	var parent: String?

	func run() async throws {
		let db = try await FingerStringDatabase.create()
		let item = try await db.addItem(
			to: listSlug,
			label: label,
			note: note
		)
		print("Added item: [\(item.itemID)] \(item.label)")
	}
}

struct DeleteItem: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		abstract: "Delete an item"
	)

	@Argument(help: "ID of the item to delete")
	var itemID: Int64

	@Flag(help: "Skip confirmation")
	var force: Bool = false

	func run() async throws {
		if !force {
			print("Delete item? (yes/no)")
			guard let input = readLine(),
				  input.lowercased() == "yes" else {
				print("Cancelled")
				return
			}
		}

		let db = try await FingerStringDatabase.create()
		try await db.deleteItem(id: itemID)
		print("Deleted item")
	}
}

struct MoveItem: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		abstract: "Move an item to a new position"
	)

	@Argument(help: "ID of the item to move")
	var itemID: Int64

	@Option(help: "Move before this item ID (omit to move to end)")
	var before: Int64?

	func run() async throws {
		let db = try await FingerStringDatabase.create()
		try await db.moveItem(id: itemID, beforeID: before)
		print("Moved item")
	}
}
