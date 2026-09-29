import Foundation
import Lighter
import SQLite3
@testable import FingerStringLib

enum TestSupport {
	/// Creates a `ListController` backed by a fresh, private in-memory SQLite database.
	static func makeController() throws -> ListController {
		var handle: OpaquePointer?
		let rc = sqlite3_create_fingerstringdb(
			":memory:",
			SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE,
			&handle)
		guard rc == SQLITE_OK else { throw ListController.DBError.cannotCreateDB }

		let handler = SQLConnectionHandler.unsafeReuse(
			handle,
			url: URL(filePath: ":memory:"),
			closeOnDeinit: true)
		return ListController(db: FingerStringDB(connectionHandler: handler))
	}
}
