// Autocreated by sqlite2swift at 2026-01-02T23:58:49Z

import SQLite3
import Foundation
import Lighter

/// Create a SQLite3 database
/// 
/// The database is created using the SQL `create` statements in the
/// Schema structures.
/// 
/// If the operation is successful, the open database handle will be
/// returned in the `db` `inout` parameter.
/// If the open succeeds, but the SQL execution fails, an incomplete
/// database can be left behind. I.e. if an error happens, the path
/// should be tested and deleted if appropriate.
/// 
/// Example:
/// ```swift
/// var db : OpaquePointer!
/// let rc = sqlite3_create_fingerstringdb(path, &db)
/// ```
/// 
/// - Parameters:
///   - path: Path of the database.
///   - flags: Custom open flags.
///   - db: A SQLite3 database handle, if successful.
/// - Returns: The SQLite3 error code (`SQLITE_OK` on success).
@inlinable
public func sqlite3_create_fingerstringdb(
	_ path: UnsafePointer<CChar>!,
	_ flags: Int32 = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE,
	_ db: inout OpaquePointer?
) -> Int32
{
	let openrc = sqlite3_open_v2(path, &db, flags, nil)
	if openrc != SQLITE_OK {
		return openrc
	}
	let execrc = sqlite3_exec(db, FingerStringDB.creationSQL, nil, nil, nil)
	if execrc != SQLITE_OK {
		sqlite3_close(db)
		db = nil
		return execrc
	}
	return SQLITE_OK
}

/// Insert a ``TaskList`` record in the SQLite database.
/// 
/// This operates on a raw SQLite database handle (as returned by
/// `sqlite3_open`).
/// 
/// Example:
/// ```swift
/// let rc = sqlite3_task_list_insert(db, record)
/// assert(rc == SQLITE_OK)
/// ```
/// 
/// - Parameters:
///   - db: SQLite3 database handle.
///   - record: The record to insert. Updated with the actual table values (e.g. assigned primary key).
/// - Returns: The SQLite error code (of `sqlite3_prepare/step`), e.g. `SQLITE_OK`.
@inlinable
@discardableResult
public func sqlite3_task_list_insert(
	_ db: OpaquePointer!,
	_ record: inout TaskList
) -> Int32
{
	let sql = FingerStringDB.useInsertReturning ? TaskList.Schema.insertReturning : TaskList.Schema.insert
	var handle : OpaquePointer? = nil
	guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
	      let statement = handle else { return sqlite3_errcode(db) }
	defer { sqlite3_finalize(statement) }
	return record.bind(to: statement, indices: TaskList.Schema.insertParameterIndices) {
		let rc = sqlite3_step(statement)
		if rc == SQLITE_DONE {
			var sql = TaskList.Schema.select
			sql.append(#" WHERE ROWID = last_insert_rowid()"#)
			var handle : OpaquePointer? = nil
			guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
			      let statement = handle else { return sqlite3_errcode(db) }
			defer { sqlite3_finalize(statement) }
			let rc = sqlite3_step(statement)
			if rc == SQLITE_DONE {
				return SQLITE_OK
			}
			else if rc != SQLITE_ROW {
				return sqlite3_errcode(db)
			}
			record = TaskList(statement, indices: TaskList.Schema.selectColumnIndices)
			return SQLITE_OK
		}
		else if rc != SQLITE_ROW {
			return sqlite3_errcode(db)
		}
		record = TaskList(statement, indices: TaskList.Schema.selectColumnIndices)
		return SQLITE_OK
	}
}

/// Update a ``TaskList`` record in the SQLite database.
/// 
/// This operates on a raw SQLite database handle (as returned by
/// `sqlite3_open`).
/// 
/// Example:
/// ```swift
/// let rc = sqlite3_task_list_update(db, record)
/// assert(rc == SQLITE_OK)
/// ```
/// 
/// - Parameters:
///   - db: SQLite3 database handle.
///   - record: The ``TaskList`` record to update.
/// - Returns: The SQLite error code (of `sqlite3_prepare/step`), e.g. `SQLITE_OK`.
@inlinable
@discardableResult
public func sqlite3_task_list_update(_ db: OpaquePointer!, _ record: TaskList)
	-> Int32
{
	let sql = TaskList.Schema.update
	var handle : OpaquePointer? = nil
	guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
	      let statement = handle else { return sqlite3_errcode(db) }
	defer { sqlite3_finalize(statement) }
	return record.bind(to: statement, indices: TaskList.Schema.updateParameterIndices) {
		let rc = sqlite3_step(statement)
		return rc != SQLITE_DONE && rc != SQLITE_ROW ? sqlite3_errcode(db) : SQLITE_OK
	}
}

/// Delete a ``TaskList`` record in the SQLite database.
/// 
/// This operates on a raw SQLite database handle (as returned by
/// `sqlite3_open`).
/// 
/// Example:
/// ```swift
/// let rc = sqlite3_task_list_delete(db, record)
/// assert(rc == SQLITE_OK)
/// ```
/// 
/// - Parameters:
///   - db: SQLite3 database handle.
///   - record: The ``TaskList`` record to delete.
/// - Returns: The SQLite error code (of `sqlite3_prepare/step`), e.g. `SQLITE_OK`.
@inlinable
@discardableResult
public func sqlite3_task_list_delete(_ db: OpaquePointer!, _ record: TaskList)
	-> Int32
{
	let sql = TaskList.Schema.delete
	var handle : OpaquePointer? = nil
	guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
	      let statement = handle else { return sqlite3_errcode(db) }
	defer { sqlite3_finalize(statement) }
	sqlite3_bind_int64(statement, 1, Int64(record.id))
	let rc = sqlite3_step(statement)
	return rc != SQLITE_DONE && rc != SQLITE_ROW ? sqlite3_errcode(db) : SQLITE_OK
}

/// Fetch ``TaskList`` records, filtering using a Swift closure.
/// 
/// This is fetching full ``TaskList`` records from the passed in SQLite database
/// handle. The filtering is done within SQLite, but using a Swift closure
/// that can be passed in.
/// 
/// Within that closure other SQL queries can be done on separate connections,
/// but *not* within the same database handle that is being passed in (because
/// the closure is executed in the context of the query).
/// 
/// Sorting can be done using raw SQL (by passing in a `orderBy` parameter,
/// e.g. `orderBy: "name DESC"`),
/// or just in Swift (e.g. `fetch(in: db).sorted { $0.name > $1.name }`).
/// Since the matching is done in Swift anyways, the primary advantage of
/// doing it in SQL is that a `LIMIT` can be applied efficiently (i.e. w/o
/// walking and loading all rows).
/// 
/// If the function returns `nil`, the error can be found using the usual
/// `sqlite3_errcode` and companions.
/// 
/// Example:
/// ```swift
/// let records = sqlite3_task_lists_fetch(db) { record in
///   record.name != "Duck"
/// }
/// 
/// let records = sqlite3_task_lists_fetch(db, orderBy: "name", limit: 5) {
///   $0.firstname != nil
/// }
/// ```
/// 
/// - Parameters:
///   - db: The SQLite database handle (as returned by `sqlite3_open`)
///   - sql: Optional custom SQL yielding ``TaskList`` records.
///   - orderBySQL: If set, some SQL that is added as an `ORDER BY` clause (e.g. `name DESC`).
///   - limit: An optional fetch limit.
///   - filter: A Swift closure used for filtering, taking the``TaskList`` record to be matched.
/// - Returns: The records matching the query, or `nil` if there was an error.
@inlinable
public func sqlite3_task_lists_fetch(
	_ db: OpaquePointer!,
	sql customSQL: String? = nil,
	orderBy orderBySQL: String? = nil,
	limit: Int? = nil,
	filter: @escaping ( TaskList ) -> Bool
) -> [ TaskList ]?
{
	withUnsafePointer(to: filter) { ( closurePtr ) in
		guard TaskList.Schema.registerSwiftMatcher(
			in: db,
			flags: SQLITE_UTF8,
			matcher: closurePtr
		) == SQLITE_OK else {
			return nil
		}
		defer {
			TaskList.Schema.unregisterSwiftMatcher(in: db, flags: SQLITE_UTF8)
		}
		var sql = customSQL ?? TaskList.Schema.matchSelect
		if let orderBySQL = orderBySQL {
			sql.append(" ORDER BY \(orderBySQL)")
		}
		if let limit = limit {
			sql.append(" LIMIT \(limit)")
		}
		var handle : OpaquePointer? = nil
		guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
		      let statement = handle else { return nil }
		defer { sqlite3_finalize(statement) }
		let indices = customSQL != nil ? TaskList.Schema.lookupColumnIndices(in: statement) : TaskList.Schema.selectColumnIndices
		var records = [ TaskList ]()
		while true {
			let rc = sqlite3_step(statement)
			if rc == SQLITE_DONE {
				break
			}
			else if rc != SQLITE_ROW {
				return nil
			}
			records.append(TaskList(statement, indices: indices))
		}
		return records
	}
}

/// Fetch ``TaskList`` records using the base SQLite API.
/// 
/// If the function returns `nil`, the error can be found using the usual
/// `sqlite3_errcode` and companions.
/// 
/// Example:
/// ```swift
/// let records = sqlite3_task_lists_fetch(
///   db, sql: #"SELECT * FROM task_list"#
/// }
/// 
/// let records = sqlite3_task_lists_fetch(
///   db, sql: #"SELECT * FROM task_list"#,
///   orderBy: "name", limit: 5
/// )
/// ```
/// 
/// - Parameters:
///   - db: The SQLite database handle (as returned by `sqlite3_open`)
///   - sql: Custom SQL yielding ``TaskList`` records.
///   - orderBySQL: If set, some SQL that is added as an `ORDER BY` clause (e.g. `name DESC`).
///   - limit: An optional fetch limit.
/// - Returns: The records matching the query, or `nil` if there was an error.
@inlinable
public func sqlite3_task_lists_fetch(
	_ db: OpaquePointer!,
	sql customSQL: String? = nil,
	orderBy orderBySQL: String? = nil,
	limit: Int? = nil
) -> [ TaskList ]?
{
	var sql = customSQL ?? TaskList.Schema.select
	if let orderBySQL = orderBySQL {
		sql.append(" ORDER BY \(orderBySQL)")
	}
	if let limit = limit {
		sql.append(" LIMIT \(limit)")
	}
	var handle : OpaquePointer? = nil
	guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
	      let statement = handle else { return nil }
	defer { sqlite3_finalize(statement) }
	let indices = customSQL != nil ? TaskList.Schema.lookupColumnIndices(in: statement) : TaskList.Schema.selectColumnIndices
	var records = [ TaskList ]()
	while true {
		let rc = sqlite3_step(statement)
		if rc == SQLITE_DONE {
			break
		}
		else if rc != SQLITE_ROW {
			return nil
		}
		records.append(TaskList(statement, indices: indices))
	}
	return records
}

/// Fetch a ``TaskList`` record the base SQLite API.
/// 
/// If the function returns `nil`, the error can be found using the usual
/// `sqlite3_errcode` and companions.
/// 
/// Example:
/// ```swift
/// let record = sqlite3_task_list_find(db, 10) {
///   print("Found record:", record)
/// }
/// ```
/// 
/// - Parameters:
///   - db: The SQLite database handle (as returned by `sqlite3_open`)
///   - sql: Optional custom SQL yielding ``TaskList`` records, has one `?` parameter containing the ID.
///   - primaryKey: The primary key value to lookup (e.g. `10`)
/// - Returns: The record matching the query, or `nil` if it wasn't found or there was an error.
@inlinable
public func sqlite3_task_list_find(
	_ db: OpaquePointer!,
	sql customSQL: String? = nil,
	_ primaryKey: Int
) -> TaskList?
{
	var sql = customSQL ?? TaskList.Schema.select
	if customSQL != nil {
		sql.append(#" WHERE "id" = ? LIMIT 1"#)
	}
	var handle : OpaquePointer? = nil
	guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
	      let statement = handle else { return nil }
	defer { sqlite3_finalize(statement) }
	sqlite3_bind_int64(statement, 1, Int64(primaryKey))
	let rc = sqlite3_step(statement)
	if rc == SQLITE_DONE {
		return nil
	}
	else if rc != SQLITE_ROW {
		return nil
	}
	let indices = customSQL != nil ? TaskList.Schema.lookupColumnIndices(in: statement) : TaskList.Schema.selectColumnIndices
	return TaskList(statement, indices: indices)
}

/// Fetches the ``TaskItem`` records related to a ``TaskList`` (`listId`).
/// 
/// This fetches the related ``TaskItem`` records using the
/// ``TaskItem/listId`` property.
/// 
/// Example:
/// ```swift
/// let record         : TaskList = ...
/// let relatedRecords = sqlite3_task_items_fetch(db, forList: record)
/// ```
/// 
/// - Parameters:
///   - db: The SQLite database handle (as returned by `sqlite3_open`)
///   - record: The ``TaskList`` record.
///   - orderBySQL: If set, some SQL that is added as an `ORDER BY` clause (e.g. `name DESC`).
///   - limit: An optional fetch limit.
/// - Returns: The related ``TaskItem`` records.
@inlinable
public func sqlite3_task_items_fetch(
	_ db: OpaquePointer!,
	forList record: TaskList,
	orderBy orderBySQL: String? = nil,
	limit: Int? = nil
) -> [ TaskItem ]?
{
	var sql = TaskItem.Schema.select
	sql.append(#" WHERE "list_id" = ? LIMIT 1"#)
	if let orderBySQL = orderBySQL {
		sql.append(" ORDER BY \(orderBySQL)")
	}
	if let limit = limit {
		sql.append(" LIMIT \(limit)")
	}
	var handle : OpaquePointer? = nil
	guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
	      let statement = handle else { return nil }
	defer { sqlite3_finalize(statement) }
	sqlite3_bind_int64(statement, 1, Int64(record.id))
	let indices = TaskItem.Schema.selectColumnIndices
	var records = [ TaskItem ]()
	while true {
		let rc = sqlite3_step(statement)
		if rc == SQLITE_DONE {
			break
		}
		else if rc != SQLITE_ROW {
			return nil
		}
		records.append(TaskItem(statement, indices: indices))
	}
	return records
}

/// Insert a ``TaskItem`` record in the SQLite database.
/// 
/// This operates on a raw SQLite database handle (as returned by
/// `sqlite3_open`).
/// 
/// Example:
/// ```swift
/// let rc = sqlite3_task_item_insert(db, record)
/// assert(rc == SQLITE_OK)
/// ```
/// 
/// - Parameters:
///   - db: SQLite3 database handle.
///   - record: The record to insert. Updated with the actual table values (e.g. assigned primary key).
/// - Returns: The SQLite error code (of `sqlite3_prepare/step`), e.g. `SQLITE_OK`.
@inlinable
@discardableResult
public func sqlite3_task_item_insert(
	_ db: OpaquePointer!,
	_ record: inout TaskItem
) -> Int32
{
	let sql = FingerStringDB.useInsertReturning ? TaskItem.Schema.insertReturning : TaskItem.Schema.insert
	var handle : OpaquePointer? = nil
	guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
	      let statement = handle else { return sqlite3_errcode(db) }
	defer { sqlite3_finalize(statement) }
	return record.bind(to: statement, indices: TaskItem.Schema.insertParameterIndices) {
		let rc = sqlite3_step(statement)
		if rc == SQLITE_DONE {
			var sql = TaskItem.Schema.select
			sql.append(#" WHERE ROWID = last_insert_rowid()"#)
			var handle : OpaquePointer? = nil
			guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
			      let statement = handle else { return sqlite3_errcode(db) }
			defer { sqlite3_finalize(statement) }
			let rc = sqlite3_step(statement)
			if rc == SQLITE_DONE {
				return SQLITE_OK
			}
			else if rc != SQLITE_ROW {
				return sqlite3_errcode(db)
			}
			record = TaskItem(statement, indices: TaskItem.Schema.selectColumnIndices)
			return SQLITE_OK
		}
		else if rc != SQLITE_ROW {
			return sqlite3_errcode(db)
		}
		record = TaskItem(statement, indices: TaskItem.Schema.selectColumnIndices)
		return SQLITE_OK
	}
}

/// Update a ``TaskItem`` record in the SQLite database.
/// 
/// This operates on a raw SQLite database handle (as returned by
/// `sqlite3_open`).
/// 
/// Example:
/// ```swift
/// let rc = sqlite3_task_item_update(db, record)
/// assert(rc == SQLITE_OK)
/// ```
/// 
/// - Parameters:
///   - db: SQLite3 database handle.
///   - record: The ``TaskItem`` record to update.
/// - Returns: The SQLite error code (of `sqlite3_prepare/step`), e.g. `SQLITE_OK`.
@inlinable
@discardableResult
public func sqlite3_task_item_update(_ db: OpaquePointer!, _ record: TaskItem)
	-> Int32
{
	let sql = TaskItem.Schema.update
	var handle : OpaquePointer? = nil
	guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
	      let statement = handle else { return sqlite3_errcode(db) }
	defer { sqlite3_finalize(statement) }
	return record.bind(to: statement, indices: TaskItem.Schema.updateParameterIndices) {
		let rc = sqlite3_step(statement)
		return rc != SQLITE_DONE && rc != SQLITE_ROW ? sqlite3_errcode(db) : SQLITE_OK
	}
}

/// Delete a ``TaskItem`` record in the SQLite database.
/// 
/// This operates on a raw SQLite database handle (as returned by
/// `sqlite3_open`).
/// 
/// Example:
/// ```swift
/// let rc = sqlite3_task_item_delete(db, record)
/// assert(rc == SQLITE_OK)
/// ```
/// 
/// - Parameters:
///   - db: SQLite3 database handle.
///   - record: The ``TaskItem`` record to delete.
/// - Returns: The SQLite error code (of `sqlite3_prepare/step`), e.g. `SQLITE_OK`.
@inlinable
@discardableResult
public func sqlite3_task_item_delete(_ db: OpaquePointer!, _ record: TaskItem)
	-> Int32
{
	let sql = TaskItem.Schema.delete
	var handle : OpaquePointer? = nil
	guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
	      let statement = handle else { return sqlite3_errcode(db) }
	defer { sqlite3_finalize(statement) }
	sqlite3_bind_int64(statement, 1, Int64(record.id))
	let rc = sqlite3_step(statement)
	return rc != SQLITE_DONE && rc != SQLITE_ROW ? sqlite3_errcode(db) : SQLITE_OK
}

/// Fetch ``TaskItem`` records, filtering using a Swift closure.
/// 
/// This is fetching full ``TaskItem`` records from the passed in SQLite database
/// handle. The filtering is done within SQLite, but using a Swift closure
/// that can be passed in.
/// 
/// Within that closure other SQL queries can be done on separate connections,
/// but *not* within the same database handle that is being passed in (because
/// the closure is executed in the context of the query).
/// 
/// Sorting can be done using raw SQL (by passing in a `orderBy` parameter,
/// e.g. `orderBy: "name DESC"`),
/// or just in Swift (e.g. `fetch(in: db).sorted { $0.name > $1.name }`).
/// Since the matching is done in Swift anyways, the primary advantage of
/// doing it in SQL is that a `LIMIT` can be applied efficiently (i.e. w/o
/// walking and loading all rows).
/// 
/// If the function returns `nil`, the error can be found using the usual
/// `sqlite3_errcode` and companions.
/// 
/// Example:
/// ```swift
/// let records = sqlite3_task_items_fetch(db) { record in
///   record.name != "Duck"
/// }
/// 
/// let records = sqlite3_task_items_fetch(db, orderBy: "name", limit: 5) {
///   $0.firstname != nil
/// }
/// ```
/// 
/// - Parameters:
///   - db: The SQLite database handle (as returned by `sqlite3_open`)
///   - sql: Optional custom SQL yielding ``TaskItem`` records.
///   - orderBySQL: If set, some SQL that is added as an `ORDER BY` clause (e.g. `name DESC`).
///   - limit: An optional fetch limit.
///   - filter: A Swift closure used for filtering, taking the``TaskItem`` record to be matched.
/// - Returns: The records matching the query, or `nil` if there was an error.
@inlinable
public func sqlite3_task_items_fetch(
	_ db: OpaquePointer!,
	sql customSQL: String? = nil,
	orderBy orderBySQL: String? = nil,
	limit: Int? = nil,
	filter: @escaping ( TaskItem ) -> Bool
) -> [ TaskItem ]?
{
	withUnsafePointer(to: filter) { ( closurePtr ) in
		guard TaskItem.Schema.registerSwiftMatcher(
			in: db,
			flags: SQLITE_UTF8,
			matcher: closurePtr
		) == SQLITE_OK else {
			return nil
		}
		defer {
			TaskItem.Schema.unregisterSwiftMatcher(in: db, flags: SQLITE_UTF8)
		}
		var sql = customSQL ?? TaskItem.Schema.matchSelect
		if let orderBySQL = orderBySQL {
			sql.append(" ORDER BY \(orderBySQL)")
		}
		if let limit = limit {
			sql.append(" LIMIT \(limit)")
		}
		var handle : OpaquePointer? = nil
		guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
		      let statement = handle else { return nil }
		defer { sqlite3_finalize(statement) }
		let indices = customSQL != nil ? TaskItem.Schema.lookupColumnIndices(in: statement) : TaskItem.Schema.selectColumnIndices
		var records = [ TaskItem ]()
		while true {
			let rc = sqlite3_step(statement)
			if rc == SQLITE_DONE {
				break
			}
			else if rc != SQLITE_ROW {
				return nil
			}
			records.append(TaskItem(statement, indices: indices))
		}
		return records
	}
}

/// Fetch ``TaskItem`` records using the base SQLite API.
/// 
/// If the function returns `nil`, the error can be found using the usual
/// `sqlite3_errcode` and companions.
/// 
/// Example:
/// ```swift
/// let records = sqlite3_task_items_fetch(
///   db, sql: #"SELECT * FROM task_item"#
/// }
/// 
/// let records = sqlite3_task_items_fetch(
///   db, sql: #"SELECT * FROM task_item"#,
///   orderBy: "name", limit: 5
/// )
/// ```
/// 
/// - Parameters:
///   - db: The SQLite database handle (as returned by `sqlite3_open`)
///   - sql: Custom SQL yielding ``TaskItem`` records.
///   - orderBySQL: If set, some SQL that is added as an `ORDER BY` clause (e.g. `name DESC`).
///   - limit: An optional fetch limit.
/// - Returns: The records matching the query, or `nil` if there was an error.
@inlinable
public func sqlite3_task_items_fetch(
	_ db: OpaquePointer!,
	sql customSQL: String? = nil,
	orderBy orderBySQL: String? = nil,
	limit: Int? = nil
) -> [ TaskItem ]?
{
	var sql = customSQL ?? TaskItem.Schema.select
	if let orderBySQL = orderBySQL {
		sql.append(" ORDER BY \(orderBySQL)")
	}
	if let limit = limit {
		sql.append(" LIMIT \(limit)")
	}
	var handle : OpaquePointer? = nil
	guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
	      let statement = handle else { return nil }
	defer { sqlite3_finalize(statement) }
	let indices = customSQL != nil ? TaskItem.Schema.lookupColumnIndices(in: statement) : TaskItem.Schema.selectColumnIndices
	var records = [ TaskItem ]()
	while true {
		let rc = sqlite3_step(statement)
		if rc == SQLITE_DONE {
			break
		}
		else if rc != SQLITE_ROW {
			return nil
		}
		records.append(TaskItem(statement, indices: indices))
	}
	return records
}

/// Fetch a ``TaskItem`` record the base SQLite API.
/// 
/// If the function returns `nil`, the error can be found using the usual
/// `sqlite3_errcode` and companions.
/// 
/// Example:
/// ```swift
/// let record = sqlite3_task_item_find(db, 10) {
///   print("Found record:", record)
/// }
/// ```
/// 
/// - Parameters:
///   - db: The SQLite database handle (as returned by `sqlite3_open`)
///   - sql: Optional custom SQL yielding ``TaskItem`` records, has one `?` parameter containing the ID.
///   - primaryKey: The primary key value to lookup (e.g. `10`)
/// - Returns: The record matching the query, or `nil` if it wasn't found or there was an error.
@inlinable
public func sqlite3_task_item_find(
	_ db: OpaquePointer!,
	sql customSQL: String? = nil,
	_ primaryKey: Int
) -> TaskItem?
{
	var sql = customSQL ?? TaskItem.Schema.select
	if customSQL != nil {
		sql.append(#" WHERE "id" = ? LIMIT 1"#)
	}
	var handle : OpaquePointer? = nil
	guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
	      let statement = handle else { return nil }
	defer { sqlite3_finalize(statement) }
	sqlite3_bind_int64(statement, 1, Int64(primaryKey))
	let rc = sqlite3_step(statement)
	if rc == SQLITE_DONE {
		return nil
	}
	else if rc != SQLITE_ROW {
		return nil
	}
	let indices = customSQL != nil ? TaskItem.Schema.lookupColumnIndices(in: statement) : TaskItem.Schema.selectColumnIndices
	return TaskItem(statement, indices: indices)
}

/// Fetch the ``TaskList`` record related to an ``TaskItem`` (`listId`).
/// 
/// This fetches the related ``TaskList`` record using the
/// ``TaskItem/listId`` property.
/// 
/// Example:
/// ```swift
/// let sourceRecord  : TaskItem = ...
/// let relatedRecord = sqlite3_task_list_find(db, for: sourceRecord)
/// ```
/// 
/// - Parameters:
///   - db: The SQLite database handle (as returned by `sqlite3_open`)
///   - record: The ``TaskItem`` record.
/// - Returns: The related ``TaskList`` record, or `nil` if not found/error.
@inlinable
public func sqlite3_task_list_find(_ db: OpaquePointer!, `for` record: TaskItem)
	-> TaskList?
{
	var sql = TaskList.Schema.select
	sql.append(#" WHERE "id" = ? LIMIT 1"#)
	var handle : OpaquePointer? = nil
	guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
	      let statement = handle else { return nil }
	defer { sqlite3_finalize(statement) }
	sqlite3_bind_int64(statement, 1, Int64(record.listId))
	let rc = sqlite3_step(statement)
	if rc == SQLITE_DONE {
		return nil
	}
	else if rc != SQLITE_ROW {
		return nil
	}
	let indices = TaskList.Schema.selectColumnIndices
	return TaskList(statement, indices: indices)
}

/// Fetch the ``TaskItem`` record related to itself (`parentId`).
/// 
/// This fetches the related ``TaskItem`` record using the
/// ``TaskItem/parentId`` property.
/// 
/// Example:
/// ```swift
/// let sourceRecord  : TaskItem = ...
/// let relatedRecord = sqlite3_task_item_find(db, forParent: sourceRecord)
/// ```
/// 
/// - Parameters:
///   - db: The SQLite database handle (as returned by `sqlite3_open`)
///   - record: The ``TaskItem`` record.
/// - Returns: The related ``TaskItem`` record, or `nil` if not found/error.
@inlinable
public func sqlite3_task_item_find(
	_ db: OpaquePointer!,
	forParent record: TaskItem
) -> TaskItem?
{
	var sql = TaskItem.Schema.select
	sql.append(#" WHERE "id" = ? LIMIT 1"#)
	var handle : OpaquePointer? = nil
	guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
	      let statement = handle else { return nil }
	defer { sqlite3_finalize(statement) }
	if let fkey = record.parentId {
		sqlite3_bind_int64(statement, 1, Int64(fkey))
	}
	else {
		sqlite3_bind_null(statement, 1)
	}
	let rc = sqlite3_step(statement)
	if rc == SQLITE_DONE {
		return nil
	}
	else if rc != SQLITE_ROW {
		return nil
	}
	let indices = TaskItem.Schema.selectColumnIndices
	return TaskItem(statement, indices: indices)
}

/// Fetch the ``TaskItem`` record related to itself (`nextId`).
/// 
/// This fetches the related ``TaskItem`` record using the
/// ``TaskItem/nextId`` property.
/// 
/// Example:
/// ```swift
/// let sourceRecord  : TaskItem = ...
/// let relatedRecord = sqlite3_task_item_find(db, forNext: sourceRecord)
/// ```
/// 
/// - Parameters:
///   - db: The SQLite database handle (as returned by `sqlite3_open`)
///   - record: The ``TaskItem`` record.
/// - Returns: The related ``TaskItem`` record, or `nil` if not found/error.
@inlinable
public func sqlite3_task_item_find(_ db: OpaquePointer!, forNext record: TaskItem)
	-> TaskItem?
{
	var sql = TaskItem.Schema.select
	sql.append(#" WHERE "id" = ? LIMIT 1"#)
	var handle : OpaquePointer? = nil
	guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
	      let statement = handle else { return nil }
	defer { sqlite3_finalize(statement) }
	if let fkey = record.nextId {
		sqlite3_bind_int64(statement, 1, Int64(fkey))
	}
	else {
		sqlite3_bind_null(statement, 1)
	}
	let rc = sqlite3_step(statement)
	if rc == SQLITE_DONE {
		return nil
	}
	else if rc != SQLITE_ROW {
		return nil
	}
	let indices = TaskItem.Schema.selectColumnIndices
	return TaskItem(statement, indices: indices)
}

/// Fetches the ``TaskItem`` records related to itself (`parentId`).
/// 
/// This fetches the related ``TaskItem`` records using the
/// ``TaskItem/parentId`` property.
/// 
/// Example:
/// ```swift
/// let record         : TaskItem = ...
/// let relatedRecords = sqlite3_task_items_fetch(db, forParent: record)
/// ```
/// 
/// - Parameters:
///   - db: The SQLite database handle (as returned by `sqlite3_open`)
///   - record: The ``TaskItem`` record.
///   - orderBySQL: If set, some SQL that is added as an `ORDER BY` clause (e.g. `name DESC`).
///   - limit: An optional fetch limit.
/// - Returns: The related ``TaskItem`` records.
@inlinable
public func sqlite3_task_items_fetch(
	_ db: OpaquePointer!,
	forParent record: TaskItem,
	orderBy orderBySQL: String? = nil,
	limit: Int? = nil
) -> [ TaskItem ]?
{
	var sql = TaskItem.Schema.select
	sql.append(#" WHERE "parent_id" = ? LIMIT 1"#)
	if let orderBySQL = orderBySQL {
		sql.append(" ORDER BY \(orderBySQL)")
	}
	if let limit = limit {
		sql.append(" LIMIT \(limit)")
	}
	var handle : OpaquePointer? = nil
	guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
	      let statement = handle else { return nil }
	defer { sqlite3_finalize(statement) }
	sqlite3_bind_int64(statement, 1, Int64(record.id))
	let indices = TaskItem.Schema.selectColumnIndices
	var records = [ TaskItem ]()
	while true {
		let rc = sqlite3_step(statement)
		if rc == SQLITE_DONE {
			break
		}
		else if rc != SQLITE_ROW {
			return nil
		}
		records.append(TaskItem(statement, indices: indices))
	}
	return records
}

/// Fetches the ``TaskItem`` records related to itself (`nextId`).
/// 
/// This fetches the related ``TaskItem`` records using the
/// ``TaskItem/nextId`` property.
/// 
/// Example:
/// ```swift
/// let record         : TaskItem = ...
/// let relatedRecords = sqlite3_task_items_fetch(db, forNext: record)
/// ```
/// 
/// - Parameters:
///   - db: The SQLite database handle (as returned by `sqlite3_open`)
///   - record: The ``TaskItem`` record.
///   - orderBySQL: If set, some SQL that is added as an `ORDER BY` clause (e.g. `name DESC`).
///   - limit: An optional fetch limit.
/// - Returns: The related ``TaskItem`` records.
@inlinable
public func sqlite3_task_items_fetch(
	_ db: OpaquePointer!,
	forNext record: TaskItem,
	orderBy orderBySQL: String? = nil,
	limit: Int? = nil
) -> [ TaskItem ]?
{
	var sql = TaskItem.Schema.select
	sql.append(#" WHERE "next_id" = ? LIMIT 1"#)
	if let orderBySQL = orderBySQL {
		sql.append(" ORDER BY \(orderBySQL)")
	}
	if let limit = limit {
		sql.append(" LIMIT \(limit)")
	}
	var handle : OpaquePointer? = nil
	guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
	      let statement = handle else { return nil }
	defer { sqlite3_finalize(statement) }
	sqlite3_bind_int64(statement, 1, Int64(record.id))
	let indices = TaskItem.Schema.selectColumnIndices
	var records = [ TaskItem ]()
	while true {
		let rc = sqlite3_step(statement)
		if rc == SQLITE_DONE {
			break
		}
		else if rc != SQLITE_ROW {
			return nil
		}
		records.append(TaskItem(statement, indices: indices))
	}
	return records
}

/// A structure representing a SQLite database.
/// 
/// ### Database Schema
/// 
/// The schema captures the SQLite table/view catalog as safe Swift types.
/// 
/// #### Tables
/// 
/// - ``TaskList`` (SQL: `task_list`)
/// - ``TaskItem`` (SQL: `task_item`)
/// 
/// > Hint: Use [SQL Views](https://www.sqlite.org/lang_createview.html)
/// >       to create Swift types that represent common queries.
/// >       (E.g. joins between tables or fragments of table data.)
/// 
/// ### Examples
/// 
/// Perform record operations on ``TaskList`` records:
/// ```swift
/// let records = try await db.taskLists.filter(orderBy: \.slug) {
///   $0.slug != nil
/// }
/// 
/// try await db.transaction { tx in
///   var record = try tx.taskLists.find(2) // find by primaryKey
///   
///   record.slug = "Hunt"
///   try tx.update(record)
/// 
///   let newRecord = try tx.insert(record)
///   try tx.delete(newRecord)
/// }
/// ```
/// 
/// Perform column selects on the `task_list` table:
/// ```swift
/// let values = try await db.select(from: \.taskLists, \.slug) {
///   $0.in([ 2, 3 ])
/// }
/// ```
/// 
/// Perform low level operations on ``TaskList`` records:
/// ```swift
/// var db : OpaquePointer?
/// sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE, nil)
/// 
/// var records = sqlite3_task_lists_fetch(db, orderBy: "slug", limit: 5) {
///   $0.slug != nil
/// }!
/// records[1].slug = "Hunt"
/// sqlite3_task_lists_update(db, records[1])
/// 
/// sqlite3_task_lists_delete(db, records[0])
/// sqlite3_task_lists_insert(db, records[0]) // re-add
/// ```
@dynamicMemberLookup
public struct FingerStringDB : SQLDatabase, SQLDatabaseAsyncChangeOperations, SQLCreationStatementsHolder {
	
	/// Mappings of table/view Swift types to their "reference name".
	/// 
	/// The `RecordTypes` structure contains a variable for the Swift type
	/// associated each table/view of the database. It maps the tables
	/// "reference names" (e.g. ``taskLists``) to the
	/// "record type" of the table (e.g. ``TaskList``.self).
	public struct RecordTypes : Swift.Sendable {
		
		/// Returns the TaskList type information (SQL: `task_list`).
		public let taskLists = TaskList.self
		
		/// Returns the TaskItem type information (SQL: `task_item`).
		public let taskItems = TaskItem.self
	}
	
	/// Property based access to the ``RecordTypes-swift.struct``.
	public static let recordTypes = RecordTypes()
	
	#if swift(>=5.7)
	/// All RecordTypes defined in the database.
	public static let _allRecordTypes : [ any SQLRecord.Type ] = [ TaskList.self, TaskItem.self ]
	#endif // swift(>=5.7)
	
	/// User version of the database (`PRAGMA user_version`).
	public static let userVersion = 0
	
	/// Whether `INSERT … RETURNING` should be used (requires SQLite 3.35.0+).
	public static let useInsertReturning = sqlite3_libversion_number() >= 3035000
	
	/// SQL that can be used to recreate the database structure.
	@inlinable
	public static var creationSQL : String {
		var sql = ""
		sql.append(TaskList.Schema.create)
		sql.append(TaskItem.Schema.create)
		return sql
	}
	
	public static func withOptCString<R>(
		_ s: String?,
		_ body: ( UnsafePointer<CChar>? ) throws -> R
	) rethrows -> R
	{
		if let s = s { return try s.withCString(body) }
		else { return try body(nil) }
	}
	
	/// The `connectionHandler` is used to open SQLite database connections.
	public var connectionHandler : SQLConnectionHandler
	
	/// Initialize ``FingerStringDB`` with a `URL`.
	/// 
	/// Configures the database with a simple connection pool opening the
	/// specified `URL`.
	/// And optional `readOnly` flag can be set (defaults to `false`).
	/// 
	/// Example:
	/// ```swift
	/// let db = FingerStringDB(url: ...)
	/// 
	/// // Write operations will raise an error.
	/// let readOnly = FingerStringDB(
	///   url: Bundle.module.url(forResource: "samples", withExtension: "db"),
	///   readOnly: true
	/// )
	/// ```
	/// 
	/// - Parameters:
	///   - url: A `URL` pointing to the database to be used.
	///   - readOnly: Whether the database should be opened readonly (default: `false`).
	@inlinable
	public init(url: URL, readOnly: Bool = false)
	{
		self.connectionHandler = .simplePool(url: url, readOnly: readOnly)
	}
	
	/// Initialize ``FingerStringDB`` w/ a `SQLConnectionHandler`.
	/// 
	/// `SQLConnectionHandler`'s are used to open SQLite database connections when
	/// queries are run using the `Lighter` APIs.
	/// The `SQLConnectionHandler` is a protocol and custom handlers
	/// can be provided.
	/// 
	/// Example:
	/// ```swift
	/// let db = FingerStringDB(connectionHandler: .simplePool(
	///   url: Bundle.module.url(forResource: "samples", withExtension: "db"),
	///   readOnly: true,
	///   maxAge: 10,
	///   maximumPoolSizePerConfiguration: 4
	/// ))
	/// ```
	/// 
	/// - Parameters:
	///   - connectionHandler: The `SQLConnectionHandler` to use w/ the database.
	@inlinable
	public init(connectionHandler: SQLConnectionHandler)
	{
		self.connectionHandler = connectionHandler
	}
}

/// Record representing the `task_list` SQL table.
/// 
/// Record types represent rows within tables&views in a SQLite database.
/// They are returned by the functions or queries/filters generated by
/// Enlighter.
/// 
/// ### Examples
/// 
/// Perform record operations on ``TaskList`` records:
/// ```swift
/// let records = try await db.taskLists.filter(orderBy: \.slug) {
///   $0.slug != nil
/// }
/// 
/// try await db.transaction { tx in
///   var record = try tx.taskLists.find(2) // find by primaryKey
///   
///   record.slug = "Hunt"
///   try tx.update(record)
/// 
///   let newRecord = try tx.insert(record)
///   try tx.delete(newRecord)
/// }
/// ```
/// 
/// Perform column selects on the `task_list` table:
/// ```swift
/// let values = try await db.select(from: \.taskLists, \.slug) {
///   $0.in([ 2, 3 ])
/// }
/// ```
/// 
/// Perform low level operations on ``TaskList`` records:
/// ```swift
/// var db : OpaquePointer?
/// sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE, nil)
/// 
/// var records = sqlite3_task_lists_fetch(db, orderBy: "slug", limit: 5) {
///   $0.slug != nil
/// }!
/// records[1].slug = "Hunt"
/// sqlite3_task_lists_update(db, records[1])
/// 
/// sqlite3_task_lists_delete(db, records[0])
/// sqlite3_task_lists_insert(db, records[0]) // re-add
/// ```
/// 
/// ### SQL
/// 
/// The SQL used to create the table associated with the record:
/// ```sql
/// CREATE TABLE task_list (
/// 	id INTEGER PRIMARY KEY NOT NULL,
/// 	slug TEXT UNIQUE NOT NULL,
/// 	title TEXT,
/// 	description TEXT,
/// 	first_task_id INTEGER
/// )
/// ```
public struct TaskList : Identifiable, SQLKeyedTableRecord, Codable, Sendable {
	
	/// Static SQL type information for the ``TaskList`` record.
	public static let schema = Schema()
	
	/// Primary key `id` (`INTEGER`), required.
	public var id : Int
	
	/// Column `slug` (`TEXT`), required.
	public var slug : String
	
	/// Column `title` (`TEXT`), optional (default: `nil`).
	public var title : String?
	
	/// Column `description` (`TEXT`), optional (default: `nil`).
	public var description : String?
	
	/// Column `first_task_id` (`INTEGER`), optional (default: `nil`).
	public var firstTaskId : Int?
	
	/// Initialize a new ``TaskList`` record.
	/// 
	/// - Parameters:
	///   - id: Primary key `id` (`INTEGER`), required.
	///   - slug: Column `slug` (`TEXT`), required.
	///   - title: Column `title` (`TEXT`), optional (default: `nil`).
	///   - description: Column `description` (`TEXT`), optional (default: `nil`).
	///   - firstTaskId: Column `first_task_id` (`INTEGER`), optional (default: `nil`).
	@inlinable
	public init(
		id: Int = Int.min,
		slug: String,
		title: String? = nil,
		description: String? = nil,
		firstTaskId: Int? = nil
	)
	{
		self.id = id
		self.slug = slug
		self.title = title
		self.description = description
		self.firstTaskId = firstTaskId
	}
}

/// Record representing the `task_item` SQL table.
/// 
/// Record types represent rows within tables&views in a SQLite database.
/// They are returned by the functions or queries/filters generated by
/// Enlighter.
/// 
/// ### Examples
/// 
/// Perform record operations on ``TaskItem`` records:
/// ```swift
/// let records = try await db.taskItems.filter(orderBy: \.itemId) {
///   $0.itemId != nil
/// }
/// 
/// try await db.transaction { tx in
///   var record = try tx.taskItems.find(2) // find by primaryKey
///   
///   record.itemId = "Hunt"
///   try tx.update(record)
/// 
///   let newRecord = try tx.insert(record)
///   try tx.delete(newRecord)
/// }
/// ```
/// 
/// Perform column selects on the `task_item` table:
/// ```swift
/// let values = try await db.select(from: \.taskItems, \.itemId) {
///   $0.in([ 2, 3 ])
/// }
/// ```
/// 
/// Perform low level operations on ``TaskItem`` records:
/// ```swift
/// var db : OpaquePointer?
/// sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE, nil)
/// 
/// var records = sqlite3_task_items_fetch(db, orderBy: "itemId", limit: 5) {
///   $0.itemId != nil
/// }!
/// records[1].itemId = "Hunt"
/// sqlite3_task_items_update(db, records[1])
/// 
/// sqlite3_task_items_delete(db, records[0])
/// sqlite3_task_items_insert(db, records[0]) // re-add
/// ```
/// 
/// ### SQL
/// 
/// The SQL used to create the table associated with the record:
/// ```sql
/// CREATE TABLE task_item (
/// 	id INTEGER PRIMARY KEY NOT NULL,
/// 	list_id INTEGER NOT NULL,
/// 	parent_id INTEGER,
/// 	next_id INTEGER,
/// 	item_id TEXT UNIQUE NOT NULL,
/// 	label TEXT NOT NULL,
/// 	note TEXT,
/// 	FOREIGN KEY(list_id) REFERENCES task_list(id),
/// 	FOREIGN KEY(parent_id) REFERENCES task_item(id),
/// 	FOREIGN KEY(next_id) REFERENCES task_item(id)
/// )
/// ```
public struct TaskItem : Identifiable, SQLKeyedTableRecord, Codable, Sendable {
	
	/// Static SQL type information for the ``TaskItem`` record.
	public static let schema = Schema()
	
	/// Primary key `id` (`INTEGER`), required.
	public var id : Int
	
	/// Column `list_id` (`INTEGER`), required.
	public var listId : Int
	
	/// Column `parent_id` (`INTEGER`), optional (default: `nil`).
	public var parentId : Int?
	
	/// Column `next_id` (`INTEGER`), optional (default: `nil`).
	public var nextId : Int?
	
	/// Column `item_id` (`TEXT`), required.
	public var itemId : String
	
	/// Column `label` (`TEXT`), required.
	public var label : String
	
	/// Column `note` (`TEXT`), optional (default: `nil`).
	public var note : String?
	
	/// Initialize a new ``TaskItem`` record.
	/// 
	/// - Parameters:
	///   - id: Primary key `id` (`INTEGER`), required.
	///   - listId: Column `list_id` (`INTEGER`), required.
	///   - parentId: Column `parent_id` (`INTEGER`), optional (default: `nil`).
	///   - nextId: Column `next_id` (`INTEGER`), optional (default: `nil`).
	///   - itemId: Column `item_id` (`TEXT`), required.
	///   - label: Column `label` (`TEXT`), required.
	///   - note: Column `note` (`TEXT`), optional (default: `nil`).
	@inlinable
	public init(
		id: Int = Int.min,
		listId: Int,
		parentId: Int?,
		nextId: Int? = nil,
		itemId: String,
		label: String,
		note: String? = nil
	)
	{
		self.id = id
		self.listId = listId
		self.parentId = parentId
		self.nextId = nextId
		self.itemId = itemId
		self.label = label
		self.note = note
	}
}

public extension TaskList {
	
	/// Static type information for the ``TaskList`` record (`task_list` SQL table).
	/// 
	/// This structure captures the static SQL information associated with the
	/// record.
	/// It is used for static type lookups and more.
	struct Schema : SQLKeyedTableSchema, SQLSwiftMatchableSchema, SQLCreatableSchema {
		
		public typealias PropertyIndices = ( idx_id: Int32, idx_slug: Int32, idx_title: Int32, idx_description: Int32, idx_firstTaskId: Int32 )
		public typealias RecordType = TaskList
		public typealias MatchClosureType = ( TaskList ) -> Bool
		
		/// The SQL table name associated with the ``TaskList`` record.
		public static let externalName = "task_list"
		
		/// The number of columns the `task_list` table has.
		public static let columnCount : Int32 = 5
		
		/// Information on the records primary key (``TaskList/id``).
		public static let primaryKeyColumn = MappedColumn<TaskList, Int>(
			externalName: "id",
			defaultValue: -1,
			keyPath: \TaskList.id
		)
		
		/// The SQL used to create the `task_list` table.
		public static let create = 
			#"""
			CREATE TABLE task_list (
				id INTEGER PRIMARY KEY NOT NULL,
				slug TEXT UNIQUE NOT NULL,
				title TEXT,
				description TEXT,
				first_task_id INTEGER
			);
			"""#
		
		/// SQL to `SELECT` all columns of the `task_list` table.
		public static let select = #"SELECT "id", "slug", "title", "description", "first_task_id" FROM "task_list""#
		
		/// SQL fragment representing all columns.
		public static let selectColumns = #""id", "slug", "title", "description", "first_task_id""#
		
		/// Index positions of the properties in ``selectColumns``.
		public static let selectColumnIndices : PropertyIndices = ( 0, 1, 2, 3, 4 )
		
		/// SQL to `SELECT` all columns of the `task_list` table using a Swift filter.
		public static let matchSelect = #"SELECT "id", "slug", "title", "description", "first_task_id" FROM "task_list" WHERE taskLists_swift_match("id", "slug", "title", "description", "first_task_id") != 0"#
		
		/// SQL to `UPDATE` all columns of the `task_list` table.
		public static let update = #"UPDATE "task_list" SET "slug" = ?, "title" = ?, "description" = ?, "first_task_id" = ? WHERE "id" = ?"#
		
		/// Property parameter indicies in the ``update`` SQL
		public static let updateParameterIndices : PropertyIndices = ( 5, 1, 2, 3, 4 )
		
		/// SQL to `INSERT` a record into the `task_list` table.
		public static let insert = #"INSERT INTO "task_list" ( "slug", "title", "description", "first_task_id" ) VALUES ( ?, ?, ?, ? )"#
		
		/// SQL to `INSERT` a record into the `task_list` table.
		public static let insertReturning = #"INSERT INTO "task_list" ( "slug", "title", "description", "first_task_id" ) VALUES ( ?, ?, ?, ? ) RETURNING "id", "slug", "title", "description", "first_task_id""#
		
		/// Property parameter indicies in the ``insert`` SQL
		public static let insertParameterIndices : PropertyIndices = ( -1, 1, 2, 3, 4 )
		
		/// SQL to `DELETE` a record from the `task_list` table.
		public static let delete = #"DELETE FROM "task_list" WHERE "id" = ?"#
		
		/// Property parameter indicies in the ``delete`` SQL
		public static let deleteParameterIndices : PropertyIndices = ( 1, -1, -1, -1, -1 )
		
		/// Lookup property indices by column name in a statement handle.
		/// 
		/// Properties are ordered in the schema and have a specific index
		/// assigned.
		/// E.g. if the record has two properties, `id` and `name`,
		/// and the query was `SELECT age, task_list_id FROM task_list`,
		/// this would return `( idx_id: 1, idx_name: -1 )`.
		/// Because the `task_list_id` is in the second position and `name`
		/// isn't provided at all.
		/// 
		/// - Parameters:
		///   - statement: A raw SQLite3 prepared statement handle.
		/// - Returns: The positions of the properties in the prepared statement.
		@inlinable
		public static func lookupColumnIndices(`in` statement: OpaquePointer!)
			-> PropertyIndices
		{
			var indices : PropertyIndices = ( -1, -1, -1, -1, -1 )
			for i in 0..<sqlite3_column_count(statement) {
				let col = sqlite3_column_name(statement, i)
				if strcmp(col!, "id") == 0 {
					indices.idx_id = i
				}
				else if strcmp(col!, "slug") == 0 {
					indices.idx_slug = i
				}
				else if strcmp(col!, "title") == 0 {
					indices.idx_title = i
				}
				else if strcmp(col!, "description") == 0 {
					indices.idx_description = i
				}
				else if strcmp(col!, "first_task_id") == 0 {
					indices.idx_firstTaskId = i
				}
			}
			return indices
		}
		
		/// Register the Swift matcher function for the ``TaskList`` record.
		/// 
		/// SQLite Swift matcher functions are used to process `filter` queries
		/// and low-level matching w/o the Lighter library.
		/// 
		/// - Parameters:
		///   - unsafeDatabaseHandle: SQLite3 database handle.
		///   - flags: SQLite3 function registration flags, default: `SQLITE_UTF8`
		///   - matcher: A pointer to the Swift closure used to filter the records.
		/// - Returns: The result code of `sqlite3_create_function`, e.g. `SQLITE_OK`.
		@inlinable
		@discardableResult
		public static func registerSwiftMatcher(
			`in` unsafeDatabaseHandle: OpaquePointer!,
			flags: Int32 = SQLITE_UTF8,
			matcher: UnsafeRawPointer
		) -> Int32
		{
			func dispatch(
				_ context: OpaquePointer?,
				argc: Int32,
				argv: UnsafeMutablePointer<OpaquePointer?>!
			)
			{
				if let closureRawPtr = sqlite3_user_data(context) {
					let closurePtr = closureRawPtr.bindMemory(to: MatchClosureType.self, capacity: 1)
					let indices = TaskList.Schema.selectColumnIndices
					let record = TaskList(
						id: (indices.idx_id >= 0) && (indices.idx_id < argc) && (sqlite3_value_type(argv[Int(indices.idx_id)]) != SQLITE_NULL) ? Int(sqlite3_value_int64(argv[Int(indices.idx_id)])) : RecordType.schema.id.defaultValue,
						slug: ((indices.idx_slug >= 0) && (indices.idx_slug < argc) ? (sqlite3_value_text(argv[Int(indices.idx_slug)]).flatMap(String.init(cString:))) : nil) ?? RecordType.schema.slug.defaultValue,
						title: (indices.idx_title >= 0) && (indices.idx_title < argc) ? (sqlite3_value_text(argv[Int(indices.idx_title)]).flatMap(String.init(cString:))) : RecordType.schema.title.defaultValue,
						description: (indices.idx_description >= 0) && (indices.idx_description < argc) ? (sqlite3_value_text(argv[Int(indices.idx_description)]).flatMap(String.init(cString:))) : RecordType.schema.description.defaultValue,
						firstTaskId: (indices.idx_firstTaskId >= 0) && (indices.idx_firstTaskId < argc) ? (sqlite3_value_type(argv[Int(indices.idx_firstTaskId)]) != SQLITE_NULL ? Int(sqlite3_value_int64(argv[Int(indices.idx_firstTaskId)])) : nil) : RecordType.schema.firstTaskId.defaultValue
					)
					sqlite3_result_int(context, closurePtr.pointee(record) ? 1 : 0)
				}
				else {
					sqlite3_result_error(context, "Missing Swift matcher closure", -1)
				}
			}
			return sqlite3_create_function(
				unsafeDatabaseHandle,
				"taskLists_swift_match",
				TaskList.Schema.columnCount,
				flags,
				UnsafeMutableRawPointer(mutating: matcher),
				dispatch,
				nil,
				nil
			)
		}
		
		/// Unregister the Swift matcher function for the ``TaskList`` record.
		/// 
		/// SQLite Swift matcher functions are used to process `filter` queries
		/// and low-level matching w/o the Lighter library.
		/// 
		/// - Parameters:
		///   - unsafeDatabaseHandle: SQLite3 database handle.
		///   - flags: SQLite3 function registration flags, default: `SQLITE_UTF8`
		/// - Returns: The result code of `sqlite3_create_function`, e.g. `SQLITE_OK`.
		@inlinable
		@discardableResult
		public static func unregisterSwiftMatcher(
			`in` unsafeDatabaseHandle: OpaquePointer!,
			flags: Int32 = SQLITE_UTF8
		) -> Int32
		{
			sqlite3_create_function(
				unsafeDatabaseHandle,
				"taskLists_swift_match",
				TaskList.Schema.columnCount,
				flags,
				nil,
				nil,
				nil,
				nil
			)
		}
		
		/// Type information for property ``TaskList/id`` (`id` column).
		public let id = MappedColumn<TaskList, Int>(
			externalName: "id",
			defaultValue: -1,
			keyPath: \TaskList.id
		)
		
		/// Type information for property ``TaskList/slug`` (`slug` column).
		public let slug = MappedColumn<TaskList, String>(
			externalName: "slug",
			defaultValue: "",
			keyPath: \TaskList.slug
		)
		
		/// Type information for property ``TaskList/title`` (`title` column).
		public let title = MappedColumn<TaskList, String?>(
			externalName: "title",
			defaultValue: nil,
			keyPath: \TaskList.title
		)
		
		/// Type information for property ``TaskList/description`` (`description` column).
		public let description = MappedColumn<TaskList, String?>(
			externalName: "description",
			defaultValue: nil,
			keyPath: \TaskList.description
		)
		
		/// Type information for property ``TaskList/firstTaskId`` (`first_task_id` column).
		public let firstTaskId = MappedColumn<TaskList, Int?>(
			externalName: "first_task_id",
			defaultValue: nil,
			keyPath: \TaskList.firstTaskId
		)
		
		#if swift(>=5.7)
		public var _allColumns : [ any SQLColumn ] { [ id, slug, title, description, firstTaskId ] }
		#endif // swift(>=5.7)
		
		public init()
		{
		}
	}
	
	/// Initialize a ``TaskList`` record from a SQLite statement handle.
	/// 
	/// This initializer allows easy setup of a record structure from an
	/// otherwise arbitrarily constructed SQLite prepared statement.
	/// 
	/// If no `indices` are specified, the `Schema/lookupColumnIndices`
	/// function will be used to find the positions of the structure properties
	/// based on their external name.
	/// When looping, it is recommended to do the lookup once, and then
	/// provide the `indices` to the initializer.
	/// 
	/// Required values that are missing in the statement are replaced with
	/// their assigned default values, i.e. this can even be used to perform
	/// partial selects w/ only a minor overhead (the extra space for a
	/// record).
	/// 
	/// Example:
	/// ```swift
	/// var statement : OpaquePointer?
	/// sqlite3_prepare_v2(dbHandle, "SELECT * FROM task_list", -1, &statement, nil)
	/// while sqlite3_step(statement) == SQLITE_ROW {
	///   let record = TaskList(statement)
	///   print("Fetched:", record)
	/// }
	/// sqlite3_finalize(statement)
	/// ```
	/// 
	/// - Parameters:
	///   - statement: Statement handle as returned by `sqlite3_prepare*` functions.
	///   - indices: Property bindings positions, defaults to `nil` (automatic lookup).
	@inlinable
	init(_ statement: OpaquePointer!, indices: Schema.PropertyIndices? = nil)
	{
		let indices = indices ?? Self.Schema.lookupColumnIndices(in: statement)
		let argc = sqlite3_column_count(statement)
		self.init(
			id: (indices.idx_id >= 0) && (indices.idx_id < argc) && (sqlite3_column_type(statement, indices.idx_id) != SQLITE_NULL) ? Int(sqlite3_column_int64(statement, indices.idx_id)) : Self.schema.id.defaultValue,
			slug: ((indices.idx_slug >= 0) && (indices.idx_slug < argc) ? (sqlite3_column_text(statement, indices.idx_slug).flatMap(String.init(cString:))) : nil) ?? Self.schema.slug.defaultValue,
			title: (indices.idx_title >= 0) && (indices.idx_title < argc) ? (sqlite3_column_text(statement, indices.idx_title).flatMap(String.init(cString:))) : Self.schema.title.defaultValue,
			description: (indices.idx_description >= 0) && (indices.idx_description < argc) ? (sqlite3_column_text(statement, indices.idx_description).flatMap(String.init(cString:))) : Self.schema.description.defaultValue,
			firstTaskId: (indices.idx_firstTaskId >= 0) && (indices.idx_firstTaskId < argc) ? (sqlite3_column_type(statement, indices.idx_firstTaskId) != SQLITE_NULL ? Int(sqlite3_column_int64(statement, indices.idx_firstTaskId)) : nil) : Self.schema.firstTaskId.defaultValue
		)
	}
	
	/// Bind all ``TaskList`` properties to a prepared statement and call a closure.
	/// 
	/// *Important*: The bindings are only valid within the closure being executed!
	/// 
	/// Example:
	/// ```swift
	/// var statement : OpaquePointer?
	/// sqlite3_prepare_v2(
	///   dbHandle,
	///   #"UPDATE "task_list" SET "slug" = ?, "title" = ?, "description" = ?, "first_task_id" = ? WHERE "id" = ?"#,
	///   -1, &statement, nil
	/// )
	/// 
	/// let record = TaskList(id: 1, slug: "Hello", title: "World", description: "Duck", firstTaskId: 2)
	/// let ok = record.bind(to: statement, indices: ( 5, 1, 2, 3, 4 )) {
	///   sqlite3_step(statement) == SQLITE_DONE
	/// }
	/// sqlite3_finalize(statement)
	/// ```
	/// 
	/// - Parameters:
	///   - statement: A SQLite3 statement handle as returned by the `sqlite3_prepare*` functions.
	///   - indices: The parameter positions for the bindings.
	///   - execute: Closure executed with bindings applied, bindings _only_ valid within the call!
	/// - Returns: Returns the result of the closure that is passed in.
	@inlinable
	@discardableResult
	func bind<R>(
		to statement: OpaquePointer!,
		indices: Schema.PropertyIndices,
		then execute: () throws -> R
	) rethrows -> R
	{
		if indices.idx_id >= 0 {
			sqlite3_bind_int64(statement, indices.idx_id, Int64(id))
		}
		return try slug.withCString() { ( s ) in
			if indices.idx_slug >= 0 {
				sqlite3_bind_text(statement, indices.idx_slug, s, -1, nil)
			}
			return try FingerStringDB.withOptCString(title) { ( s ) in
				if indices.idx_title >= 0 {
					sqlite3_bind_text(statement, indices.idx_title, s, -1, nil)
				}
				return try FingerStringDB.withOptCString(description) { ( s ) in
					if indices.idx_description >= 0 {
						sqlite3_bind_text(statement, indices.idx_description, s, -1, nil)
					}
					if indices.idx_firstTaskId >= 0 {
						if let firstTaskId = firstTaskId {
							sqlite3_bind_int64(statement, indices.idx_firstTaskId, Int64(firstTaskId))
						}
						else {
							sqlite3_bind_null(statement, indices.idx_firstTaskId)
						}
					}
					return try execute()
				}
			}
		}
	}
}

public extension TaskItem {
	
	/// Static type information for the ``TaskItem`` record (`task_item` SQL table).
	/// 
	/// This structure captures the static SQL information associated with the
	/// record.
	/// It is used for static type lookups and more.
	struct Schema : SQLKeyedTableSchema, SQLSwiftMatchableSchema, SQLCreatableSchema {
		
		public typealias PropertyIndices = ( idx_id: Int32, idx_listId: Int32, idx_parentId: Int32, idx_nextId: Int32, idx_itemId: Int32, idx_label: Int32, idx_note: Int32 )
		public typealias RecordType = TaskItem
		public typealias MatchClosureType = ( TaskItem ) -> Bool
		
		/// The SQL table name associated with the ``TaskItem`` record.
		public static let externalName = "task_item"
		
		/// The number of columns the `task_item` table has.
		public static let columnCount : Int32 = 7
		
		/// Information on the records primary key (``TaskItem/id``).
		public static let primaryKeyColumn = MappedColumn<TaskItem, Int>(
			externalName: "id",
			defaultValue: -1,
			keyPath: \TaskItem.id
		)
		
		/// The SQL used to create the `task_item` table.
		public static let create = 
			#"""
			CREATE TABLE task_item (
				id INTEGER PRIMARY KEY NOT NULL,
				list_id INTEGER NOT NULL,
				parent_id INTEGER,
				next_id INTEGER,
				item_id TEXT UNIQUE NOT NULL,
				label TEXT NOT NULL,
				note TEXT,
				FOREIGN KEY(list_id) REFERENCES task_list(id),
				FOREIGN KEY(parent_id) REFERENCES task_item(id),
				FOREIGN KEY(next_id) REFERENCES task_item(id)
			);
			"""#
		
		/// SQL to `SELECT` all columns of the `task_item` table.
		public static let select = #"SELECT "id", "list_id", "parent_id", "next_id", "item_id", "label", "note" FROM "task_item""#
		
		/// SQL fragment representing all columns.
		public static let selectColumns = #""id", "list_id", "parent_id", "next_id", "item_id", "label", "note""#
		
		/// Index positions of the properties in ``selectColumns``.
		public static let selectColumnIndices : PropertyIndices = ( 0, 1, 2, 3, 4, 5, 6 )
		
		/// SQL to `SELECT` all columns of the `task_item` table using a Swift filter.
		public static let matchSelect = #"SELECT "id", "list_id", "parent_id", "next_id", "item_id", "label", "note" FROM "task_item" WHERE taskItems_swift_match("id", "list_id", "parent_id", "next_id", "item_id", "label", "note") != 0"#
		
		/// SQL to `UPDATE` all columns of the `task_item` table.
		public static let update = #"UPDATE "task_item" SET "list_id" = ?, "parent_id" = ?, "next_id" = ?, "item_id" = ?, "label" = ?, "note" = ? WHERE "id" = ?"#
		
		/// Property parameter indicies in the ``update`` SQL
		public static let updateParameterIndices : PropertyIndices = ( 7, 1, 2, 3, 4, 5, 6 )
		
		/// SQL to `INSERT` a record into the `task_item` table.
		public static let insert = #"INSERT INTO "task_item" ( "list_id", "parent_id", "next_id", "item_id", "label", "note" ) VALUES ( ?, ?, ?, ?, ?, ? )"#
		
		/// SQL to `INSERT` a record into the `task_item` table.
		public static let insertReturning = #"INSERT INTO "task_item" ( "list_id", "parent_id", "next_id", "item_id", "label", "note" ) VALUES ( ?, ?, ?, ?, ?, ? ) RETURNING "id", "list_id", "parent_id", "next_id", "item_id", "label", "note""#
		
		/// Property parameter indicies in the ``insert`` SQL
		public static let insertParameterIndices : PropertyIndices = ( -1, 1, 2, 3, 4, 5, 6 )
		
		/// SQL to `DELETE` a record from the `task_item` table.
		public static let delete = #"DELETE FROM "task_item" WHERE "id" = ?"#
		
		/// Property parameter indicies in the ``delete`` SQL
		public static let deleteParameterIndices : PropertyIndices = ( 1, -1, -1, -1, -1, -1, -1 )
		
		/// Lookup property indices by column name in a statement handle.
		/// 
		/// Properties are ordered in the schema and have a specific index
		/// assigned.
		/// E.g. if the record has two properties, `id` and `name`,
		/// and the query was `SELECT age, task_item_id FROM task_item`,
		/// this would return `( idx_id: 1, idx_name: -1 )`.
		/// Because the `task_item_id` is in the second position and `name`
		/// isn't provided at all.
		/// 
		/// - Parameters:
		///   - statement: A raw SQLite3 prepared statement handle.
		/// - Returns: The positions of the properties in the prepared statement.
		@inlinable
		public static func lookupColumnIndices(`in` statement: OpaquePointer!)
			-> PropertyIndices
		{
			var indices : PropertyIndices = ( -1, -1, -1, -1, -1, -1, -1 )
			for i in 0..<sqlite3_column_count(statement) {
				let col = sqlite3_column_name(statement, i)
				if strcmp(col!, "id") == 0 {
					indices.idx_id = i
				}
				else if strcmp(col!, "list_id") == 0 {
					indices.idx_listId = i
				}
				else if strcmp(col!, "parent_id") == 0 {
					indices.idx_parentId = i
				}
				else if strcmp(col!, "next_id") == 0 {
					indices.idx_nextId = i
				}
				else if strcmp(col!, "item_id") == 0 {
					indices.idx_itemId = i
				}
				else if strcmp(col!, "label") == 0 {
					indices.idx_label = i
				}
				else if strcmp(col!, "note") == 0 {
					indices.idx_note = i
				}
			}
			return indices
		}
		
		/// Register the Swift matcher function for the ``TaskItem`` record.
		/// 
		/// SQLite Swift matcher functions are used to process `filter` queries
		/// and low-level matching w/o the Lighter library.
		/// 
		/// - Parameters:
		///   - unsafeDatabaseHandle: SQLite3 database handle.
		///   - flags: SQLite3 function registration flags, default: `SQLITE_UTF8`
		///   - matcher: A pointer to the Swift closure used to filter the records.
		/// - Returns: The result code of `sqlite3_create_function`, e.g. `SQLITE_OK`.
		@inlinable
		@discardableResult
		public static func registerSwiftMatcher(
			`in` unsafeDatabaseHandle: OpaquePointer!,
			flags: Int32 = SQLITE_UTF8,
			matcher: UnsafeRawPointer
		) -> Int32
		{
			func dispatch(
				_ context: OpaquePointer?,
				argc: Int32,
				argv: UnsafeMutablePointer<OpaquePointer?>!
			)
			{
				if let closureRawPtr = sqlite3_user_data(context) {
					let closurePtr = closureRawPtr.bindMemory(to: MatchClosureType.self, capacity: 1)
					let indices = TaskItem.Schema.selectColumnIndices
					let record = TaskItem(
						id: (indices.idx_id >= 0) && (indices.idx_id < argc) && (sqlite3_value_type(argv[Int(indices.idx_id)]) != SQLITE_NULL) ? Int(sqlite3_value_int64(argv[Int(indices.idx_id)])) : RecordType.schema.id.defaultValue,
						listId: (indices.idx_listId >= 0) && (indices.idx_listId < argc) && (sqlite3_value_type(argv[Int(indices.idx_listId)]) != SQLITE_NULL) ? Int(sqlite3_value_int64(argv[Int(indices.idx_listId)])) : RecordType.schema.listId.defaultValue,
						parentId: (indices.idx_parentId >= 0) && (indices.idx_parentId < argc) ? (sqlite3_value_type(argv[Int(indices.idx_parentId)]) != SQLITE_NULL ? Int(sqlite3_value_int64(argv[Int(indices.idx_parentId)])) : nil) : RecordType.schema.parentId.defaultValue,
						nextId: (indices.idx_nextId >= 0) && (indices.idx_nextId < argc) ? (sqlite3_value_type(argv[Int(indices.idx_nextId)]) != SQLITE_NULL ? Int(sqlite3_value_int64(argv[Int(indices.idx_nextId)])) : nil) : RecordType.schema.nextId.defaultValue,
						itemId: ((indices.idx_itemId >= 0) && (indices.idx_itemId < argc) ? (sqlite3_value_text(argv[Int(indices.idx_itemId)]).flatMap(String.init(cString:))) : nil) ?? RecordType.schema.itemId.defaultValue,
						label: ((indices.idx_label >= 0) && (indices.idx_label < argc) ? (sqlite3_value_text(argv[Int(indices.idx_label)]).flatMap(String.init(cString:))) : nil) ?? RecordType.schema.label.defaultValue,
						note: (indices.idx_note >= 0) && (indices.idx_note < argc) ? (sqlite3_value_text(argv[Int(indices.idx_note)]).flatMap(String.init(cString:))) : RecordType.schema.note.defaultValue
					)
					sqlite3_result_int(context, closurePtr.pointee(record) ? 1 : 0)
				}
				else {
					sqlite3_result_error(context, "Missing Swift matcher closure", -1)
				}
			}
			return sqlite3_create_function(
				unsafeDatabaseHandle,
				"taskItems_swift_match",
				TaskItem.Schema.columnCount,
				flags,
				UnsafeMutableRawPointer(mutating: matcher),
				dispatch,
				nil,
				nil
			)
		}
		
		/// Unregister the Swift matcher function for the ``TaskItem`` record.
		/// 
		/// SQLite Swift matcher functions are used to process `filter` queries
		/// and low-level matching w/o the Lighter library.
		/// 
		/// - Parameters:
		///   - unsafeDatabaseHandle: SQLite3 database handle.
		///   - flags: SQLite3 function registration flags, default: `SQLITE_UTF8`
		/// - Returns: The result code of `sqlite3_create_function`, e.g. `SQLITE_OK`.
		@inlinable
		@discardableResult
		public static func unregisterSwiftMatcher(
			`in` unsafeDatabaseHandle: OpaquePointer!,
			flags: Int32 = SQLITE_UTF8
		) -> Int32
		{
			sqlite3_create_function(
				unsafeDatabaseHandle,
				"taskItems_swift_match",
				TaskItem.Schema.columnCount,
				flags,
				nil,
				nil,
				nil,
				nil
			)
		}
		
		/// Type information for property ``TaskItem/id`` (`id` column).
		public let id = MappedColumn<TaskItem, Int>(
			externalName: "id",
			defaultValue: -1,
			keyPath: \TaskItem.id
		)
		
		/// Type information for property ``TaskItem/listId`` (`list_id` column).
		public let listId = MappedForeignKey<TaskItem, Int, MappedColumn<TaskList, Int>>(
			externalName: "list_id",
			defaultValue: -1,
			keyPath: \TaskItem.listId,
			destinationColumn: TaskList.schema.id
		)
		
		/// Type information for property ``TaskItem/parentId`` (`parent_id` column).
		public let parentId = MappedForeignKey<TaskItem, Int?, MappedColumn<TaskItem, Int>>(
			externalName: "parent_id",
			defaultValue: nil,
			keyPath: \TaskItem.parentId,
			destinationColumn: TaskItem.schema.id
		)
		
		/// Type information for property ``TaskItem/nextId`` (`next_id` column).
		public let nextId = MappedForeignKey<TaskItem, Int?, MappedColumn<TaskItem, Int>>(
			externalName: "next_id",
			defaultValue: nil,
			keyPath: \TaskItem.nextId,
			destinationColumn: TaskItem.schema.id
		)
		
		/// Type information for property ``TaskItem/itemId`` (`item_id` column).
		public let itemId = MappedColumn<TaskItem, String>(
			externalName: "item_id",
			defaultValue: "",
			keyPath: \TaskItem.itemId
		)
		
		/// Type information for property ``TaskItem/label`` (`label` column).
		public let label = MappedColumn<TaskItem, String>(
			externalName: "label",
			defaultValue: "",
			keyPath: \TaskItem.label
		)
		
		/// Type information for property ``TaskItem/note`` (`note` column).
		public let note = MappedColumn<TaskItem, String?>(
			externalName: "note",
			defaultValue: nil,
			keyPath: \TaskItem.note
		)
		
		#if swift(>=5.7)
		public var _allColumns : [ any SQLColumn ] { [ id, listId, parentId, nextId, itemId, label, note ] }
		#endif // swift(>=5.7)
		
		public init()
		{
		}
	}
	
	/// Initialize a ``TaskItem`` record from a SQLite statement handle.
	/// 
	/// This initializer allows easy setup of a record structure from an
	/// otherwise arbitrarily constructed SQLite prepared statement.
	/// 
	/// If no `indices` are specified, the `Schema/lookupColumnIndices`
	/// function will be used to find the positions of the structure properties
	/// based on their external name.
	/// When looping, it is recommended to do the lookup once, and then
	/// provide the `indices` to the initializer.
	/// 
	/// Required values that are missing in the statement are replaced with
	/// their assigned default values, i.e. this can even be used to perform
	/// partial selects w/ only a minor overhead (the extra space for a
	/// record).
	/// 
	/// Example:
	/// ```swift
	/// var statement : OpaquePointer?
	/// sqlite3_prepare_v2(dbHandle, "SELECT * FROM task_item", -1, &statement, nil)
	/// while sqlite3_step(statement) == SQLITE_ROW {
	///   let record = TaskItem(statement)
	///   print("Fetched:", record)
	/// }
	/// sqlite3_finalize(statement)
	/// ```
	/// 
	/// - Parameters:
	///   - statement: Statement handle as returned by `sqlite3_prepare*` functions.
	///   - indices: Property bindings positions, defaults to `nil` (automatic lookup).
	@inlinable
	init(_ statement: OpaquePointer!, indices: Schema.PropertyIndices? = nil)
	{
		let indices = indices ?? Self.Schema.lookupColumnIndices(in: statement)
		let argc = sqlite3_column_count(statement)
		self.init(
			id: (indices.idx_id >= 0) && (indices.idx_id < argc) && (sqlite3_column_type(statement, indices.idx_id) != SQLITE_NULL) ? Int(sqlite3_column_int64(statement, indices.idx_id)) : Self.schema.id.defaultValue,
			listId: (indices.idx_listId >= 0) && (indices.idx_listId < argc) && (sqlite3_column_type(statement, indices.idx_listId) != SQLITE_NULL) ? Int(sqlite3_column_int64(statement, indices.idx_listId)) : Self.schema.listId.defaultValue,
			parentId: (indices.idx_parentId >= 0) && (indices.idx_parentId < argc) ? (sqlite3_column_type(statement, indices.idx_parentId) != SQLITE_NULL ? Int(sqlite3_column_int64(statement, indices.idx_parentId)) : nil) : Self.schema.parentId.defaultValue,
			nextId: (indices.idx_nextId >= 0) && (indices.idx_nextId < argc) ? (sqlite3_column_type(statement, indices.idx_nextId) != SQLITE_NULL ? Int(sqlite3_column_int64(statement, indices.idx_nextId)) : nil) : Self.schema.nextId.defaultValue,
			itemId: ((indices.idx_itemId >= 0) && (indices.idx_itemId < argc) ? (sqlite3_column_text(statement, indices.idx_itemId).flatMap(String.init(cString:))) : nil) ?? Self.schema.itemId.defaultValue,
			label: ((indices.idx_label >= 0) && (indices.idx_label < argc) ? (sqlite3_column_text(statement, indices.idx_label).flatMap(String.init(cString:))) : nil) ?? Self.schema.label.defaultValue,
			note: (indices.idx_note >= 0) && (indices.idx_note < argc) ? (sqlite3_column_text(statement, indices.idx_note).flatMap(String.init(cString:))) : Self.schema.note.defaultValue
		)
	}
	
	/// Bind all ``TaskItem`` properties to a prepared statement and call a closure.
	/// 
	/// *Important*: The bindings are only valid within the closure being executed!
	/// 
	/// Example:
	/// ```swift
	/// var statement : OpaquePointer?
	/// sqlite3_prepare_v2(
	///   dbHandle,
	///   #"UPDATE "task_item" SET "list_id" = ?, "parent_id" = ?, "next_id" = ?, "item_id" = ?, "label" = ?, "note" = ? WHERE "id" = ?"#,
	///   -1, &statement, nil
	/// )
	/// 
	/// let record = TaskItem(id: 1, listId: 2, parentId: 3, nextId: 4, itemId: "Hello", label: "World", note: "Duck")
	/// let ok = record.bind(to: statement, indices: ( 7, 1, 2, 3, 4, 5, 6 )) {
	///   sqlite3_step(statement) == SQLITE_DONE
	/// }
	/// sqlite3_finalize(statement)
	/// ```
	/// 
	/// - Parameters:
	///   - statement: A SQLite3 statement handle as returned by the `sqlite3_prepare*` functions.
	///   - indices: The parameter positions for the bindings.
	///   - execute: Closure executed with bindings applied, bindings _only_ valid within the call!
	/// - Returns: Returns the result of the closure that is passed in.
	@inlinable
	@discardableResult
	func bind<R>(
		to statement: OpaquePointer!,
		indices: Schema.PropertyIndices,
		then execute: () throws -> R
	) rethrows -> R
	{
		if indices.idx_id >= 0 {
			sqlite3_bind_int64(statement, indices.idx_id, Int64(id))
		}
		if indices.idx_listId >= 0 {
			sqlite3_bind_int64(statement, indices.idx_listId, Int64(listId))
		}
		if indices.idx_parentId >= 0 {
			if let parentId = parentId {
				sqlite3_bind_int64(statement, indices.idx_parentId, Int64(parentId))
			}
			else {
				sqlite3_bind_null(statement, indices.idx_parentId)
			}
		}
		if indices.idx_nextId >= 0 {
			if let nextId = nextId {
				sqlite3_bind_int64(statement, indices.idx_nextId, Int64(nextId))
			}
			else {
				sqlite3_bind_null(statement, indices.idx_nextId)
			}
		}
		return try itemId.withCString() { ( s ) in
			if indices.idx_itemId >= 0 {
				sqlite3_bind_text(statement, indices.idx_itemId, s, -1, nil)
			}
			return try label.withCString() { ( s ) in
				if indices.idx_label >= 0 {
					sqlite3_bind_text(statement, indices.idx_label, s, -1, nil)
				}
				return try FingerStringDB.withOptCString(note) { ( s ) in
					if indices.idx_note >= 0 {
						sqlite3_bind_text(statement, indices.idx_note, s, -1, nil)
					}
					return try execute()
				}
			}
		}
	}
}

public extension SQLRecordFetchOperations
	where T == TaskList, Ops: SQLDatabaseFetchOperations, Ops.RecordTypes == FingerStringDB.RecordTypes
{
	
	/// Fetch the ``TaskList`` record related to a ``TaskItem`` (`listId`).
	/// 
	/// This fetches the related ``TaskList`` record using the
	/// ``TaskItem/listId`` property.
	/// 
	/// Example:
	/// ```swift
	/// let sourceRecord  : TaskItem = ...
	/// let relatedRecord = try db.taskLists.find(for: sourceRecord)
	/// ```
	/// 
	/// - Parameters:
	///   - record: The ``TaskItem`` record.
	/// - Returns: The related ``TaskList`` record (throws if not found).
	@inlinable
	func find(`for` record: TaskItem) throws -> TaskList
	{
		if let record = try operations[dynamicMember: \.taskItems].findTarget(for: \.listId, in: record) {
			return record
		}
		else {
			throw LighterError(.couldNotFindRelationshipTarget, SQLITE_CONSTRAINT)
		}
	}
}

public extension SQLRecordFetchOperations
	where T == TaskItem, Ops: SQLDatabaseFetchOperations, Ops.RecordTypes == FingerStringDB.RecordTypes
{
	
	/// Fetch the ``TaskItem`` record related to itself (`parentId`).
	/// 
	/// This fetches the related ``TaskItem`` record using the
	/// ``TaskItem/parentId`` property.
	/// 
	/// Example:
	/// ```swift
	/// let sourceRecord  : TaskItem = ...
	/// let relatedRecord = try db.taskItems.find(forParent: sourceRecord)
	/// ```
	/// 
	/// - Parameters:
	///   - record: The ``TaskItem`` record.
	/// - Returns: The related ``TaskItem`` record, or `nil` if not found.
	@inlinable
	func find(forParent record: TaskItem) throws -> TaskItem?
	{
		try operations[dynamicMember: \.taskItems].findTarget(for: \.parentId, in: record)
	}
	
	/// Fetch the ``TaskItem`` record related to itself (`nextId`).
	/// 
	/// This fetches the related ``TaskItem`` record using the
	/// ``TaskItem/nextId`` property.
	/// 
	/// Example:
	/// ```swift
	/// let sourceRecord  : TaskItem = ...
	/// let relatedRecord = try db.taskItems.find(forNext: sourceRecord)
	/// ```
	/// 
	/// - Parameters:
	///   - record: The ``TaskItem`` record.
	/// - Returns: The related ``TaskItem`` record, or `nil` if not found.
	@inlinable
	func find(forNext record: TaskItem) throws -> TaskItem?
	{
		try operations[dynamicMember: \.taskItems].findTarget(for: \.nextId, in: record)
	}
	
	/// Fetches the ``TaskItem`` records related to a ``TaskList`` (`listId`).
	/// 
	/// This fetches the related ``TaskList`` records using the
	/// ``TaskItem/listId`` property.
	/// 
	/// Example:
	/// ```swift
	/// let record         : TaskList = ...
	/// let relatedRecords = try db.taskItems.fetch(forList: record)
	/// ```
	/// 
	/// - Parameters:
	///   - record: The ``TaskList`` record.
	///   - limit: An optional limit of records to fetch (defaults to `nil`).
	/// - Returns: The related ``TaskList`` records.
	@inlinable
	func fetch(forList record: TaskList, limit: Int? = nil) throws -> [ TaskItem ]
	{
		try fetch(for: \.listId, in: record, limit: limit)
	}
	
	/// Fetches the ``TaskItem`` records related to itself (`parentId`).
	/// 
	/// This fetches the related ``TaskItem`` records using the
	/// ``TaskItem/parentId`` property.
	/// 
	/// Example:
	/// ```swift
	/// let record         : TaskItem = ...
	/// let relatedRecords = try db.taskItems.fetch(forParent: record)
	/// ```
	/// 
	/// - Parameters:
	///   - record: The ``TaskItem`` record.
	///   - limit: An optional limit of records to fetch (defaults to `nil`).
	/// - Returns: The related ``TaskItem`` records.
	@inlinable
	func fetch(forParent record: TaskItem, limit: Int? = nil) throws -> [ TaskItem ]
	{
		try fetch(for: \.parentId, in: record, limit: limit)
	}
	
	/// Fetches the ``TaskItem`` records related to itself (`nextId`).
	/// 
	/// This fetches the related ``TaskItem`` records using the
	/// ``TaskItem/nextId`` property.
	/// 
	/// Example:
	/// ```swift
	/// let record         : TaskItem = ...
	/// let relatedRecords = try db.taskItems.fetch(forNext: record)
	/// ```
	/// 
	/// - Parameters:
	///   - record: The ``TaskItem`` record.
	///   - limit: An optional limit of records to fetch (defaults to `nil`).
	/// - Returns: The related ``TaskItem`` records.
	@inlinable
	func fetch(forNext record: TaskItem, limit: Int? = nil) throws -> [ TaskItem ]
	{
		try fetch(for: \.nextId, in: record, limit: limit)
	}
}

#if swift(>=5.5)
#if canImport(_Concurrency)
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public extension SQLRecordFetchOperations
	where T == TaskList, Ops: SQLDatabaseFetchOperations & SQLDatabaseAsyncOperations, Ops.RecordTypes == FingerStringDB.RecordTypes
{
	
	/// Fetch the ``TaskList`` record related to a ``TaskItem`` (`listId`).
	/// 
	/// This fetches the related ``TaskList`` record using the
	/// ``TaskItem/listId`` property.
	/// 
	/// Example:
	/// ```swift
	/// let sourceRecord  : TaskItem = ...
	/// let relatedRecord = try await db.taskLists.find(for: sourceRecord)
	/// ```
	/// 
	/// - Parameters:
	///   - record: The ``TaskItem`` record.
	/// - Returns: The related ``TaskList`` record (throws if not found).
	@inlinable
	func find(`for` record: TaskItem) async throws -> TaskList
	{
		if let record = try await operations[dynamicMember: \.taskItems].findTarget(
			for: \.listId,
			in: record
		) {
			return record
		}
		else {
			throw LighterError(.couldNotFindRelationshipTarget, SQLITE_CONSTRAINT)
		}
	}
}
#endif // required canImports
#endif // swift(>=5.5)

#if swift(>=5.5)
#if canImport(_Concurrency)
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public extension SQLRecordFetchOperations
	where T == TaskItem, Ops: SQLDatabaseFetchOperations & SQLDatabaseAsyncOperations, Ops.RecordTypes == FingerStringDB.RecordTypes
{
	
	/// Fetch the ``TaskItem`` record related to itself (`parentId`).
	/// 
	/// This fetches the related ``TaskItem`` record using the
	/// ``TaskItem/parentId`` property.
	/// 
	/// Example:
	/// ```swift
	/// let sourceRecord  : TaskItem = ...
	/// let relatedRecord = try await db.taskItems.find(forParent: sourceRecord)
	/// ```
	/// 
	/// - Parameters:
	///   - record: The ``TaskItem`` record.
	/// - Returns: The related ``TaskItem`` record, or `nil` if not found.
	@inlinable
	func find(forParent record: TaskItem) async throws -> TaskItem?
	{
		try await operations[dynamicMember: \.taskItems].findTarget(
			for: \.parentId,
			in: record
		)
	}
	
	/// Fetch the ``TaskItem`` record related to itself (`nextId`).
	/// 
	/// This fetches the related ``TaskItem`` record using the
	/// ``TaskItem/nextId`` property.
	/// 
	/// Example:
	/// ```swift
	/// let sourceRecord  : TaskItem = ...
	/// let relatedRecord = try await db.taskItems.find(forNext: sourceRecord)
	/// ```
	/// 
	/// - Parameters:
	///   - record: The ``TaskItem`` record.
	/// - Returns: The related ``TaskItem`` record, or `nil` if not found.
	@inlinable
	func find(forNext record: TaskItem) async throws -> TaskItem?
	{
		try await operations[dynamicMember: \.taskItems].findTarget(
			for: \.nextId,
			in: record
		)
	}
	
	/// Fetches the ``TaskItem`` records related to a ``TaskList`` (`listId`).
	/// 
	/// This fetches the related ``TaskList`` records using the
	/// ``TaskItem/listId`` property.
	/// 
	/// Example:
	/// ```swift
	/// let record         : TaskList = ...
	/// let relatedRecords = try await db.taskItems.fetch(forList: record)
	/// ```
	/// 
	/// - Parameters:
	///   - record: The ``TaskList`` record.
	///   - limit: An optional limit of records to fetch (defaults to `nil`).
	/// - Returns: The related ``TaskList`` records.
	@inlinable
	func fetch(forList record: TaskList, limit: Int? = nil) async throws -> [ TaskItem ]
	{
		try await fetch(for: \.listId, in: record, limit: limit)
	}
	
	/// Fetches the ``TaskItem`` records related to itself (`parentId`).
	/// 
	/// This fetches the related ``TaskItem`` records using the
	/// ``TaskItem/parentId`` property.
	/// 
	/// Example:
	/// ```swift
	/// let record         : TaskItem = ...
	/// let relatedRecords = try await db.taskItems.fetch(forParent: record)
	/// ```
	/// 
	/// - Parameters:
	///   - record: The ``TaskItem`` record.
	///   - limit: An optional limit of records to fetch (defaults to `nil`).
	/// - Returns: The related ``TaskItem`` records.
	@inlinable
	func fetch(forParent record: TaskItem, limit: Int? = nil)
		async throws -> [ TaskItem ]
	{
		try await fetch(for: \.parentId, in: record, limit: limit)
	}
	
	/// Fetches the ``TaskItem`` records related to itself (`nextId`).
	/// 
	/// This fetches the related ``TaskItem`` records using the
	/// ``TaskItem/nextId`` property.
	/// 
	/// Example:
	/// ```swift
	/// let record         : TaskItem = ...
	/// let relatedRecords = try await db.taskItems.fetch(forNext: record)
	/// ```
	/// 
	/// - Parameters:
	///   - record: The ``TaskItem`` record.
	///   - limit: An optional limit of records to fetch (defaults to `nil`).
	/// - Returns: The related ``TaskItem`` records.
	@inlinable
	func fetch(forNext record: TaskItem, limit: Int? = nil) async throws -> [ TaskItem ]
	{
		try await fetch(for: \.nextId, in: record, limit: limit)
	}
}
#endif // required canImports
#endif // swift(>=5.5)
