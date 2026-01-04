#!/usr/bin/env bash

swift build
BUILDPATH=$(swift build --show-bin-path)

CMD="${BUILDPATH}/fingerstring"

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Clean up old database
rm -f "${HOME}/.config/FingerString/store.db"
mkdir -p ~/.config/FingerString

echo -e "${BLUE}=== FingerString Test Suite ===${NC}\n"

# set -x
# Test 1: Create list
echo -e "${GREEN}1. Create list${NC}"
$CMD list-create tasks --title "My Tasks" --description "Daily tasks"
echo

# Test 2: View empty list
echo -e "${GREEN}2. View empty list${NC}"
$CMD list-view tasks
echo

# Test 3: Add first task
echo -e "${GREEN}3. Add first task${NC}"
TASK1_OUTPUT=$($CMD task-add tasks "Buy groceries")
TASK1_ID=$(echo "$TASK1_OUTPUT" | sed -n 's/^Added task: \[\([^]]*\)\].*/\1/p')
echo "$TASK1_OUTPUT"
echo

# Test 4: Add second task with note
echo -e "${GREEN}4. Add second task with note${NC}"
TASK2_OUTPUT=$($CMD task-add tasks "Write documentation" --note "Update README and API docs")
TASK2_ID=$(echo "$TASK2_OUTPUT" | sed -n 's/^Added task: \[\([^]]*\)\].*/\1/p')
echo "$TASK2_OUTPUT"
echo

# Test 5: View list with tasks
echo -e "${GREEN}5. View list with tasks${NC}"
$CMD list-view tasks
echo

# Test 6: Add subtasks to first task
echo -e "${GREEN}6. Add subtasks to first task${NC}"
SUBTASK1_OUTPUT=$($CMD task-add "$TASK1_ID" "Buy milk")
SUBTASK1_ID=$(echo "$SUBTASK1_OUTPUT" | sed -n 's/^Added task: \[\([^]]*\)\].*/\1/p')
echo "$SUBTASK1_OUTPUT"
echo

# Test 7: Add another subtask
echo -e "${GREEN}7. Add another subtask to first task${NC}"
SUBTASK2_OUTPUT=$($CMD task-add "$TASK1_ID" "Buy bread")
SUBTASK2_ID=$(echo "$SUBTASK2_OUTPUT" | sed -n 's/^Added task: \[\([^]]*\)\].*/\1/p')
echo "$SUBTASK2_OUTPUT"
echo

# Test 8: View list to see subtasks
echo -e "${GREEN}8. View list showing tasks with subtasks${NC}"
$CMD list-view tasks
echo

# Test 9: Complete one subtask
echo -e "${GREEN}9. Complete one subtask (Buy milk)${NC}"
$CMD task-complete "$SUBTASK1_ID"
echo

# Test 10: View list after completing subtask
echo -e "${GREEN}10. View list after completing subtask${NC}"
$CMD list-view tasks
echo

# Test 11: Complete the parent task (Buy groceries)
echo -e "${GREEN}11. Complete parent task (Buy groceries)${NC}"
$CMD task-complete "$TASK1_ID"
echo

# Test 12: View list after completing parent task
echo -e "${GREEN}12. View list after completing parent (incomplete subtask should be gone)${NC}"
$CMD list-view tasks
echo

# Test 13: View list showing all completed tasks
echo -e "${GREEN}13. View list showing all tasks (including completed)${NC}"
$CMD list-view tasks --show-completed-tasks
echo

# Test 14: Create second list
echo -e "${GREEN}14. Create second list${NC}"
$CMD list-create shopping --title "Shopping List"
echo

# Test 15: List all lists
echo -e "${GREEN}15. List all lists${NC}"
$CMD list-all
echo

# Test 16: List all lists with descriptions
echo -e "${GREEN}16. List all lists with descriptions${NC}"
$CMD list-all --include-descriptions
echo

# Test 17: Delete first list
echo -e "${GREEN}17. Delete first list${NC}"
$CMD list-delete tasks --force
echo

# Test 18: Delete second list
echo -e "${GREEN}18. Delete second list${NC}"
$CMD list-delete shopping --force
echo

# Test 19: Verify lists are gone
echo -e "${GREEN}19. Verify all lists deleted${NC}"
$CMD list-all
echo

echo -e "${GREEN}=== All tests completed ===${NC}"
