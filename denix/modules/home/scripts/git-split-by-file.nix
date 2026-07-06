{ pkgs }:
pkgs.writeShellApplication {
  name = "git-split-by-file";
  runtimeInputs = with pkgs; [ git gnused coreutils ];
  text = ''
    set -euxo pipefail

    # Check that a reference was provided
    if [ "$#" -lt 1 ]; then
      echo "Usage: $0 <commit-ref>"
      exit 1
    fi

    # Get the git repository root directory
    GIT_ROOT=$(git rev-parse --show-toplevel)

    COMMIT_REF="$1"
    PARENT_COMMIT="$COMMIT_REF^"
    COMMIT_MSG=$(git log -1 --format=%B "$COMMIT_REF")

    # Get the files changed in the commit with full paths
    FILES=$(git diff-tree --no-commit-id --name-only -r "$COMMIT_REF")

    # Create a temporary script to modify the rebase todo
    TEMP_SCRIPT=$(mktemp)
    trap 'rm -f "$TEMP_SCRIPT"' EXIT

    # Function to handle the actual splitting
    split_commit() {
      # Reset the commit but keep changes staged
      git reset --soft HEAD^

      # Unstage all files
      git restore --staged "$GIT_ROOT"

      # For each file, stage it and commit separately
      for FILE in $FILES; do
        # Use the full path from the repository root
        FULL_PATH="$GIT_ROOT/$FILE"
        if [ -f "$FULL_PATH" ] || [ -d "$FULL_PATH" ]; then
          git add -- "$FULL_PATH"
          git commit -m "$COMMIT_MSG ($FILE)"
        fi
      done
    }

    # Create the rebase script
    cat > "$TEMP_SCRIPT" << 'EOF'
    #!/usr/bin/env bash
    set -eu
    sed -i '1s/pick/edit/' "$1"
    EOF
    chmod +x "$TEMP_SCRIPT"

    # Start interactive rebase - this works from any directory
    GIT_SEQUENCE_EDITOR="$TEMP_SCRIPT" git rebase -i "$PARENT_COMMIT"

    # Split the commit
    split_commit

    # Continue with the rebase to let the user edit if needed
    git rebase --edit-todo
    echo "Review the rebase plan and then continue with 'git rebase --continue'"
  '';
}
