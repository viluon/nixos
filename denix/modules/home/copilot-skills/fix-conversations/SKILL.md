---
name: fix-conversations
description: >
  Reply "fixed" on each review conversation of the PR for the current branch.
  Link "fixed" to the force-push that fixed the conversation.
  Use when the user types /fix-conversations.
---

Post one reply on each review conversation that a code change fixed.
The reply text is `[fixed](<compare-url>)`.
The `<compare-url>` is the force-push that fixed the conversation.
Do not post other text.
Do not resolve or unresolve conversations.

## 1. Get the data

1. Run `gh pr view --json number,url,headRefName` in the repository.
2. Get `HOST`, `OWNER`, `REPO` and `NUMBER` from the URL.
3. For GitHub Enterprise Server, set `GH_HOST=<host>` before each `gh` command.
4. Get your login with `gh api user --jq .login`.
5. Send one GraphQL query for the PR. Get these fields:
   - `timelineItems(itemTypes:[HEAD_REF_FORCE_PUSHED_EVENT], last:100) { nodes { ... on HeadRefForcePushedEvent { createdAt actor{login} beforeCommit{oid} afterCommit{oid} } } }`
   - `reviewThreads(first:100) { nodes { id isResolved path line originalLine comments(first:20) { nodes { author{login} createdAt body diffHunk originalCommit{oid} } } } }`
6. Select the conversations to reply to:
   - Another user wrote the first comment.
   - You did not reply with a compare link before.
   - If the user gave a reviewer name, use only the conversations of that reviewer.
7. Select the force-pushes to examine:
   - You did the force-push.
   - The force-push occurred after the first comment of the conversation.
8. Make sure that each before and after commit is available. Use `git cat-file -e <oid>`.
9. If a commit is not available, run `git fetch origin <oid>`.

## 2. Find the force-push that fixed each conversation

Make sure that each result is correct.

1. Find the line that the comment is about. It is the last line of `diffHunk`.
2. Read that line at `originalCommit`.
3. Find what the reviewer asked for.
4. Look in the local session history (`session_store_sql`). Find how you fixed the conversation.
5. For each force-push, get the diff of the related files: `git diff <before> <after> -- <paths>`.
6. If a diff has only changes from the base branch, the force-push is a rebase. Ignore it.
7. For each conversation, select text patterns:
   - A pattern of the old code. The fix removes it.
   - A pattern of the new code. The fix adds it.
8. Count each pattern in each force-push tree. Use `git grep -c`.
9. Find the first force-push where the old pattern is gone and the new pattern is present.
10. Read the diff of that force-push. Make sure that it contains the fix.
11. If the fix is in more than one force-push, use the last one. Tell the user.
12. If no code change fixed a conversation, do not reply to it. Tell the user.

## 3. Get approval from the user

1. Show the user a Markdown table with these columns:
   - Start of the comment.
   - File path.
   - Force-push (short before and after hashes, and the time).
   - Evidence.
2. Use `ask_user` to get approval. Write the question in plain text, without Markdown.
3. Do not post a reply before the user approves.

## 4. Post the replies one at a time

**CAUTION:** Do not post replies in parallel.
Parallel replies can stay PENDING in a review that GitHub already submitted.

1. Post each reply with this command:

   ```sh
   gh api graphql \
     -f query='mutation($t:ID!,$b:String!){addPullRequestReviewThreadReply(input:{pullRequestReviewThreadId:$t,body:$b}){comment{databaseId state url}}}' \
     -f t="$THREAD_ID" -f b="[fixed](https://$HOST/$OWNER/$REPO/compare/$BEFORE..$AFTER)"
   ```

2. Use the full 40-character hashes in the URL.
3. Make sure that each reply has the state `SUBMITTED`.
4. If a reply has the state `PENDING`, find your pending review with `reviews(states:[PENDING])`.
5. Submit that review with `submitPullRequestReview(event:COMMENT)`.
6. If GitHub already submitted the review, the submit fails. Then:
   1. Delete the reply with `deletePullRequestReviewComment`.
   2. Post the reply again.

## 5. Do a check of the result

1. Send the GraphQL query for the conversations again.
2. For each conversation, show:
   - The resolution state.
   - The state of the reply.
   - The before and after hashes from the reply link.
3. Make sure that each reply has the state `SUBMITTED`.
4. Make sure that each reply links to the correct force-push.
5. Show the final table to the user.
