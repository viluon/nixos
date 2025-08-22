{ pkgs }:
pkgs.writeShellApplication {
  name = "git-prepare-fixups";
  runtimeInputs = with pkgs; [ git gnused gawk coreutils ];
  text = ''
    set -euxo pipefail

    # Get current branch
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

    # Determine default branch (typically main or master)
    DEFAULT_BRANCH=$(git remote show origin | grep "HEAD branch" | sed 's/.*: //')

    # Find the branch-off point (where feature branch diverged from default branch)
    BRANCH_OFF_POINT=$(git merge-base "$DEFAULT_BRANCH" "$CURRENT_BRANCH")

    # Create a temporary file for the rebase script
    TEMP_SCRIPT=$(mktemp)
    trap 'rm -f "$TEMP_SCRIPT"' EXIT

    # Collect information about commits since branch-off point, oldest to newest
    COMMITS=$(git log --reverse --format='%H' "''${BRANCH_OFF_POINT}..''${CURRENT_BRANCH}")

    # Build mapping of files to their last non-wip modifying commit
    declare -A file_to_commit
    declare -A is_wip_commit
    declare -A commit_to_files

    # First pass: identify wip commits and build file mapping
    for COMMIT in $COMMITS; do
      COMMIT_MSG=$(git log -1 --pretty=format:'%s' "$COMMIT")

      # Store all files modified by this commit
      FILES=$(git diff-tree --no-commit-id --name-only -r "$COMMIT")
      commit_to_files["$COMMIT"]="$FILES"

      # Check if this is a wip commit
      if [[ "$COMMIT_MSG" =~ ^wip: ]]; then
        is_wip_commit["$COMMIT"]=1
        # Verify wip commit only changes one file
        if [[ $(echo "$FILES" | wc -l) -ne 1 ]]; then
          echo "Error: WIP commit $COMMIT changes multiple files, expected only one" >&2
          exit 1
        fi
      else
        # Only update file mapping with non-wip commits
        for FILE in $FILES; do
          file_to_commit["$FILE"]="$COMMIT"
        done
      fi
    done

    # Find the oldest commit that needs modification
    OLDEST_COMMIT_TO_EDIT=""

    # We need to preserve the correct order of commits while ensuring
    # fixups appear after their targets in the rebase plan
    declare -a rebase_plan

    # First, add all non-wip commits to the plan in their original order
    for COMMIT in $COMMITS; do
      if [[ -z "''${is_wip_commit[$COMMIT]:-}" ]]; then
        COMMIT_MSG=$(git log -1 --pretty=format:'%s' "$COMMIT")
        SHORT_HASH=$(git rev-parse --short "$COMMIT")
        rebase_plan+=("pick $SHORT_HASH $COMMIT_MSG")
      fi
    done

    # Now process wip commits - they need to become fixups after their targets
    for COMMIT in $COMMITS; do
      if [[ -n "''${is_wip_commit[$COMMIT]:-}" ]]; then
        COMMIT_MSG=$(git log -1 --pretty=format:'%s' "$COMMIT")
        SHORT_HASH=$(git rev-parse --short "$COMMIT")
        CHANGED_FILE=$(echo "''${commit_to_files[$COMMIT]}" | head -1)
        TARGET_COMMIT="''${file_to_commit[$CHANGED_FILE]:-}"

        if [[ -n "$TARGET_COMMIT" ]]; then
          # Track the oldest commit we need to edit
          if [[ -z "$OLDEST_COMMIT_TO_EDIT" ]] || [[ $(git rev-list --count "$TARGET_COMMIT".."$OLDEST_COMMIT_TO_EDIT") -gt 0 ]]; then
            OLDEST_COMMIT_TO_EDIT="$TARGET_COMMIT"
          fi

          # Find the position of the target commit in the rebase plan
          TARGET_SHORT=$(git rev-parse --short "$TARGET_COMMIT")
          position=0
          for ((i=0; i<''${#rebase_plan[@]}; i++)); do
            if [[ "''${rebase_plan[$i]}" == "pick $TARGET_SHORT"* ]]; then
              position=$((i+1))
              break
            fi
          done

          # Insert the fixup right after its target
          if [[ $position -gt 0 ]]; then
            rebase_plan=("''${rebase_plan[@]:0:$position}" "fixup $SHORT_HASH $COMMIT_MSG" "''${rebase_plan[@]:$position}")
          else
            # Fallback if target not found in plan
            rebase_plan+=("pick $SHORT_HASH $COMMIT_MSG # Warning: Target commit not found for $CHANGED_FILE")
          fi
        else
          # No target found for this file, use regular pick as fallback
          rebase_plan+=("pick $SHORT_HASH $COMMIT_MSG # Warning: No previous commit found for $CHANGED_FILE")
        fi
      fi
    done

    # Write the rebase plan to the temp file
    printf "%s\n" "''${rebase_plan[@]}" > "$TEMP_SCRIPT"

    if [[ -z "$OLDEST_COMMIT_TO_EDIT" ]]; then
      echo "No wip commits found that need fixups. Exiting."
      exit 0
    fi

    # Start interactive rebase
    echo "Prepared fixups for 'wip:' commits. Review and save to continue..."
    GIT_SEQUENCE_EDITOR="cp $TEMP_SCRIPT" git rebase -i "''${OLDEST_COMMIT_TO_EDIT}^"

    echo "Rebase prepared. Review the plan and continue with 'git rebase --continue'"
  '';
}
