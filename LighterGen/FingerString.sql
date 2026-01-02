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
