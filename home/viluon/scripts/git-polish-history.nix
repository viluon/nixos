{ pkgs }:
pkgs.writeShellApplication {
  name = "git-polish-history";
  runtimeInputs = with pkgs; [ git fzf gawk coreutils timg ];
  text = ''
    set -euo pipefail

    # Select a commit using fzf
    selected_commit=$(git log --oneline --color=always |
                    fzf --ansi --height 50% --reverse --header="Select commit to polish" --preview="git show --color {1}" |
                    awk '{print $1}')

    # Exit if no commit was selected
    if [ -z "$selected_commit" ]; then
      exit 0
    fi

    # Create temporary files that will be cleaned up on exit
    TEMP_EDITOR=$(mktemp)
    LOG_FILE=$(mktemp)
    FIFO=$(mktemp -u)
    mkfifo "$FIFO"

    # Clean up temporary files on exit
    trap 'rm -f "$TEMP_EDITOR" "$LOG_FILE" "$FIFO"; jobs -p | xargs kill -9 2>/dev/null || true' EXIT

    # Create editor script
    cat > "$TEMP_EDITOR" << 'EOF'
    #!/bin/sh
    cat "$1" > "$1.tmp" && mv "$1.tmp" "$1"
    EOF
    chmod +x "$TEMP_EDITOR"

    # Export the non-interactive editor for all git commands
    export GIT_SEQUENCE_EDITOR="$TEMP_EDITOR"

    # Create a function to check for uncommitted changes
    check_repo_clean() {
      if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "ERROR: You have uncommitted changes. Please commit or stash them first."
        echo "0" > "$FIFO" # Signal error to main process
        exit 1
      fi
    }

    # Function to handle potential conflicts
    handle_conflicts() {
      if git status | grep -q "You are in the middle of a rebase"; then
        {
          echo "ERROR: Rebase conflicts detected. Please resolve conflicts manually."
          echo "Current status:"
          git status 2>&1
        } >> "$LOG_FILE"
        echo "0" > "$FIFO" # Signal error to main process
        return 1
      fi
      return 0
    }

    # Run git operations in background, logging output
    {
      # Check if repository is clean
      check_repo_clean

      # Run the git operations, capturing errors
      if ! git-split-by-file "$selected_commit" >> "$LOG_FILE" 2>&1; then
        echo "ERROR: git-split-by-file failed" >> "$LOG_FILE"
        echo "0" > "$FIFO" # Signal error to main process
        exit 1
      fi

      # Check for conflicts after first step
      handle_conflicts || exit 1

      if ! git rebase --continue >> "$LOG_FILE" 2>&1; then
        echo "ERROR: First rebase failed" >> "$LOG_FILE"
        echo "0" > "$FIFO" # Signal error to main process
        exit 1
      fi

      # Check for conflicts again
      handle_conflicts || exit 1

      if ! git-prepare-fixups >> "$LOG_FILE" 2>&1; then
        echo "ERROR: git-prepare-fixups failed" >> "$LOG_FILE"
        echo "0" > "$FIFO" # Signal error to main process
        exit 1
      fi

      # Check for conflicts after fixups
      handle_conflicts || exit 1

      if ! git rebase --continue >> "$LOG_FILE" 2>&1; then
        echo "ERROR: Second rebase failed" >> "$LOG_FILE"
        echo "0" > "$FIFO" # Signal error to main process
        exit 1
      fi

      echo "SUCCESS: History polished successfully" >> "$LOG_FILE"
      echo "1" > "$FIFO" # Signal success to main process
    } &

    # Run timg in background and capture its PID
    timg --center ~/Pictures/polish-cow.gif &
    TIMG_PID=$!

    # Wait for the git operations to complete by reading from FIFO
    STATUS=$(cat "$FIFO")

    # Kill timg process
    kill $TIMG_PID 2>/dev/null || true

    # Report results based on status
    if [ "$STATUS" = "1" ]; then
      echo -e "\nSuccess! Your git history has been polished."
    else
      echo -e "\nError occurred during history polishing. Check the log for details:"
      cat "$LOG_FILE"
      exit 1
    fi
  '';
}
