# FingerString

A lightweight Swift CLI tool for task list management with support for subtasks, notes, and list organization. All data is stored locally in SQLite (`~/.config/FingerString/store.db` by default).

## TLDR - Quick Start

**Install via Homebrew:**
Use brew to get the [pizza tool package](https://github.com/mredig/homebrew-pizza-mcp-tools), containing this (and other tools).

```bash
brew tap mredig/pizza-mcp-tools
brew update
brew install fingerstring
```

**Or build from source:**
```bash
git clone https://github.com/mredig/FingerString.git
cd FingerString
swift build -c release
```

**Then use it:**
```bash
fingerstring list-create tasks --title "My Tasks"
fingerstring task-add tasks "Buy groceries"
fingerstring list-view tasks
```

## Bash Completion Setup

Enable tab completion for commands, subcommands, and arguments.

**If you have `bash-completion` installed:**
```bash
mkdir -p ~/.local/share/bash-completion/completions
fingerstring --generate-completion-script bash > ~/.local/share/bash-completion/completions/fingerstring
```

**If you don't have `bash-completion`:**
```bash
# Generate the completion script in the standard location
mkdir -p ~/.local/share/bash-completion/completions
fingerstring --generate-completion-script bash > ~/.local/share/bash-completion/completions/fingerstring

# Add to your shell profile (choose the file that exists on your system)
echo 'source ~/.local/share/bash-completion/completions/fingerstring' >> ~/.bash_profile  # or ~/.bashrc
```

Then restart your shell or run `source ~/.bash_profile` (or `~/.bashrc`).

**For other shells (zsh, fish):** See the [Swift Argument Parser documentation](https://apple.github.io/swift-argument-parser/documentation/argumentparser/installingcompletionscripts#Installing-Zsh-Completions).

## Available Commands

### List Management
- **`list-create`** - Create a new task list
- **`list-view`** - View a list with all tasks and subtasks
- **`list-delete`** - Delete a list
- **`list-all`** - Show all lists

### Task Management
- **`task-add`** - Add a task to a list or as a subtask
- **`task-view`** - View task details with subtasks
- **`task-edit`** - Edit task label or note
- **`task-delete`** - Delete a task
- **`task-complete`** - Mark task complete/incomplete

## Usage Examples

**Create a list:**
```bash
fingerstring list-create work --title "Work Tasks" --description "Project tasks"
```

**Add a task:**
```bash
fingerstring task-add work "Implement authentication" --note "Use OAuth provider"
```

**Add a subtask:**
```bash
fingerstring task-add abc12 "Setup OAuth provider"
```

**View task with subtasks:**
```bash
fingerstring task-view abc12 --show-completed
```

**Edit a task:**
```bash
fingerstring task-edit abc12 --label "Updated label"
fingerstring task-edit abc12 --note "Updated note"
```

**Mark complete:**
```bash
fingerstring task-complete abc12
```

**Mark incomplete:**
```bash
fingerstring task-complete abc12 --mark false
```

**View all tasks in a list:**
```bash
fingerstring list-view work
```

## Requirements

- Swift 6.0+ (development)
- macOS 13.0+

## Testing

```bash
./test.sh
```

## Related Projects

- **[MCP-FingerString](https://github.com/mredig/MCP-FingerString)** - MCP server for FingerString, use this to integrate task management with Claude or Zed

## Resources

- [MCP Specification](https://spec.modelcontextprotocol.io/)
- [MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk)
- [Homebrew Package](https://github.com/mredig/homebrew-pizza-mcp-tools)
