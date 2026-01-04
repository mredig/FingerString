#!/usr/bin/env bash

set -e

BUILDPATH=$(swift build --show-bin-path)
CMD="${BUILDPATH}/fingerstring"
DB="${HOME}/.config/FingerString/store.db"

# Clean up old database
rm -f "$DB"
mkdir -p ~/.config/FingerString

echo "=== Verifying Cascading Deletes ==="
echo

# Create a list with tasks
echo "1. Creating list and adding tasks..."
$CMD list-create tasks --title "Test Tasks"
TASK1_OUTPUT=$($CMD task-add tasks "Task 1")
TASK2_OUTPUT=$($CMD task-add tasks "Task 2")
TASK1_ID=$(echo "$TASK1_OUTPUT" | sed -n 's/.*\[\([^]]*\)\].*/\1/p')
TASK2_ID=$(echo "$TASK2_OUTPUT" | sed -n 's/.*\[\([^]]*\)\].*/\1/p')
echo "  Task 1 ID: $TASK1_ID"
echo "  Task 2 ID: $TASK2_ID"
echo

# Check database before deletion
echo "2. Checking database before deletion..."
BEFORE=$(sqlite3 "$DB" "SELECT COUNT(*) FROM task_item;")
echo "  Tasks in database: $BEFORE"
echo

# Delete the list
echo "3. Deleting the list..."
$CMD list-delete tasks --force
echo

# Check database after deletion
echo "4. Checking database after deletion..."
AFTER=$(sqlite3 "$DB" "SELECT COUNT(*) FROM task_item;")
echo "  Tasks in database: $AFTER"
echo

if [ "$AFTER" -eq 0 ]; then
  echo "✓ SUCCESS: Cascading delete worked! Tasks were deleted when list was deleted."
else
  echo "✗ FAILURE: Cascading delete did NOT work. Tasks still exist in database."
  echo "  Remaining tasks:"
  sqlite3 "$DB" "SELECT id, label FROM task_item;"
  exit 1
fi
