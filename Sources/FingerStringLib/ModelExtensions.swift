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
