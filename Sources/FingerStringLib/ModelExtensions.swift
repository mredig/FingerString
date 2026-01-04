extension TaskList {
	public var headerTitle: String {
		guard let title = title else {
			return slug
		}

		return "\(title) (\(slug))"
	}

	public var inlineTitle: String {
		title ?? slug
	}
}

extension TaskItem {
	mutating func setNext(_ nextTaskItem: inout TaskItem) {
		nextId = nextTaskItem.id
		nextTaskItem.prevId = id
	}
}
