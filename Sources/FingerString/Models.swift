import Foundation

/// A task list with items stored in linked list order
public struct TaskList: Codable, Identifiable, Sendable {
	public let id: Int64
	var id: Int64
	var slug: String
	var title: String?
	var description: String?
	var firstItemID: Int64?

	enum CodingKeys: String, CodingKey {
		case id
		case slug
		case title
		case description
		case firstItemID = "first_item_id"
	}
}

/// A task list item with optional sub-items
struct ListItem: Codable, Identifiable, Sendable {
	var id: Int64
	var listID: Int64
	var parentID: Int64?
	var nextID: Int64?
	var itemID: String
	var label: String
	var note: String?

	enum CodingKeys: String, CodingKey {
		case id
		case listID = "list_id"
		case parentID = "parent_id"
		case nextID = "next_id"
		case itemID = "item_id"
		case label
		case note
	}
}
