import Foundation

/// A task list with items stored in linked list order
public struct TaskList: Codable, Identifiable, Sendable {
	public var id: Int64
	public var slug: String
	public var title: String?
	public var description: String?
	public var firstItemID: Int64?

	public enum CodingKeys: String, CodingKey {
		case id
		case slug
		case title
		case description
		case firstItemID = "first_item_id"
	}

	public init(
		id: Int64,
		slug: String,
		title: String? = nil,
		description: String? = nil,
		firstItemID: Int64? = nil
	) {
		self.id = id
		self.slug = slug
		self.title = title
		self.description = description
		self.firstItemID = firstItemID
	}
}

/// A task list item with optional sub-items
public struct ListItem: Codable, Identifiable, Sendable {
	public var id: Int64
	public var listID: Int64
	public var parentID: Int64?
	public var nextID: Int64?
	public var itemID: String
	public var label: String
	public var note: String?

	public enum CodingKeys: String, CodingKey {
		case id
		case listID = "list_id"
		case parentID = "parent_id"
		case nextID = "next_id"
		case itemID = "item_id"
		case label
		case note
	}

	public init(
		id: Int64,
		listID: Int64,
		parentID: Int64? = nil,
		nextID: Int64? = nil,
		itemID: String,
		label: String,
		note: String? = nil
	) {
		self.id = id
		self.listID = listID
		self.parentID = parentID
		self.nextID = nextID
		self.itemID = itemID
		self.label = label
		self.note = note
	}
}
