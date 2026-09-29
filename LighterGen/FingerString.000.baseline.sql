PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

CREATE TABLE task_list (
	id INTEGER PRIMARY KEY NOT NULL,
	slug TEXT UNIQUE NOT NULL,
	title TEXT,
	description TEXT,
	first_task_id INTEGER REFERENCES task_item(id) ON DELETE SET NULL
);

CREATE TABLE task_item (
	id INTEGER PRIMARY KEY NOT NULL,
	list_id INTEGER NOT NULL REFERENCES task_list(id) ON DELETE CASCADE,
	prev_id INTEGER REFERENCES task_item(id),
	next_id INTEGER REFERENCES task_item(id),
	first_subtask_id INTEGER REFERENCES task_item(id),
	subtask_parent_id INTEGER REFERENCES task_item(id) ON DELETE CASCADE,
	item_hash_id TEXT UNIQUE NOT NULL,
	is_complete BOOL NOT NULL,
	label TEXT NOT NULL,
	note TEXT
);
