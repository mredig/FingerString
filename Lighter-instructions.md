# How to Use Lighter with FingerString

This document explains how Lighter was integrated into the FingerString project.

## What is Lighter?

Lighter is a Swift code generation tool that creates type-safe SQLite database accessors from SQL schemas. It's not an ORM—instead, it generates Swift code that directly uses SQLite3 bindings with full type safety and minimal overhead.

## The Workflow

### 1. Create Your SQL Schema

Create a `.sql` file with your database schema in `Sources/FingerString/`. For example: `FingerString.sql`

```sql
CREATE TABLE task_lists (
	id INTEGER PRIMARY KEY NOT NULL,
	slug TEXT UNIQUE NOT NULL,
	title TEXT,
	description TEXT,
	first_item_id INTEGER
);

CREATE TABLE list_items (
	id INTEGER PRIMARY KEY NOT NULL,
	list_id INTEGER NOT NULL,
	parent_id INTEGER,
	next_id INTEGER,
	item_id TEXT NOT NULL,
	label TEXT NOT NULL,
	note TEXT,
	FOREIGN KEY(list_id) REFERENCES task_lists(id),
	FOREIGN KEY(parent_id) REFERENCES list_items(id),
	FOREIGN KEY(next_id) REFERENCES list_items(id)
);
```

### 2. Create a SQLite Database from Your Schema

Use the sqlite3 command-line tool to create a database file from your SQL schema:

```bash
cd Sources/FingerString
sqlite3 FingerString.sqlite < FingerString.sql
```

This creates an empty `FingerString.sqlite` file with your schema.

### 3. Generate Swift Code Using sqlite2swift

Lighter provides a command-line tool called `sqlite2swift` that generates Swift code from a SQLite database. 

First, create a minimal config file (can be empty JSON):

```bash
echo '{}' > lighter.json
```

Then run the code generator:

```bash
swift run -c release sqlite2swift lighter.json FingerString FingerString.sqlite FingerString-DB.swift
```

This generates `FingerString-DB.swift` containing:
- `FingerString` struct (the database)
- `TaskLists` and `ListItems` structs (your model types)
- Helper functions like `sqlite3_create_fingerstring()`
- Full CRUD operations with async/await support

### 4. Clean Up Temporary Files

You can delete the temporary files used for generation:

```bash
rm FingerString.sqlite lighter.json FingerString.sql
```

The generated Swift code contains all the information needed—no database file needs to be committed.

### 5. Use the Generated Code in Your Application

The generated `FingerString` database type can be initialized with just a path:

```swift
let db = FingerString(url: databaseURL)
```

If the database doesn't exist, it will be created automatically with the schema defined in your SQL file (stored in the generated code as `FingerString.creationSQL`).

### 6. Update Package.swift

Ensure your `Package.swift` includes Lighter as a dependency:

```swift
dependencies: [
	.package(url: "https://github.com/Lighter-swift/Lighter.git", from: "1.4.8"),
	// ... other dependencies
],
targets: [
	.target(
		name: "FingerString",
		dependencies: [
			.product(name: "Lighter", package: "Lighter"),
		],
		// ... other configuration
	),
	// ... other targets
]
```

Note: You don't need build plugins or code generation plugins—just the Lighter product dependency.

## Generated Code Structure

The generated file includes:

- **Database struct**: `FingerString` - the main database type implementing `SQLDatabase` and `SQLDatabaseAsyncChangeOperations`
- **Model structs**: `TaskLists`, `ListItems` - your table models, implementing `SQLKeyedTableRecord`
- **Helper functions**: `sqlite3_create_fingerstring()`, `sqlite3_task_lists_insert()`, etc.
- **Relationship helpers**: Methods to fetch related records
- **Schema information**: SQL statements, column indices, and binding code

## Using the Generated Database

```swift
// Initialize
let db = FingerString(url: databasePath)

// Fetch records (async)
let lists = try await db.taskLists.fetch()
let list = try await db.taskLists.fetch(where: { $0.slug == "my-list" }).first

// Insert (requires transaction)
try await db.transaction { tx in
	try await tx.taskLists.insert(myRecord)
}

// Update
try await db.transaction { tx in
	try await tx.taskLists.update(modifiedRecord)
}

// Delete
try await db.transaction { tx in
	try await tx.taskLists.delete(myRecord)
}
```

## Key Advantages

1. **No runtime schema**: The schema is embedded in the generated code as creation SQL
2. **No database file needed at build time**: You only need the SQL schema
3. **Type-safe**: Full Swift type checking on all database operations
4. **Async/await support**: Modern Swift concurrency built-in
5. **Minimal dependencies**: Just SQLite3 (included with macOS)
6. **One-time generation**: Generate once, commit the code, no build-time plugins needed

## When to Regenerate

If you need to change your database schema:

1. Update your `FingerString.sql` file
2. Run the generation steps again (steps 2-3 above)
3. The new `FingerString-DB.swift` file will have all updated models and operations

## References

- [Lighter GitHub](https://github.com/Lighter-swift/Lighter)
- [Lighter Documentation](https://lighter-swift.github.io/)
