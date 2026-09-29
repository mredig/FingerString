import Foundation
import Lighter
import SQLite3
import FingerStringLib

enum TestSupport {
	/// Creates a `ListController` backed by a fresh, private in-memory SQLite database.
	static func makeController() throws -> ListController {
		var handle: OpaquePointer?
		let rc = sqlite3_create_fingerstringdb(
			":memory:",
			SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
			&handle)
		guard rc == SQLITE_OK else { throw ListController.DBError.cannotCreateDB }

		let handler = SharedConnectionHandler(handle: handle)
		return ListController(db: FingerStringDB(connectionHandler: handler))
	}
}

/// Keeps one connection open for the life of a test, and hands it to every caller, including overlapping ones.
///
/// Tests use an in-memory database so they never touch disk or each other. But an in-memory database only
/// exists while its connection is open, and no other connection can see it. Lighter's `reopen` and
/// `simplePool` handlers close connections between calls, which would erase the schema and data, and a
/// second connection would get a separate, empty database. So this handler never closes the connection
/// until it is deallocated (after the controller and anything still using it is gone).
///
/// It must also allow overlapping use. Lighter's `unsafeReuse` handler asserts on that, but
/// `ListController` does overlap calls (`async let` in `deleteTask`, and the task stream that keeps
/// running after an early return). Sharing one connection across threads is only safe in SQLite's
/// serialized mode, so the connection is opened with `SQLITE_OPEN_FULLMUTEX` rather than relying on
/// the system library's default threading mode.
private final class SharedConnectionHandler: SQLConnectionHandler, @unchecked Sendable {
	private let handle: OpaquePointer?

	init(handle: OpaquePointer?) {
		self.handle = handle
		super.init(url: URL(filePath: ":memory:"))
	}

	deinit {
		sqlite3_close(handle)
	}

	override func openConnection(_ configuration: Configuration) throws -> OpaquePointer {
		guard let handle else {
			throw ListController.DBError.cannotCreateDB
		}
		return handle
	}

	override func releaseConnection(
		_ connection: OpaquePointer?,
		with configuration: Configuration,
		afterError error: Error? = nil
	) {}
}
