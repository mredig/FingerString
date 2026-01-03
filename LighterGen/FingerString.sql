CREATE TABLE task_list (
	id INTEGER PRIMARY KEY NOT NULL,
	slug TEXT UNIQUE NOT NULL,
	title TEXT,
	description TEXT,
	first_task_id INTEGER
);

CREATE TABLE task_item (
	id INTEGER PRIMARY KEY NOT NULL,
	list_id INTEGER NOT NULL,
	parent_id INTEGER,
	next_id INTEGER,
	item_id TEXT UNIQUE NOT NULL,
	is_complete BOOL NOT NULL,
	label TEXT NOT NULL,
	note TEXT,
	FOREIGN KEY(list_id) REFERENCES task_list(id),
	FOREIGN KEY(parent_id) REFERENCES task_item(id),
	FOREIGN KEY(next_id) REFERENCES task_item(id)
);
