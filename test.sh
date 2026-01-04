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
TASK1_ID=$(echo "$TASK1_OUTPUT" | sed -n 's/.*\[\([^]]*\)\].*/\1/p')
echo "$TASK1_OUTPUT"
echo

# Test 4: Add second task with note
echo -e "${GREEN}4. Add second task with note${NC}"
TASK2_OUTPUT=$($CMD task-add tasks "Write documentation" --note "Update README and API docs")
TASK2_ID=$(echo "$TASK2_OUTPUT" | sed -n 's/.*\[\([^]]*\)\].*/\1/p')
echo "$TASK2_OUTPUT"
echo

# Test 5: View list with tasks
echo -e "${GREEN}5. View list with tasks${NC}"
$CMD list-view tasks
echo

# Test 6: Complete a task
echo -e "${GREEN}6. Complete first task${NC}"
$CMD task-complete "$TASK1_ID"
echo

# Test 7: View list with tasks (after completing one)
echo -e "${GREEN}7. View list with tasks (one completed)${NC}"
$CMD list-view tasks
echo

# Test 8: View list showing completed tasks
echo -e "${GREEN}8. View list showing all tasks (including completed)${NC}"
$CMD list-view tasks --show-completed-tasks
echo

# Test 9: Create second list
echo -e "${GREEN}9. Create second list${NC}"
$CMD list-create shopping --title "Shopping List"
echo

# Test 10: List all lists
echo -e "${GREEN}10. List all lists${NC}"
$CMD list-all
echo

# Test 11: List all lists with descriptions
echo -e "${GREEN}11. List all lists with descriptions${NC}"
$CMD list-all --include-descriptions
echo

# Test 12: Delete first list
echo -e "${GREEN}12. Delete first list${NC}"
$CMD list-delete tasks --force
echo

# Test 13: Delete second list
echo -e "${GREEN}13. Delete second list${NC}"
$CMD list-delete shopping --force
echo

# Test 14: Verify lists are gone
echo -e "${GREEN}14. Verify all lists deleted${NC}"
$CMD list-all
echo

echo -e "${GREEN}=== All tests completed ===${NC}"
