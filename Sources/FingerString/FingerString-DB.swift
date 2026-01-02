// Autocreated by sqlite2swift at 2026-01-02T20:20:49Z

import SQLite3
import Foundation
import Lighter

/**
 * Create a SQLite3 database
 * 
 * The database is created using the SQL `create` statements in the
 * Schema structures.
 * 
 * If the operation is successful, the open database handle will be
 * returned in the `db` `inout` parameter.
 * If the open succeeds, but the SQL execution fails, an incomplete
 * database can be left behind. I.e. if an error happens, the path
 * should be tested and deleted if appropriate.
 * 
 * Example:
 * ```swift
 * var db : OpaquePointer!
 * let rc = sqlite3_create_fingerstringdb(path, &db)
 * ```
 * 
 * - Parameters:
 *   - path: Path of the database.
 *   - flags: Custom open flags.
 *   - db: A SQLite3 database handle, if successful.
 * - Returns: The SQLite3 error code (`SQLITE_OK` on success).
 */
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

/**
 * Insert a ``TaskList`` record in the SQLite database.
 * 
 * This operates on a raw SQLite database handle (as returned by
 * `sqlite3_open`).
 * 
 * Example:
 * ```swift
 * let rc = sqlite3_task_list_insert(db, record)
 * assert(rc == SQLITE_OK)
 * ```
 * 
 * - Parameters:
 *   - db: SQLite3 database handle.
 *   - record: The record to insert. Updated with the actual table values (e.g. assigned primary key).
 * - Returns: The SQLite error code (of `sqlite3_prepare/step`), e.g. `SQLITE_OK`.
 */
@inlinable
@discardableResult
public func sqlite3_task_list_insert(
	_ db: OpaquePointer!,
	_ record: inout FingerStringDB.TaskList
) -> Int32
{
	let sql = FingerStringDB.useInsertReturning ? TaskList.Schema.insertReturning : TaskList.Schema.insert
	var handle : OpaquePointer? = nil
	guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
	      let statement = handle else { return sqlite3_errcode(db) }
	defer { sqlite3_finalize(statement) }
	return record.bind(
		to: statement,
		indices: FingerStringDB.TaskList.Schema.insertParameterIndices
	) {
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
			record = FingerStringDB.TaskList(
				statement,
				indices: FingerStringDB.TaskList.Schema.selectColumnIndices
			)
			return SQLITE_OK
		}
		else if rc != SQLITE_ROW {
			return sqlite3_errcode(db)
		}
		record = FingerStringDB.TaskList(
			statement,
			indices: FingerStringDB.TaskList.Schema.selectColumnIndices
		)
		return SQLITE_OK
	}
}

/**
 * Update a ``TaskList`` record in the SQLite database.
 * 
 * This operates on a raw SQLite database handle (as returned by
 * `sqlite3_open`).
 * 
 * Example:
 * ```swift
 * let rc = sqlite3_task_list_update(db, record)
 * assert(rc == SQLITE_OK)
 * ```
 * 
 * - Parameters:
 *   - db: SQLite3 database handle.
 *   - record: The ``TaskList`` record to update.
 * - Returns: The SQLite error code (of `sqlite3_prepare/step`), e.g. `SQLITE_OK`.
 */
@inlinable
@discardableResult
public func sqlite3_task_list_update(
	_ db: OpaquePointer!,
	_ record: FingerStringDB.TaskList
) -> Int32
{
	let sql = TaskList.Schema.update
	var handle : OpaquePointer? = nil
	guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
	      let statement = handle else { return sqlite3_errcode(db) }
	defer { sqlite3_finalize(statement) }
	return record.bind(
		to: statement,
		indices: FingerStringDB.TaskList.Schema.updateParameterIndices
	) {
		let rc = sqlite3_step(statement)
		return rc != SQLITE_DONE && rc != SQLITE_ROW ? sqlite3_errcode(db) : SQLITE_OK
	}
}

/**
 * Delete a ``TaskList`` record in the SQLite database.
 * 
 * This operates on a raw SQLite database handle (as returned by
 * `sqlite3_open`).
 * 
 * Example:
 * ```swift
 * let rc = sqlite3_task_list_delete(db, record)
 * assert(rc == SQLITE_OK)
 * ```
 * 
 * - Parameters:
 *   - db: SQLite3 database handle.
 *   - record: The ``TaskList`` record to delete.
 * - Returns: The SQLite error code (of `sqlite3_prepare/step`), e.g. `SQLITE_OK`.
 */
@inlinable
@discardableResult
public func sqlite3_task_list_delete(
	_ db: OpaquePointer!,
	_ record: FingerStringDB.TaskList
) -> Int32
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

/**
 * Fetch ``TaskList`` records, filtering using a Swift closure.
 * 
 * This is fetching full ``TaskList`` records from the passed in SQLite database
 * handle. The filtering is done within SQLite, but using a Swift closure
 * that can be passed in.
 * 
 * Within that closure other SQL queries can be done on separate connections,
 * but *not* within the same database handle that is being passed in (because
 * the closure is executed in the context of the query).
 * 
 * Sorting can be done using raw SQL (by passing in a `orderBy` parameter,
 * e.g. `orderBy: "name DESC"`),
 * or just in Swift (e.g. `fetch(in: db).sorted { $0.name > $1.name }`).
 * Since the matching is done in Swift anyways, the primary advantage of
 * doing it in SQL is that a `LIMIT` can be applied efficiently (i.e. w/o
 * walking and loading all rows).
 * 
 * If the function returns `nil`, the error can be found using the usual
 * `sqlite3_errcode` and companions.
 * 
 * Example:
 * ```swift
 * let records = sqlite3_task_lists_fetch(db) { record in
 *   record.name != "Duck"
 * }
 * 
 * let records = sqlite3_task_lists_fetch(db, orderBy: "name", limit: 5) {
 *   $0.firstname != nil
 * }
 * ```
 * 
 * - Parameters:
 *   - db: The SQLite database handle (as returned by `sqlite3_open`)
 *   - sql: Optional custom SQL yielding ``TaskList`` records.
 *   - orderBySQL: If set, some SQL that is added as an `ORDER BY` clause (e.g. `name DESC`).
 *   - limit: An optional fetch limit.
 *   - filter: A Swift closure used for filtering, taking the``TaskList`` record to be matched.
 * - Returns: The records matching the query, or `nil` if there was an error.
 */
@inlinable
public func sqlite3_task_lists_fetch(
	_ db: OpaquePointer!,
	sql customSQL: String? = nil,
	orderBy orderBySQL: String? = nil,
	limit: Int? = nil,
	filter: @escaping ( FingerStringDB.TaskList ) -> Bool
) -> [ FingerStringDB.TaskList ]?
{
	withUnsafePointer(to: filter) { ( closurePtr ) in
		guard FingerStringDB.TaskList.Schema.registerSwiftMatcher(
			in: db,
			flags: SQLITE_UTF8,
			matcher: closurePtr
		) == SQLITE_OK else {
			return nil
		}
		defer {
			FingerStringDB.TaskList.Schema.unregisterSwiftMatcher(in: db, flags: SQLITE_UTF8)
		}
		var sql = customSQL ?? FingerStringDB.TaskList.Schema.matchSelect
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
		let indices = customSQL != nil ? FingerStringDB.TaskList.Schema.lookupColumnIndices(in: statement) : FingerStringDB.TaskList.Schema.selectColumnIndices
		var records = [ FingerStringDB.TaskList ]()
		while true {
			let rc = sqlite3_step(statement)
			if rc == SQLITE_DONE {
				break
			}
			else if rc != SQLITE_ROW {
				return nil
			}
			records.append(FingerStringDB.TaskList(statement, indices: indices))
		}
		return records
	}
}

/**
 * Fetch ``TaskList`` records using the base SQLite API.
 * 
 * If the function returns `nil`, the error can be found using the usual
 * `sqlite3_errcode` and companions.
 * 
 * Example:
 * ```swift
 * let records = sqlite3_task_lists_fetch(
 *   db, sql: #"SELECT * FROM task_list"#
 * }
 * 
 * let records = sqlite3_task_lists_fetch(
 *   db, sql: #"SELECT * FROM task_list"#,
 *   orderBy: "name", limit: 5
 * )
 * ```
 * 
 * - Parameters:
 *   - db: The SQLite database handle (as returned by `sqlite3_open`)
 *   - sql: Custom SQL yielding ``TaskList`` records.
 *   - orderBySQL: If set, some SQL that is added as an `ORDER BY` clause (e.g. `name DESC`).
 *   - limit: An optional fetch limit.
 * - Returns: The records matching the query, or `nil` if there was an error.
 */
@inlinable
public func sqlite3_task_lists_fetch(
	_ db: OpaquePointer!,
	sql customSQL: String? = nil,
	orderBy orderBySQL: String? = nil,
	limit: Int? = nil
) -> [ FingerStringDB.TaskList ]?
{
	var sql = customSQL ?? FingerStringDB.TaskList.Schema.select
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
	let indices = customSQL != nil ? FingerStringDB.TaskList.Schema.lookupColumnIndices(in: statement) : FingerStringDB.TaskList.Schema.selectColumnIndices
	var records = [ FingerStringDB.TaskList ]()
	while true {
		let rc = sqlite3_step(statement)
		if rc == SQLITE_DONE {
			break
		}
		else if rc != SQLITE_ROW {
			return nil
		}
		records.append(FingerStringDB.TaskList(statement, indices: indices))
	}
	return records
}

/**
 * Fetch a ``TaskList`` record the base SQLite API.
 * 
 * If the function returns `nil`, the error can be found using the usual
 * `sqlite3_errcode` and companions.
 * 
 * Example:
 * ```swift
 * let record = sqlite3_task_list_find(db, 10) {
 *   print("Found record:", record)
 * }
 * ```
 * 
 * - Parameters:
 *   - db: The SQLite database handle (as returned by `sqlite3_open`)
 *   - sql: Optional custom SQL yielding ``TaskList`` records, has one `?` parameter containing the ID.
 *   - primaryKey: The primary key value to lookup (e.g. `10`)
 * - Returns: The record matching the query, or `nil` if it wasn't found or there was an error.
 */
@inlinable
public func sqlite3_task_list_find(
	_ db: OpaquePointer!,
	sql customSQL: String? = nil,
	_ primaryKey: Int
) -> FingerStringDB.TaskList?
{
	var sql = customSQL ?? FingerStringDB.TaskList.Schema.select
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
	let indices = customSQL != nil ? FingerStringDB.TaskList.Schema.lookupColumnIndices(in: statement) : FingerStringDB.TaskList.Schema.selectColumnIndices
	return FingerStringDB.TaskList(statement, indices: indices)
}

/**
 * Fetches the ``FingerStringDB/ListItem`` records related to a ``FingerStringDB/TaskList`` (`listId`).
 * 
 * This fetches the related ``FingerStringDB/ListItem`` records using the
 * ``FingerStringDB/ListItem/listId`` property.
 * 
 * Example:
 * ```swift
 * let record         : TaskList = ...
 * let relatedRecords = sqlite3_list_items_fetch(db, forList: record)
 * ```
 * 
 * - Parameters:
 *   - db: The SQLite database handle (as returned by `sqlite3_open`)
 *   - record: The ``FingerStringDB/TaskList`` record.
 *   - orderBySQL: If set, some SQL that is added as an `ORDER BY` clause (e.g. `name DESC`).
 *   - limit: An optional fetch limit.
 * - Returns: The related ``FingerStringDB/ListItem`` records.
 */
@inlinable
public func sqlite3_list_items_fetch(
	_ db: OpaquePointer!,
	forList record: FingerStringDB.TaskList,
	orderBy orderBySQL: String? = nil,
	limit: Int? = nil
) -> [ FingerStringDB.ListItem ]?
{
	var sql = FingerStringDB.ListItem.Schema.select
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
	let indices = FingerStringDB.ListItem.Schema.selectColumnIndices
	var records = [ FingerStringDB.ListItem ]()
	while true {
		let rc = sqlite3_step(statement)
		if rc == SQLITE_DONE {
			break
		}
		else if rc != SQLITE_ROW {
			return nil
		}
		records.append(FingerStringDB.ListItem(statement, indices: indices))
	}
	return records
}

/**
 * Insert a ``ListItem`` record in the SQLite database.
 * 
 * This operates on a raw SQLite database handle (as returned by
 * `sqlite3_open`).
 * 
 * Example:
 * ```swift
 * let rc = sqlite3_list_item_insert(db, record)
 * assert(rc == SQLITE_OK)
 * ```
 * 
 * - Parameters:
 *   - db: SQLite3 database handle.
 *   - record: The record to insert. Updated with the actual table values (e.g. assigned primary key).
 * - Returns: The SQLite error code (of `sqlite3_prepare/step`), e.g. `SQLITE_OK`.
 */
@inlinable
@discardableResult
public func sqlite3_list_item_insert(
	_ db: OpaquePointer!,
	_ record: inout FingerStringDB.ListItem
) -> Int32
{
	let sql = FingerStringDB.useInsertReturning ? ListItem.Schema.insertReturning : ListItem.Schema.insert
	var handle : OpaquePointer? = nil
	guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
	      let statement = handle else { return sqlite3_errcode(db) }
	defer { sqlite3_finalize(statement) }
	return record.bind(
		to: statement,
		indices: FingerStringDB.ListItem.Schema.insertParameterIndices
	) {
		let rc = sqlite3_step(statement)
		if rc == SQLITE_DONE {
			var sql = ListItem.Schema.select
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
			record = FingerStringDB.ListItem(
				statement,
				indices: FingerStringDB.ListItem.Schema.selectColumnIndices
			)
			return SQLITE_OK
		}
		else if rc != SQLITE_ROW {
			return sqlite3_errcode(db)
		}
		record = FingerStringDB.ListItem(
			statement,
			indices: FingerStringDB.ListItem.Schema.selectColumnIndices
		)
		return SQLITE_OK
	}
}

/**
 * Update a ``ListItem`` record in the SQLite database.
 * 
 * This operates on a raw SQLite database handle (as returned by
 * `sqlite3_open`).
 * 
 * Example:
 * ```swift
 * let rc = sqlite3_list_item_update(db, record)
 * assert(rc == SQLITE_OK)
 * ```
 * 
 * - Parameters:
 *   - db: SQLite3 database handle.
 *   - record: The ``ListItem`` record to update.
 * - Returns: The SQLite error code (of `sqlite3_prepare/step`), e.g. `SQLITE_OK`.
 */
@inlinable
@discardableResult
public func sqlite3_list_item_update(
	_ db: OpaquePointer!,
	_ record: FingerStringDB.ListItem
) -> Int32
{
	let sql = ListItem.Schema.update
	var handle : OpaquePointer? = nil
	guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
	      let statement = handle else { return sqlite3_errcode(db) }
	defer { sqlite3_finalize(statement) }
	return record.bind(
		to: statement,
		indices: FingerStringDB.ListItem.Schema.updateParameterIndices
	) {
		let rc = sqlite3_step(statement)
		return rc != SQLITE_DONE && rc != SQLITE_ROW ? sqlite3_errcode(db) : SQLITE_OK
	}
}

/**
 * Delete a ``ListItem`` record in the SQLite database.
 * 
 * This operates on a raw SQLite database handle (as returned by
 * `sqlite3_open`).
 * 
 * Example:
 * ```swift
 * let rc = sqlite3_list_item_delete(db, record)
 * assert(rc == SQLITE_OK)
 * ```
 * 
 * - Parameters:
 *   - db: SQLite3 database handle.
 *   - record: The ``ListItem`` record to delete.
 * - Returns: The SQLite error code (of `sqlite3_prepare/step`), e.g. `SQLITE_OK`.
 */
@inlinable
@discardableResult
public func sqlite3_list_item_delete(
	_ db: OpaquePointer!,
	_ record: FingerStringDB.ListItem
) -> Int32
{
	let sql = ListItem.Schema.delete
	var handle : OpaquePointer? = nil
	guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
	      let statement = handle else { return sqlite3_errcode(db) }
	defer { sqlite3_finalize(statement) }
	sqlite3_bind_int64(statement, 1, Int64(record.id))
	let rc = sqlite3_step(statement)
	return rc != SQLITE_DONE && rc != SQLITE_ROW ? sqlite3_errcode(db) : SQLITE_OK
}

/**
 * Fetch ``ListItem`` records, filtering using a Swift closure.
 * 
 * This is fetching full ``ListItem`` records from the passed in SQLite database
 * handle. The filtering is done within SQLite, but using a Swift closure
 * that can be passed in.
 * 
 * Within that closure other SQL queries can be done on separate connections,
 * but *not* within the same database handle that is being passed in (because
 * the closure is executed in the context of the query).
 * 
 * Sorting can be done using raw SQL (by passing in a `orderBy` parameter,
 * e.g. `orderBy: "name DESC"`),
 * or just in Swift (e.g. `fetch(in: db).sorted { $0.name > $1.name }`).
 * Since the matching is done in Swift anyways, the primary advantage of
 * doing it in SQL is that a `LIMIT` can be applied efficiently (i.e. w/o
 * walking and loading all rows).
 * 
 * If the function returns `nil`, the error can be found using the usual
 * `sqlite3_errcode` and companions.
 * 
 * Example:
 * ```swift
 * let records = sqlite3_list_items_fetch(db) { record in
 *   record.name != "Duck"
 * }
 * 
 * let records = sqlite3_list_items_fetch(db, orderBy: "name", limit: 5) {
 *   $0.firstname != nil
 * }
 * ```
 * 
 * - Parameters:
 *   - db: The SQLite database handle (as returned by `sqlite3_open`)
 *   - sql: Optional custom SQL yielding ``ListItem`` records.
 *   - orderBySQL: If set, some SQL that is added as an `ORDER BY` clause (e.g. `name DESC`).
 *   - limit: An optional fetch limit.
 *   - filter: A Swift closure used for filtering, taking the``ListItem`` record to be matched.
 * - Returns: The records matching the query, or `nil` if there was an error.
 */
@inlinable
public func sqlite3_list_items_fetch(
	_ db: OpaquePointer!,
	sql customSQL: String? = nil,
	orderBy orderBySQL: String? = nil,
	limit: Int? = nil,
	filter: @escaping ( FingerStringDB.ListItem ) -> Bool
) -> [ FingerStringDB.ListItem ]?
{
	withUnsafePointer(to: filter) { ( closurePtr ) in
		guard FingerStringDB.ListItem.Schema.registerSwiftMatcher(
			in: db,
			flags: SQLITE_UTF8,
			matcher: closurePtr
		) == SQLITE_OK else {
			return nil
		}
		defer {
			FingerStringDB.ListItem.Schema.unregisterSwiftMatcher(in: db, flags: SQLITE_UTF8)
		}
		var sql = customSQL ?? FingerStringDB.ListItem.Schema.matchSelect
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
		let indices = customSQL != nil ? FingerStringDB.ListItem.Schema.lookupColumnIndices(in: statement) : FingerStringDB.ListItem.Schema.selectColumnIndices
		var records = [ FingerStringDB.ListItem ]()
		while true {
			let rc = sqlite3_step(statement)
			if rc == SQLITE_DONE {
				break
			}
			else if rc != SQLITE_ROW {
				return nil
			}
			records.append(FingerStringDB.ListItem(statement, indices: indices))
		}
		return records
	}
}

/**
 * Fetch ``ListItem`` records using the base SQLite API.
 * 
 * If the function returns `nil`, the error can be found using the usual
 * `sqlite3_errcode` and companions.
 * 
 * Example:
 * ```swift
 * let records = sqlite3_list_items_fetch(
 *   db, sql: #"SELECT * FROM list_item"#
 * }
 * 
 * let records = sqlite3_list_items_fetch(
 *   db, sql: #"SELECT * FROM list_item"#,
 *   orderBy: "name", limit: 5
 * )
 * ```
 * 
 * - Parameters:
 *   - db: The SQLite database handle (as returned by `sqlite3_open`)
 *   - sql: Custom SQL yielding ``ListItem`` records.
 *   - orderBySQL: If set, some SQL that is added as an `ORDER BY` clause (e.g. `name DESC`).
 *   - limit: An optional fetch limit.
 * - Returns: The records matching the query, or `nil` if there was an error.
 */
@inlinable
public func sqlite3_list_items_fetch(
	_ db: OpaquePointer!,
	sql customSQL: String? = nil,
	orderBy orderBySQL: String? = nil,
	limit: Int? = nil
) -> [ FingerStringDB.ListItem ]?
{
	var sql = customSQL ?? FingerStringDB.ListItem.Schema.select
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
	let indices = customSQL != nil ? FingerStringDB.ListItem.Schema.lookupColumnIndices(in: statement) : FingerStringDB.ListItem.Schema.selectColumnIndices
	var records = [ FingerStringDB.ListItem ]()
	while true {
		let rc = sqlite3_step(statement)
		if rc == SQLITE_DONE {
			break
		}
		else if rc != SQLITE_ROW {
			return nil
		}
		records.append(FingerStringDB.ListItem(statement, indices: indices))
	}
	return records
}

/**
 * Fetch a ``ListItem`` record the base SQLite API.
 * 
 * If the function returns `nil`, the error can be found using the usual
 * `sqlite3_errcode` and companions.
 * 
 * Example:
 * ```swift
 * let record = sqlite3_list_item_find(db, 10) {
 *   print("Found record:", record)
 * }
 * ```
 * 
 * - Parameters:
 *   - db: The SQLite database handle (as returned by `sqlite3_open`)
 *   - sql: Optional custom SQL yielding ``ListItem`` records, has one `?` parameter containing the ID.
 *   - primaryKey: The primary key value to lookup (e.g. `10`)
 * - Returns: The record matching the query, or `nil` if it wasn't found or there was an error.
 */
@inlinable
public func sqlite3_list_item_find(
	_ db: OpaquePointer!,
	sql customSQL: String? = nil,
	_ primaryKey: Int
) -> FingerStringDB.ListItem?
{
	var sql = customSQL ?? FingerStringDB.ListItem.Schema.select
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
	let indices = customSQL != nil ? FingerStringDB.ListItem.Schema.lookupColumnIndices(in: statement) : FingerStringDB.ListItem.Schema.selectColumnIndices
	return FingerStringDB.ListItem(statement, indices: indices)
}

/**
 * Fetch the ``TaskList`` record related to an ``ListItem`` (`listId`).
 * 
 * This fetches the related ``TaskList`` record using the
 * ``ListItem/listId`` property.
 * 
 * Example:
 * ```swift
 * let sourceRecord  : ListItem = ...
 * let relatedRecord = sqlite3_task_list_find(db, for: sourceRecord)
 * ```
 * 
 * - Parameters:
 *   - db: The SQLite database handle (as returned by `sqlite3_open`)
 *   - record: The ``ListItem`` record.
 * - Returns: The related ``TaskList`` record, or `nil` if not found/error.
 */
@inlinable
public func sqlite3_task_list_find(
	_ db: OpaquePointer!,
	`for` record: FingerStringDB.ListItem
) -> FingerStringDB.TaskList?
{
	var sql = FingerStringDB.TaskList.Schema.select
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
	let indices = FingerStringDB.TaskList.Schema.selectColumnIndices
	return FingerStringDB.TaskList(statement, indices: indices)
}

/**
 * Fetch the ``ListItem`` record related to itself (`parentId`).
 * 
 * This fetches the related ``ListItem`` record using the
 * ``ListItem/parentId`` property.
 * 
 * Example:
 * ```swift
 * let sourceRecord  : ListItem = ...
 * let relatedRecord = sqlite3_list_item_find(db, forParent: sourceRecord)
 * ```
 * 
 * - Parameters:
 *   - db: The SQLite database handle (as returned by `sqlite3_open`)
 *   - record: The ``ListItem`` record.
 * - Returns: The related ``ListItem`` record, or `nil` if not found/error.
 */
@inlinable
public func sqlite3_list_item_find(
	_ db: OpaquePointer!,
	forParent record: FingerStringDB.ListItem
) -> FingerStringDB.ListItem?
{
	var sql = FingerStringDB.ListItem.Schema.select
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
	let indices = FingerStringDB.ListItem.Schema.selectColumnIndices
	return FingerStringDB.ListItem(statement, indices: indices)
}

/**
 * Fetch the ``ListItem`` record related to itself (`nextId`).
 * 
 * This fetches the related ``ListItem`` record using the
 * ``ListItem/nextId`` property.
 * 
 * Example:
 * ```swift
 * let sourceRecord  : ListItem = ...
 * let relatedRecord = sqlite3_list_item_find(db, forNext: sourceRecord)
 * ```
 * 
 * - Parameters:
 *   - db: The SQLite database handle (as returned by `sqlite3_open`)
 *   - record: The ``ListItem`` record.
 * - Returns: The related ``ListItem`` record, or `nil` if not found/error.
 */
@inlinable
public func sqlite3_list_item_find(
	_ db: OpaquePointer!,
	forNext record: FingerStringDB.ListItem
) -> FingerStringDB.ListItem?
{
	var sql = FingerStringDB.ListItem.Schema.select
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
	let indices = FingerStringDB.ListItem.Schema.selectColumnIndices
	return FingerStringDB.ListItem(statement, indices: indices)
}

/**
 * Fetches the ``FingerStringDB/ListItem`` records related to itself (`parentId`).
 * 
 * This fetches the related ``FingerStringDB/ListItem`` records using the
 * ``FingerStringDB/ListItem/parentId`` property.
 * 
 * Example:
 * ```swift
 * let record         : ListItem = ...
 * let relatedRecords = sqlite3_list_items_fetch(db, forParent: record)
 * ```
 * 
 * - Parameters:
 *   - db: The SQLite database handle (as returned by `sqlite3_open`)
 *   - record: The ``FingerStringDB/ListItem`` record.
 *   - orderBySQL: If set, some SQL that is added as an `ORDER BY` clause (e.g. `name DESC`).
 *   - limit: An optional fetch limit.
 * - Returns: The related ``FingerStringDB/ListItem`` records.
 */
@inlinable
public func sqlite3_list_items_fetch(
	_ db: OpaquePointer!,
	forParent record: FingerStringDB.ListItem,
	orderBy orderBySQL: String? = nil,
	limit: Int? = nil
) -> [ FingerStringDB.ListItem ]?
{
	var sql = FingerStringDB.ListItem.Schema.select
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
	let indices = FingerStringDB.ListItem.Schema.selectColumnIndices
	var records = [ FingerStringDB.ListItem ]()
	while true {
		let rc = sqlite3_step(statement)
		if rc == SQLITE_DONE {
			break
		}
		else if rc != SQLITE_ROW {
			return nil
		}
		records.append(FingerStringDB.ListItem(statement, indices: indices))
	}
	return records
}

/**
 * Fetches the ``FingerStringDB/ListItem`` records related to itself (`nextId`).
 * 
 * This fetches the related ``FingerStringDB/ListItem`` records using the
 * ``FingerStringDB/ListItem/nextId`` property.
 * 
 * Example:
 * ```swift
 * let record         : ListItem = ...
 * let relatedRecords = sqlite3_list_items_fetch(db, forNext: record)
 * ```
 * 
 * - Parameters:
 *   - db: The SQLite database handle (as returned by `sqlite3_open`)
 *   - record: The ``FingerStringDB/ListItem`` record.
 *   - orderBySQL: If set, some SQL that is added as an `ORDER BY` clause (e.g. `name DESC`).
 *   - limit: An optional fetch limit.
 * - Returns: The related ``FingerStringDB/ListItem`` records.
 */
@inlinable
public func sqlite3_list_items_fetch(
	_ db: OpaquePointer!,
	forNext record: FingerStringDB.ListItem,
	orderBy orderBySQL: String? = nil,
	limit: Int? = nil
) -> [ FingerStringDB.ListItem ]?
{
	var sql = FingerStringDB.ListItem.Schema.select
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
	let indices = FingerStringDB.ListItem.Schema.selectColumnIndices
	var records = [ FingerStringDB.ListItem ]()
	while true {
		let rc = sqlite3_step(statement)
		if rc == SQLITE_DONE {
			break
		}
		else if rc != SQLITE_ROW {
			return nil
		}
		records.append(FingerStringDB.ListItem(statement, indices: indices))
	}
	return records
}

/**
 * A structure representing a SQLite database.
 * 
 * ### Database Schema
 * 
 * The schema captures the SQLite table/view catalog as safe Swift types.
 * 
 * #### Tables
 * 
 * - ``TaskList`` (SQL: `task_list`)
 * - ``ListItem`` (SQL: `list_item`)
 * 
 * > Hint: Use [SQL Views](https://www.sqlite.org/lang_createview.html)
 * >       to create Swift types that represent common queries.
 * >       (E.g. joins between tables or fragments of table data.)
 * 
 * ### Examples
 * 
 * Perform record operations on ``TaskList`` records:
 * ```swift
 * let records = try await db.taskLists.filter(orderBy: \.slug) {
 *   $0.slug != nil
 * }
 * 
 * try await db.transaction { tx in
 *   var record = try tx.taskLists.find(2) // find by primaryKey
 *   
 *   record.slug = "Hunt"
 *   try tx.update(record)
 * 
 *   let newRecord = try tx.insert(record)
 *   try tx.delete(newRecord)
 * }
 * ```
 * 
 * Perform column selects on the `task_list` table:
 * ```swift
 * let values = try await db.select(from: \.taskLists, \.slug) {
 *   $0.in([ 2, 3 ])
 * }
 * ```
 * 
 * Perform low level operations on ``TaskList`` records:
 * ```swift
 * var db : OpaquePointer?
 * sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE, nil)
 * 
 * var records = sqlite3_task_lists_fetch(db, orderBy: "slug", limit: 5) {
 *   $0.slug != nil
 * }!
 * records[1].slug = "Hunt"
 * sqlite3_task_lists_update(db, records[1])
 * 
 * sqlite3_task_lists_delete(db, records[0])
 * sqlite3_task_lists_insert(db, records[0]) // re-add
 * ```
 */
@dynamicMemberLookup
public struct FingerStringDB : SQLDatabase, SQLDatabaseAsyncChangeOperations, SQLCreationStatementsHolder {
	
	/**
	 * Mappings of table/view Swift types to their "reference name".
	 * 
	 * The `RecordTypes` structure contains a variable for the Swift type
	 * associated each table/view of the database. It maps the tables
	 * "reference names" (e.g. ``taskLists``) to the
	 * "record type" of the table (e.g. ``TaskList``.self).
	 */
	public struct RecordTypes : Swift.Sendable {
		
		/// Returns the TaskList type information (SQL: `task_list`).
		public let taskLists = TaskList.self
		
		/// Returns the ListItem type information (SQL: `list_item`).
		public let listItems = ListItem.self
	}
	
	/**
	 * Record representing the `task_list` SQL table.
	 * 
	 * Record types represent rows within tables&views in a SQLite database.
	 * They are returned by the functions or queries/filters generated by
	 * Enlighter.
	 * 
	 * ### Examples
	 * 
	 * Perform record operations on ``TaskList`` records:
	 * ```swift
	 * let records = try await db.taskLists.filter(orderBy: \.slug) {
	 *   $0.slug != nil
	 * }
	 * 
	 * try await db.transaction { tx in
	 *   var record = try tx.taskLists.find(2) // find by primaryKey
	 *   
	 *   record.slug = "Hunt"
	 *   try tx.update(record)
	 * 
	 *   let newRecord = try tx.insert(record)
	 *   try tx.delete(newRecord)
	 * }
	 * ```
	 * 
	 * Perform column selects on the `task_list` table:
	 * ```swift
	 * let values = try await db.select(from: \.taskLists, \.slug) {
	 *   $0.in([ 2, 3 ])
	 * }
	 * ```
	 * 
	 * Perform low level operations on ``TaskList`` records:
	 * ```swift
	 * var db : OpaquePointer?
	 * sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE, nil)
	 * 
	 * var records = sqlite3_task_lists_fetch(db, orderBy: "slug", limit: 5) {
	 *   $0.slug != nil
	 * }!
	 * records[1].slug = "Hunt"
	 * sqlite3_task_lists_update(db, records[1])
	 * 
	 * sqlite3_task_lists_delete(db, records[0])
	 * sqlite3_task_lists_insert(db, records[0]) // re-add
	 * ```
	 * 
	 * ### SQL
	 * 
	 * The SQL used to create the table associated with the record:
	 * ```sql
	 * CREATE TABLE task_list (
	 * 	id INTEGER PRIMARY KEY NOT NULL,
	 * 	slug TEXT UNIQUE NOT NULL,
	 * 	title TEXT,
	 * 	description TEXT,
	 * 	first_item_id INTEGER
	 * )
	 * ```
	 */
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
		
		/// Column `first_item_id` (`INTEGER`), optional (default: `nil`).
		public var firstItemId : Int?
		
		/**
		 * Initialize a new ``TaskList`` record.
		 * 
		 * - Parameters:
		 *   - id: Primary key `id` (`INTEGER`), required.
		 *   - slug: Column `slug` (`TEXT`), required.
		 *   - title: Column `title` (`TEXT`), optional (default: `nil`).
		 *   - description: Column `description` (`TEXT`), optional (default: `nil`).
		 *   - firstItemId: Column `first_item_id` (`INTEGER`), optional (default: `nil`).
		 */
		@inlinable
		public init(
			id: Int = Int.min,
			slug: String,
			title: String? = nil,
			description: String? = nil,
			firstItemId: Int? = nil
		)
		{
			self.id = id
			self.slug = slug
			self.title = title
			self.description = description
			self.firstItemId = firstItemId
		}
	}
	
	/**
	 * Record representing the `list_item` SQL table.
	 * 
	 * Record types represent rows within tables&views in a SQLite database.
	 * They are returned by the functions or queries/filters generated by
	 * Enlighter.
	 * 
	 * ### Examples
	 * 
	 * Perform record operations on ``ListItem`` records:
	 * ```swift
	 * let records = try await db.listItems.filter(orderBy: \.itemId) {
	 *   $0.itemId != nil
	 * }
	 * 
	 * try await db.transaction { tx in
	 *   var record = try tx.listItems.find(2) // find by primaryKey
	 *   
	 *   record.itemId = "Hunt"
	 *   try tx.update(record)
	 * 
	 *   let newRecord = try tx.insert(record)
	 *   try tx.delete(newRecord)
	 * }
	 * ```
	 * 
	 * Perform column selects on the `list_item` table:
	 * ```swift
	 * let values = try await db.select(from: \.listItems, \.itemId) {
	 *   $0.in([ 2, 3 ])
	 * }
	 * ```
	 * 
	 * Perform low level operations on ``ListItem`` records:
	 * ```swift
	 * var db : OpaquePointer?
	 * sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE, nil)
	 * 
	 * var records = sqlite3_list_items_fetch(db, orderBy: "itemId", limit: 5) {
	 *   $0.itemId != nil
	 * }!
	 * records[1].itemId = "Hunt"
	 * sqlite3_list_items_update(db, records[1])
	 * 
	 * sqlite3_list_items_delete(db, records[0])
	 * sqlite3_list_items_insert(db, records[0]) // re-add
	 * ```
	 * 
	 * ### SQL
	 * 
	 * The SQL used to create the table associated with the record:
	 * ```sql
	 * CREATE TABLE list_item (
	 * 	id INTEGER PRIMARY KEY NOT NULL,
	 * 	list_id INTEGER NOT NULL,
	 * 	parent_id INTEGER,
	 * 	next_id INTEGER,
	 * 	item_id TEXT NOT NULL,
	 * 	label TEXT NOT NULL,
	 * 	note TEXT,
	 * 	FOREIGN KEY(list_id) REFERENCES task_list(id),
	 * 	FOREIGN KEY(parent_id) REFERENCES list_item(id),
	 * 	FOREIGN KEY(next_id) REFERENCES list_item(id)
	 * )
	 * ```
	 */
	public struct ListItem : Identifiable, SQLKeyedTableRecord, Codable, Sendable {
		
		/// Static SQL type information for the ``ListItem`` record.
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
		
		/**
		 * Initialize a new ``ListItem`` record.
		 * 
		 * - Parameters:
		 *   - id: Primary key `id` (`INTEGER`), required.
		 *   - listId: Column `list_id` (`INTEGER`), required.
		 *   - parentId: Column `parent_id` (`INTEGER`), optional (default: `nil`).
		 *   - nextId: Column `next_id` (`INTEGER`), optional (default: `nil`).
		 *   - itemId: Column `item_id` (`TEXT`), required.
		 *   - label: Column `label` (`TEXT`), required.
		 *   - note: Column `note` (`TEXT`), optional (default: `nil`).
		 */
		@inlinable
		public init(
			id: Int = Int.min,
			listId: Int,
			parentId: Int? = nil,
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
	
	/// Property based access to the ``RecordTypes-swift.struct``.
	public static let recordTypes = RecordTypes()
	
	#if swift(>=5.7)
	/// All RecordTypes defined in the database.
	public static let _allRecordTypes : [ any SQLRecord.Type ] = [ TaskList.self, ListItem.self ]
	#endif // swift(>=5.7)
	
	/// User version of the database (`PRAGMA user_version`).
	public static let userVersion = 0
	
	/// Whether `INSERT … RETURNING` should be used (requires SQLite 3.35.0+).
	public static let useInsertReturning = sqlite3_libversion_number() >= 3035000
	
	/// SQL that can be used to recreate the database structure.
	@inlinable
	public static var creationSQL : String {
		var sql = ""
		sql.append(FingerStringDB.TaskList.Schema.create)
		sql.append(FingerStringDB.ListItem.Schema.create)
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
	
	/**
	 * Initialize ``FingerStringDB`` with a `URL`.
	 * 
	 * Configures the database with a simple connection pool opening the
	 * specified `URL`.
	 * And optional `readOnly` flag can be set (defaults to `false`).
	 * 
	 * Example:
	 * ```swift
	 * let db = FingerStringDB(url: ...)
	 * 
	 * // Write operations will raise an error.
	 * let readOnly = FingerStringDB(
	 *   url: Bundle.module.url(forResource: "samples", withExtension: "db"),
	 *   readOnly: true
	 * )
	 * ```
	 * 
	 * - Parameters:
	 *   - url: A `URL` pointing to the database to be used.
	 *   - readOnly: Whether the database should be opened readonly (default: `false`).
	 */
	@inlinable
	public init(url: URL, readOnly: Bool = false)
	{
		self.connectionHandler = .simplePool(url: url, readOnly: readOnly)
	}
	
	/**
	 * Initialize ``FingerStringDB`` w/ a `SQLConnectionHandler`.
	 * 
	 * `SQLConnectionHandler`'s are used to open SQLite database connections when
	 * queries are run using the `Lighter` APIs.
	 * The `SQLConnectionHandler` is a protocol and custom handlers
	 * can be provided.
	 * 
	 * Example:
	 * ```swift
	 * let db = FingerStringDB(connectionHandler: .simplePool(
	 *   url: Bundle.module.url(forResource: "samples", withExtension: "db"),
	 *   readOnly: true,
	 *   maxAge: 10,
	 *   maximumPoolSizePerConfiguration: 4
	 * ))
	 * ```
	 * 
	 * - Parameters:
	 *   - connectionHandler: The `SQLConnectionHandler` to use w/ the database.
	 */
	@inlinable
	public init(connectionHandler: SQLConnectionHandler)
	{
		self.connectionHandler = connectionHandler
	}
}

public extension FingerStringDB.TaskList {
	
	/**
	 * Static type information for the ``TaskList`` record (`task_list` SQL table).
	 * 
	 * This structure captures the static SQL information associated with the
	 * record.
	 * It is used for static type lookups and more.
	 */
	struct Schema : SQLKeyedTableSchema, SQLSwiftMatchableSchema, SQLCreatableSchema {
		
		public typealias PropertyIndices = ( idx_id: Int32, idx_slug: Int32, idx_title: Int32, idx_description: Int32, idx_firstItemId: Int32 )
		public typealias RecordType = FingerStringDB.TaskList
		public typealias MatchClosureType = ( FingerStringDB.TaskList ) -> Bool
		
		/// The SQL table name associated with the ``TaskList`` record.
		public static let externalName = "task_list"
		
		/// The number of columns the `task_list` table has.
		public static let columnCount : Int32 = 5
		
		/// Information on the records primary key (``TaskList/id``).
		public static let primaryKeyColumn = MappedColumn<FingerStringDB.TaskList, Int>(
			externalName: "id",
			defaultValue: -1,
			keyPath: \FingerStringDB.TaskList.id
		)
		
		/// The SQL used to create the `task_list` table.
		public static let create = 
			#"""
			CREATE TABLE task_list (
				id INTEGER PRIMARY KEY NOT NULL,
				slug TEXT UNIQUE NOT NULL,
				title TEXT,
				description TEXT,
				first_item_id INTEGER
			);
			"""#
		
		/// SQL to `SELECT` all columns of the `task_list` table.
		public static let select = #"SELECT "id", "slug", "title", "description", "first_item_id" FROM "task_list""#
		
		/// SQL fragment representing all columns.
		public static let selectColumns = #""id", "slug", "title", "description", "first_item_id""#
		
		/// Index positions of the properties in ``selectColumns``.
		public static let selectColumnIndices : PropertyIndices = ( 0, 1, 2, 3, 4 )
		
		/// SQL to `SELECT` all columns of the `task_list` table using a Swift filter.
		public static let matchSelect = #"SELECT "id", "slug", "title", "description", "first_item_id" FROM "task_list" WHERE taskLists_swift_match("id", "slug", "title", "description", "first_item_id") != 0"#
		
		/// SQL to `UPDATE` all columns of the `task_list` table.
		public static let update = #"UPDATE "task_list" SET "slug" = ?, "title" = ?, "description" = ?, "first_item_id" = ? WHERE "id" = ?"#
		
		/// Property parameter indicies in the ``update`` SQL
		public static let updateParameterIndices : PropertyIndices = ( 5, 1, 2, 3, 4 )
		
		/// SQL to `INSERT` a record into the `task_list` table.
		public static let insert = #"INSERT INTO "task_list" ( "slug", "title", "description", "first_item_id" ) VALUES ( ?, ?, ?, ? )"#
		
		/// SQL to `INSERT` a record into the `task_list` table.
		public static let insertReturning = #"INSERT INTO "task_list" ( "slug", "title", "description", "first_item_id" ) VALUES ( ?, ?, ?, ? ) RETURNING "id", "slug", "title", "description", "first_item_id""#
		
		/// Property parameter indicies in the ``insert`` SQL
		public static let insertParameterIndices : PropertyIndices = ( -1, 1, 2, 3, 4 )
		
		/// SQL to `DELETE` a record from the `task_list` table.
		public static let delete = #"DELETE FROM "task_list" WHERE "id" = ?"#
		
		/// Property parameter indicies in the ``delete`` SQL
		public static let deleteParameterIndices : PropertyIndices = ( 1, -1, -1, -1, -1 )
		
		/**
		 * Lookup property indices by column name in a statement handle.
		 * 
		 * Properties are ordered in the schema and have a specific index
		 * assigned.
		 * E.g. if the record has two properties, `id` and `name`,
		 * and the query was `SELECT age, task_list_id FROM task_list`,
		 * this would return `( idx_id: 1, idx_name: -1 )`.
		 * Because the `task_list_id` is in the second position and `name`
		 * isn't provided at all.
		 * 
		 * - Parameters:
		 *   - statement: A raw SQLite3 prepared statement handle.
		 * - Returns: The positions of the properties in the prepared statement.
		 */
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
				else if strcmp(col!, "first_item_id") == 0 {
					indices.idx_firstItemId = i
				}
			}
			return indices
		}
		
		/**
		 * Register the Swift matcher function for the ``TaskList`` record.
		 * 
		 * SQLite Swift matcher functions are used to process `filter` queries
		 * and low-level matching w/o the Lighter library.
		 * 
		 * - Parameters:
		 *   - unsafeDatabaseHandle: SQLite3 database handle.
		 *   - flags: SQLite3 function registration flags, default: `SQLITE_UTF8`
		 *   - matcher: A pointer to the Swift closure used to filter the records.
		 * - Returns: The result code of `sqlite3_create_function`, e.g. `SQLITE_OK`.
		 */
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
					let indices = FingerStringDB.TaskList.Schema.selectColumnIndices
					let record = FingerStringDB.TaskList(
						id: (indices.idx_id >= 0) && (indices.idx_id < argc) && (sqlite3_value_type(argv[Int(indices.idx_id)]) != SQLITE_NULL) ? Int(sqlite3_value_int64(argv[Int(indices.idx_id)])) : RecordType.schema.id.defaultValue,
						slug: ((indices.idx_slug >= 0) && (indices.idx_slug < argc) ? (sqlite3_value_text(argv[Int(indices.idx_slug)]).flatMap(String.init(cString:))) : nil) ?? RecordType.schema.slug.defaultValue,
						title: (indices.idx_title >= 0) && (indices.idx_title < argc) ? (sqlite3_value_text(argv[Int(indices.idx_title)]).flatMap(String.init(cString:))) : RecordType.schema.title.defaultValue,
						description: (indices.idx_description >= 0) && (indices.idx_description < argc) ? (sqlite3_value_text(argv[Int(indices.idx_description)]).flatMap(String.init(cString:))) : RecordType.schema.description.defaultValue,
						firstItemId: (indices.idx_firstItemId >= 0) && (indices.idx_firstItemId < argc) ? (sqlite3_value_type(argv[Int(indices.idx_firstItemId)]) != SQLITE_NULL ? Int(sqlite3_value_int64(argv[Int(indices.idx_firstItemId)])) : nil) : RecordType.schema.firstItemId.defaultValue
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
				FingerStringDB.TaskList.Schema.columnCount,
				flags,
				UnsafeMutableRawPointer(mutating: matcher),
				dispatch,
				nil,
				nil
			)
		}
		
		/**
		 * Unregister the Swift matcher function for the ``TaskList`` record.
		 * 
		 * SQLite Swift matcher functions are used to process `filter` queries
		 * and low-level matching w/o the Lighter library.
		 * 
		 * - Parameters:
		 *   - unsafeDatabaseHandle: SQLite3 database handle.
		 *   - flags: SQLite3 function registration flags, default: `SQLITE_UTF8`
		 * - Returns: The result code of `sqlite3_create_function`, e.g. `SQLITE_OK`.
		 */
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
				FingerStringDB.TaskList.Schema.columnCount,
				flags,
				nil,
				nil,
				nil,
				nil
			)
		}
		
		/// Type information for property ``TaskList/id`` (`id` column).
		public let id = MappedColumn<FingerStringDB.TaskList, Int>(
			externalName: "id",
			defaultValue: -1,
			keyPath: \FingerStringDB.TaskList.id
		)
		
		/// Type information for property ``TaskList/slug`` (`slug` column).
		public let slug = MappedColumn<FingerStringDB.TaskList, String>(
			externalName: "slug",
			defaultValue: "",
			keyPath: \FingerStringDB.TaskList.slug
		)
		
		/// Type information for property ``TaskList/title`` (`title` column).
		public let title = MappedColumn<FingerStringDB.TaskList, String?>(
			externalName: "title",
			defaultValue: nil,
			keyPath: \FingerStringDB.TaskList.title
		)
		
		/// Type information for property ``TaskList/description`` (`description` column).
		public let description = MappedColumn<FingerStringDB.TaskList, String?>(
			externalName: "description",
			defaultValue: nil,
			keyPath: \FingerStringDB.TaskList.description
		)
		
		/// Type information for property ``TaskList/firstItemId`` (`first_item_id` column).
		public let firstItemId = MappedColumn<FingerStringDB.TaskList, Int?>(
			externalName: "first_item_id",
			defaultValue: nil,
			keyPath: \FingerStringDB.TaskList.firstItemId
		)
		
		#if swift(>=5.7)
		public var _allColumns : [ any SQLColumn ] { [ id, slug, title, description, firstItemId ] }
		#endif // swift(>=5.7)
		
		public init()
		{
		}
	}
	
	/**
	 * Initialize a ``TaskList`` record from a SQLite statement handle.
	 * 
	 * This initializer allows easy setup of a record structure from an
	 * otherwise arbitrarily constructed SQLite prepared statement.
	 * 
	 * If no `indices` are specified, the `Schema/lookupColumnIndices`
	 * function will be used to find the positions of the structure properties
	 * based on their external name.
	 * When looping, it is recommended to do the lookup once, and then
	 * provide the `indices` to the initializer.
	 * 
	 * Required values that are missing in the statement are replaced with
	 * their assigned default values, i.e. this can even be used to perform
	 * partial selects w/ only a minor overhead (the extra space for a
	 * record).
	 * 
	 * Example:
	 * ```swift
	 * var statement : OpaquePointer?
	 * sqlite3_prepare_v2(dbHandle, "SELECT * FROM task_list", -1, &statement, nil)
	 * while sqlite3_step(statement) == SQLITE_ROW {
	 *   let record = TaskList(statement)
	 *   print("Fetched:", record)
	 * }
	 * sqlite3_finalize(statement)
	 * ```
	 * 
	 * - Parameters:
	 *   - statement: Statement handle as returned by `sqlite3_prepare*` functions.
	 *   - indices: Property bindings positions, defaults to `nil` (automatic lookup).
	 */
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
			firstItemId: (indices.idx_firstItemId >= 0) && (indices.idx_firstItemId < argc) ? (sqlite3_column_type(statement, indices.idx_firstItemId) != SQLITE_NULL ? Int(sqlite3_column_int64(statement, indices.idx_firstItemId)) : nil) : Self.schema.firstItemId.defaultValue
		)
	}
	
	/**
	 * Bind all ``TaskList`` properties to a prepared statement and call a closure.
	 * 
	 * *Important*: The bindings are only valid within the closure being executed!
	 * 
	 * Example:
	 * ```swift
	 * var statement : OpaquePointer?
	 * sqlite3_prepare_v2(
	 *   dbHandle,
	 *   #"UPDATE "task_list" SET "slug" = ?, "title" = ?, "description" = ?, "first_item_id" = ? WHERE "id" = ?"#,
	 *   -1, &statement, nil
	 * )
	 * 
	 * let record = TaskList(id: 1, slug: "Hello", title: "World", description: "Duck", firstItemId: 2)
	 * let ok = record.bind(to: statement, indices: ( 5, 1, 2, 3, 4 )) {
	 *   sqlite3_step(statement) == SQLITE_DONE
	 * }
	 * sqlite3_finalize(statement)
	 * ```
	 * 
	 * - Parameters:
	 *   - statement: A SQLite3 statement handle as returned by the `sqlite3_prepare*` functions.
	 *   - indices: The parameter positions for the bindings.
	 *   - execute: Closure executed with bindings applied, bindings _only_ valid within the call!
	 * - Returns: Returns the result of the closure that is passed in.
	 */
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
					if indices.idx_firstItemId >= 0 {
						if let firstItemId = firstItemId {
							sqlite3_bind_int64(statement, indices.idx_firstItemId, Int64(firstItemId))
						}
						else {
							sqlite3_bind_null(statement, indices.idx_firstItemId)
						}
					}
					return try execute()
				}
			}
		}
	}
}

public extension FingerStringDB.ListItem {
	
	/**
	 * Static type information for the ``ListItem`` record (`list_item` SQL table).
	 * 
	 * This structure captures the static SQL information associated with the
	 * record.
	 * It is used for static type lookups and more.
	 */
	struct Schema : SQLKeyedTableSchema, SQLSwiftMatchableSchema, SQLCreatableSchema {
		
		public typealias PropertyIndices = ( idx_id: Int32, idx_listId: Int32, idx_parentId: Int32, idx_nextId: Int32, idx_itemId: Int32, idx_label: Int32, idx_note: Int32 )
		public typealias RecordType = FingerStringDB.ListItem
		public typealias MatchClosureType = ( FingerStringDB.ListItem ) -> Bool
		
		/// The SQL table name associated with the ``ListItem`` record.
		public static let externalName = "list_item"
		
		/// The number of columns the `list_item` table has.
		public static let columnCount : Int32 = 7
		
		/// Information on the records primary key (``ListItem/id``).
		public static let primaryKeyColumn = MappedColumn<FingerStringDB.ListItem, Int>(
			externalName: "id",
			defaultValue: -1,
			keyPath: \FingerStringDB.ListItem.id
		)
		
		/// The SQL used to create the `list_item` table.
		public static let create = 
			#"""
			CREATE TABLE list_item (
				id INTEGER PRIMARY KEY NOT NULL,
				list_id INTEGER NOT NULL,
				parent_id INTEGER,
				next_id INTEGER,
				item_id TEXT NOT NULL,
				label TEXT NOT NULL,
				note TEXT,
				FOREIGN KEY(list_id) REFERENCES task_list(id),
				FOREIGN KEY(parent_id) REFERENCES list_item(id),
				FOREIGN KEY(next_id) REFERENCES list_item(id)
			);
			"""#
		
		/// SQL to `SELECT` all columns of the `list_item` table.
		public static let select = #"SELECT "id", "list_id", "parent_id", "next_id", "item_id", "label", "note" FROM "list_item""#
		
		/// SQL fragment representing all columns.
		public static let selectColumns = #""id", "list_id", "parent_id", "next_id", "item_id", "label", "note""#
		
		/// Index positions of the properties in ``selectColumns``.
		public static let selectColumnIndices : PropertyIndices = ( 0, 1, 2, 3, 4, 5, 6 )
		
		/// SQL to `SELECT` all columns of the `list_item` table using a Swift filter.
		public static let matchSelect = #"SELECT "id", "list_id", "parent_id", "next_id", "item_id", "label", "note" FROM "list_item" WHERE listItems_swift_match("id", "list_id", "parent_id", "next_id", "item_id", "label", "note") != 0"#
		
		/// SQL to `UPDATE` all columns of the `list_item` table.
		public static let update = #"UPDATE "list_item" SET "list_id" = ?, "parent_id" = ?, "next_id" = ?, "item_id" = ?, "label" = ?, "note" = ? WHERE "id" = ?"#
		
		/// Property parameter indicies in the ``update`` SQL
		public static let updateParameterIndices : PropertyIndices = ( 7, 1, 2, 3, 4, 5, 6 )
		
		/// SQL to `INSERT` a record into the `list_item` table.
		public static let insert = #"INSERT INTO "list_item" ( "list_id", "parent_id", "next_id", "item_id", "label", "note" ) VALUES ( ?, ?, ?, ?, ?, ? )"#
		
		/// SQL to `INSERT` a record into the `list_item` table.
		public static let insertReturning = #"INSERT INTO "list_item" ( "list_id", "parent_id", "next_id", "item_id", "label", "note" ) VALUES ( ?, ?, ?, ?, ?, ? ) RETURNING "id", "list_id", "parent_id", "next_id", "item_id", "label", "note""#
		
		/// Property parameter indicies in the ``insert`` SQL
		public static let insertParameterIndices : PropertyIndices = ( -1, 1, 2, 3, 4, 5, 6 )
		
		/// SQL to `DELETE` a record from the `list_item` table.
		public static let delete = #"DELETE FROM "list_item" WHERE "id" = ?"#
		
		/// Property parameter indicies in the ``delete`` SQL
		public static let deleteParameterIndices : PropertyIndices = ( 1, -1, -1, -1, -1, -1, -1 )
		
		/**
		 * Lookup property indices by column name in a statement handle.
		 * 
		 * Properties are ordered in the schema and have a specific index
		 * assigned.
		 * E.g. if the record has two properties, `id` and `name`,
		 * and the query was `SELECT age, list_item_id FROM list_item`,
		 * this would return `( idx_id: 1, idx_name: -1 )`.
		 * Because the `list_item_id` is in the second position and `name`
		 * isn't provided at all.
		 * 
		 * - Parameters:
		 *   - statement: A raw SQLite3 prepared statement handle.
		 * - Returns: The positions of the properties in the prepared statement.
		 */
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
		
		/**
		 * Register the Swift matcher function for the ``ListItem`` record.
		 * 
		 * SQLite Swift matcher functions are used to process `filter` queries
		 * and low-level matching w/o the Lighter library.
		 * 
		 * - Parameters:
		 *   - unsafeDatabaseHandle: SQLite3 database handle.
		 *   - flags: SQLite3 function registration flags, default: `SQLITE_UTF8`
		 *   - matcher: A pointer to the Swift closure used to filter the records.
		 * - Returns: The result code of `sqlite3_create_function`, e.g. `SQLITE_OK`.
		 */
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
					let indices = FingerStringDB.ListItem.Schema.selectColumnIndices
					let record = FingerStringDB.ListItem(
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
				"listItems_swift_match",
				FingerStringDB.ListItem.Schema.columnCount,
				flags,
				UnsafeMutableRawPointer(mutating: matcher),
				dispatch,
				nil,
				nil
			)
		}
		
		/**
		 * Unregister the Swift matcher function for the ``ListItem`` record.
		 * 
		 * SQLite Swift matcher functions are used to process `filter` queries
		 * and low-level matching w/o the Lighter library.
		 * 
		 * - Parameters:
		 *   - unsafeDatabaseHandle: SQLite3 database handle.
		 *   - flags: SQLite3 function registration flags, default: `SQLITE_UTF8`
		 * - Returns: The result code of `sqlite3_create_function`, e.g. `SQLITE_OK`.
		 */
		@inlinable
		@discardableResult
		public static func unregisterSwiftMatcher(
			`in` unsafeDatabaseHandle: OpaquePointer!,
			flags: Int32 = SQLITE_UTF8
		) -> Int32
		{
			sqlite3_create_function(
				unsafeDatabaseHandle,
				"listItems_swift_match",
				FingerStringDB.ListItem.Schema.columnCount,
				flags,
				nil,
				nil,
				nil,
				nil
			)
		}
		
		/// Type information for property ``ListItem/id`` (`id` column).
		public let id = MappedColumn<FingerStringDB.ListItem, Int>(
			externalName: "id",
			defaultValue: -1,
			keyPath: \FingerStringDB.ListItem.id
		)
		
		/// Type information for property ``ListItem/listId`` (`list_id` column).
		public let listId = MappedForeignKey<FingerStringDB.ListItem, Int, MappedColumn<FingerStringDB.TaskList, Int>>(
			externalName: "list_id",
			defaultValue: -1,
			keyPath: \FingerStringDB.ListItem.listId,
			destinationColumn: FingerStringDB.TaskList.schema.id
		)
		
		/// Type information for property ``ListItem/parentId`` (`parent_id` column).
		public let parentId = MappedForeignKey<FingerStringDB.ListItem, Int?, MappedColumn<FingerStringDB.ListItem, Int>>(
			externalName: "parent_id",
			defaultValue: nil,
			keyPath: \FingerStringDB.ListItem.parentId,
			destinationColumn: FingerStringDB.ListItem.schema.id
		)
		
		/// Type information for property ``ListItem/nextId`` (`next_id` column).
		public let nextId = MappedForeignKey<FingerStringDB.ListItem, Int?, MappedColumn<FingerStringDB.ListItem, Int>>(
			externalName: "next_id",
			defaultValue: nil,
			keyPath: \FingerStringDB.ListItem.nextId,
			destinationColumn: FingerStringDB.ListItem.schema.id
		)
		
		/// Type information for property ``ListItem/itemId`` (`item_id` column).
		public let itemId = MappedColumn<FingerStringDB.ListItem, String>(
			externalName: "item_id",
			defaultValue: "",
			keyPath: \FingerStringDB.ListItem.itemId
		)
		
		/// Type information for property ``ListItem/label`` (`label` column).
		public let label = MappedColumn<FingerStringDB.ListItem, String>(
			externalName: "label",
			defaultValue: "",
			keyPath: \FingerStringDB.ListItem.label
		)
		
		/// Type information for property ``ListItem/note`` (`note` column).
		public let note = MappedColumn<FingerStringDB.ListItem, String?>(
			externalName: "note",
			defaultValue: nil,
			keyPath: \FingerStringDB.ListItem.note
		)
		
		#if swift(>=5.7)
		public var _allColumns : [ any SQLColumn ] { [ id, listId, parentId, nextId, itemId, label, note ] }
		#endif // swift(>=5.7)
		
		public init()
		{
		}
	}
	
	/**
	 * Initialize a ``ListItem`` record from a SQLite statement handle.
	 * 
	 * This initializer allows easy setup of a record structure from an
	 * otherwise arbitrarily constructed SQLite prepared statement.
	 * 
	 * If no `indices` are specified, the `Schema/lookupColumnIndices`
	 * function will be used to find the positions of the structure properties
	 * based on their external name.
	 * When looping, it is recommended to do the lookup once, and then
	 * provide the `indices` to the initializer.
	 * 
	 * Required values that are missing in the statement are replaced with
	 * their assigned default values, i.e. this can even be used to perform
	 * partial selects w/ only a minor overhead (the extra space for a
	 * record).
	 * 
	 * Example:
	 * ```swift
	 * var statement : OpaquePointer?
	 * sqlite3_prepare_v2(dbHandle, "SELECT * FROM list_item", -1, &statement, nil)
	 * while sqlite3_step(statement) == SQLITE_ROW {
	 *   let record = ListItem(statement)
	 *   print("Fetched:", record)
	 * }
	 * sqlite3_finalize(statement)
	 * ```
	 * 
	 * - Parameters:
	 *   - statement: Statement handle as returned by `sqlite3_prepare*` functions.
	 *   - indices: Property bindings positions, defaults to `nil` (automatic lookup).
	 */
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
	
	/**
	 * Bind all ``ListItem`` properties to a prepared statement and call a closure.
	 * 
	 * *Important*: The bindings are only valid within the closure being executed!
	 * 
	 * Example:
	 * ```swift
	 * var statement : OpaquePointer?
	 * sqlite3_prepare_v2(
	 *   dbHandle,
	 *   #"UPDATE "list_item" SET "list_id" = ?, "parent_id" = ?, "next_id" = ?, "item_id" = ?, "label" = ?, "note" = ? WHERE "id" = ?"#,
	 *   -1, &statement, nil
	 * )
	 * 
	 * let record = ListItem(id: 1, listId: 2, parentId: 3, nextId: 4, itemId: "Hello", label: "World", note: "Duck")
	 * let ok = record.bind(to: statement, indices: ( 7, 1, 2, 3, 4, 5, 6 )) {
	 *   sqlite3_step(statement) == SQLITE_DONE
	 * }
	 * sqlite3_finalize(statement)
	 * ```
	 * 
	 * - Parameters:
	 *   - statement: A SQLite3 statement handle as returned by the `sqlite3_prepare*` functions.
	 *   - indices: The parameter positions for the bindings.
	 *   - execute: Closure executed with bindings applied, bindings _only_ valid within the call!
	 * - Returns: Returns the result of the closure that is passed in.
	 */
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
	where T == FingerStringDB.TaskList, Ops: SQLDatabaseFetchOperations, Ops.RecordTypes == FingerStringDB.RecordTypes
{
	
	/**
	 * Fetch the ``FingerStringDB/TaskList`` record related to a ``FingerStringDB/ListItem`` (`listId`).
	 * 
	 * This fetches the related ``FingerStringDB/TaskList`` record using the
	 * ``FingerStringDB/ListItem/listId`` property.
	 * 
	 * Example:
	 * ```swift
	 * let sourceRecord  : ListItem = ...
	 * let relatedRecord = try db.taskLists.find(for: sourceRecord)
	 * ```
	 * 
	 * - Parameters:
	 *   - record: The ``ListItem`` record.
	 * - Returns: The related ``FingerStringDB/TaskList`` record (throws if not found).
	 */
	@inlinable
	func find(`for` record: FingerStringDB.ListItem) throws -> FingerStringDB.TaskList
	{
		if let record = try operations[dynamicMember: \.listItems].findTarget(for: \.listId, in: record) {
			return record
		}
		else {
			throw LighterError(.couldNotFindRelationshipTarget, SQLITE_CONSTRAINT)
		}
	}
}

public extension SQLRecordFetchOperations
	where T == FingerStringDB.ListItem, Ops: SQLDatabaseFetchOperations, Ops.RecordTypes == FingerStringDB.RecordTypes
{
	
	/**
	 * Fetch the ``FingerStringDB/ListItem`` record related to itself (`parentId`).
	 * 
	 * This fetches the related ``FingerStringDB/ListItem`` record using the
	 * ``FingerStringDB/ListItem/parentId`` property.
	 * 
	 * Example:
	 * ```swift
	 * let sourceRecord  : ListItem = ...
	 * let relatedRecord = try db.listItems.find(forParent: sourceRecord)
	 * ```
	 * 
	 * - Parameters:
	 *   - record: The ``ListItem`` record.
	 * - Returns: The related ``FingerStringDB/ListItem`` record, or `nil` if not found.
	 */
	@inlinable
	func find(forParent record: FingerStringDB.ListItem)
		throws -> FingerStringDB.ListItem?
	{
		try operations[dynamicMember: \.listItems].findTarget(for: \.parentId, in: record)
	}
	
	/**
	 * Fetch the ``FingerStringDB/ListItem`` record related to itself (`nextId`).
	 * 
	 * This fetches the related ``FingerStringDB/ListItem`` record using the
	 * ``FingerStringDB/ListItem/nextId`` property.
	 * 
	 * Example:
	 * ```swift
	 * let sourceRecord  : ListItem = ...
	 * let relatedRecord = try db.listItems.find(forNext: sourceRecord)
	 * ```
	 * 
	 * - Parameters:
	 *   - record: The ``ListItem`` record.
	 * - Returns: The related ``FingerStringDB/ListItem`` record, or `nil` if not found.
	 */
	@inlinable
	func find(forNext record: FingerStringDB.ListItem)
		throws -> FingerStringDB.ListItem?
	{
		try operations[dynamicMember: \.listItems].findTarget(for: \.nextId, in: record)
	}
	
	/**
	 * Fetches the ``FingerStringDB/ListItem`` records related to a ``FingerStringDB/TaskList`` (`listId`).
	 * 
	 * This fetches the related ``FingerStringDB/TaskList`` records using the
	 * ``FingerStringDB/ListItem/listId`` property.
	 * 
	 * Example:
	 * ```swift
	 * let record         : TaskList = ...
	 * let relatedRecords = try db.listItems.fetch(forList: record)
	 * ```
	 * 
	 * - Parameters:
	 *   - record: The ``FingerStringDB/TaskList`` record.
	 *   - limit: An optional limit of records to fetch (defaults to `nil`).
	 * - Returns: The related ``TaskList`` records.
	 */
	@inlinable
	func fetch(forList record: FingerStringDB.TaskList, limit: Int? = nil)
		throws -> [ FingerStringDB.ListItem ]
	{
		try fetch(for: \.listId, in: record, limit: limit)
	}
	
	/**
	 * Fetches the ``FingerStringDB/ListItem`` records related to itself (`parentId`).
	 * 
	 * This fetches the related ``FingerStringDB/ListItem`` records using the
	 * ``FingerStringDB/ListItem/parentId`` property.
	 * 
	 * Example:
	 * ```swift
	 * let record         : ListItem = ...
	 * let relatedRecords = try db.listItems.fetch(forParent: record)
	 * ```
	 * 
	 * - Parameters:
	 *   - record: The ``FingerStringDB/ListItem`` record.
	 *   - limit: An optional limit of records to fetch (defaults to `nil`).
	 * - Returns: The related ``ListItem`` records.
	 */
	@inlinable
	func fetch(forParent record: FingerStringDB.ListItem, limit: Int? = nil)
		throws -> [ FingerStringDB.ListItem ]
	{
		try fetch(for: \.parentId, in: record, limit: limit)
	}
	
	/**
	 * Fetches the ``FingerStringDB/ListItem`` records related to itself (`nextId`).
	 * 
	 * This fetches the related ``FingerStringDB/ListItem`` records using the
	 * ``FingerStringDB/ListItem/nextId`` property.
	 * 
	 * Example:
	 * ```swift
	 * let record         : ListItem = ...
	 * let relatedRecords = try db.listItems.fetch(forNext: record)
	 * ```
	 * 
	 * - Parameters:
	 *   - record: The ``FingerStringDB/ListItem`` record.
	 *   - limit: An optional limit of records to fetch (defaults to `nil`).
	 * - Returns: The related ``ListItem`` records.
	 */
	@inlinable
	func fetch(forNext record: FingerStringDB.ListItem, limit: Int? = nil)
		throws -> [ FingerStringDB.ListItem ]
	{
		try fetch(for: \.nextId, in: record, limit: limit)
	}
}

#if swift(>=5.5)
#if canImport(_Concurrency)
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public extension SQLRecordFetchOperations
	where T == FingerStringDB.TaskList, Ops: SQLDatabaseFetchOperations & SQLDatabaseAsyncOperations, Ops.RecordTypes == FingerStringDB.RecordTypes
{
	
	/**
	 * Fetch the ``FingerStringDB/TaskList`` record related to a ``FingerStringDB/ListItem`` (`listId`).
	 * 
	 * This fetches the related ``FingerStringDB/TaskList`` record using the
	 * ``FingerStringDB/ListItem/listId`` property.
	 * 
	 * Example:
	 * ```swift
	 * let sourceRecord  : ListItem = ...
	 * let relatedRecord = try await db.taskLists.find(for: sourceRecord)
	 * ```
	 * 
	 * - Parameters:
	 *   - record: The ``ListItem`` record.
	 * - Returns: The related ``FingerStringDB/TaskList`` record (throws if not found).
	 */
	@inlinable
	func find(`for` record: FingerStringDB.ListItem)
		async throws -> FingerStringDB.TaskList
	{
		if let record = try await operations[dynamicMember: \.listItems].findTarget(
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
	where T == FingerStringDB.ListItem, Ops: SQLDatabaseFetchOperations & SQLDatabaseAsyncOperations, Ops.RecordTypes == FingerStringDB.RecordTypes
{
	
	/**
	 * Fetch the ``FingerStringDB/ListItem`` record related to itself (`parentId`).
	 * 
	 * This fetches the related ``FingerStringDB/ListItem`` record using the
	 * ``FingerStringDB/ListItem/parentId`` property.
	 * 
	 * Example:
	 * ```swift
	 * let sourceRecord  : ListItem = ...
	 * let relatedRecord = try await db.listItems.find(forParent: sourceRecord)
	 * ```
	 * 
	 * - Parameters:
	 *   - record: The ``ListItem`` record.
	 * - Returns: The related ``FingerStringDB/ListItem`` record, or `nil` if not found.
	 */
	@inlinable
	func find(forParent record: FingerStringDB.ListItem)
		async throws -> FingerStringDB.ListItem?
	{
		try await operations[dynamicMember: \.listItems].findTarget(
			for: \.parentId,
			in: record
		)
	}
	
	/**
	 * Fetch the ``FingerStringDB/ListItem`` record related to itself (`nextId`).
	 * 
	 * This fetches the related ``FingerStringDB/ListItem`` record using the
	 * ``FingerStringDB/ListItem/nextId`` property.
	 * 
	 * Example:
	 * ```swift
	 * let sourceRecord  : ListItem = ...
	 * let relatedRecord = try await db.listItems.find(forNext: sourceRecord)
	 * ```
	 * 
	 * - Parameters:
	 *   - record: The ``ListItem`` record.
	 * - Returns: The related ``FingerStringDB/ListItem`` record, or `nil` if not found.
	 */
	@inlinable
	func find(forNext record: FingerStringDB.ListItem)
		async throws -> FingerStringDB.ListItem?
	{
		try await operations[dynamicMember: \.listItems].findTarget(
			for: \.nextId,
			in: record
		)
	}
	
	/**
	 * Fetches the ``FingerStringDB/ListItem`` records related to a ``FingerStringDB/TaskList`` (`listId`).
	 * 
	 * This fetches the related ``FingerStringDB/TaskList`` records using the
	 * ``FingerStringDB/ListItem/listId`` property.
	 * 
	 * Example:
	 * ```swift
	 * let record         : TaskList = ...
	 * let relatedRecords = try await db.listItems.fetch(forList: record)
	 * ```
	 * 
	 * - Parameters:
	 *   - record: The ``FingerStringDB/TaskList`` record.
	 *   - limit: An optional limit of records to fetch (defaults to `nil`).
	 * - Returns: The related ``TaskList`` records.
	 */
	@inlinable
	func fetch(forList record: FingerStringDB.TaskList, limit: Int? = nil)
		async throws -> [ FingerStringDB.ListItem ]
	{
		try await fetch(for: \.listId, in: record, limit: limit)
	}
	
	/**
	 * Fetches the ``FingerStringDB/ListItem`` records related to itself (`parentId`).
	 * 
	 * This fetches the related ``FingerStringDB/ListItem`` records using the
	 * ``FingerStringDB/ListItem/parentId`` property.
	 * 
	 * Example:
	 * ```swift
	 * let record         : ListItem = ...
	 * let relatedRecords = try await db.listItems.fetch(forParent: record)
	 * ```
	 * 
	 * - Parameters:
	 *   - record: The ``FingerStringDB/ListItem`` record.
	 *   - limit: An optional limit of records to fetch (defaults to `nil`).
	 * - Returns: The related ``ListItem`` records.
	 */
	@inlinable
	func fetch(forParent record: FingerStringDB.ListItem, limit: Int? = nil)
		async throws -> [ FingerStringDB.ListItem ]
	{
		try await fetch(for: \.parentId, in: record, limit: limit)
	}
	
	/**
	 * Fetches the ``FingerStringDB/ListItem`` records related to itself (`nextId`).
	 * 
	 * This fetches the related ``FingerStringDB/ListItem`` records using the
	 * ``FingerStringDB/ListItem/nextId`` property.
	 * 
	 * Example:
	 * ```swift
	 * let record         : ListItem = ...
	 * let relatedRecords = try await db.listItems.fetch(forNext: record)
	 * ```
	 * 
	 * - Parameters:
	 *   - record: The ``FingerStringDB/ListItem`` record.
	 *   - limit: An optional limit of records to fetch (defaults to `nil`).
	 * - Returns: The related ``ListItem`` records.
	 */
	@inlinable
	func fetch(forNext record: FingerStringDB.ListItem, limit: Int? = nil)
		async throws -> [ FingerStringDB.ListItem ]
	{
		try await fetch(for: \.nextId, in: record, limit: limit)
	}
}
#endif // required canImports
#endif // swift(>=5.5)
