# Stack Overflow rules that shape the data

The dump is a snapshot of a living site. Site rules decide what gets recorded, what changes after posting
and what disappears, so they matter as much as the schema. This page lists the rules that affect this
analysis and what each one implies.

Rules come from the Stack Overflow Help Center (links at the end). Thresholds have changed over the
years, and since 2025 they can be tuned per site, so the exact values below are indicative rather than
guaranteed for every year in the data.

## Asking and answering

- A question needs **1 to 5 tags**. Creating a tag that does not exist yet requires reputation
  (1,500).
- Anyone with an account can answer; a question can have any number of answers.
- **Closed** questions accept no new answers (see below).

**Implications**
- Tags are the *current* tags, not the ones used at posting time: editors can retag a question later,
  and tag synonyms are merged into a master tag. P1 and P2 group by tags as they stand in the dump.
- 119 questions carry 6 tags (see [data_quality.md](data_quality.md)): legacy rows from before the
  limit was enforced.

## Accepting an answer

- Only the **asker** can accept an answer, and only **one** answer per question.
- The asker can change or remove the acceptance at any time.
- The asker can accept **their own answer**, but only after **48 hours**, and it earns no reputation.
- Accepting someone else's answer gives +15 reputation to the answerer and +2 to the asker.

**Implications**
- "Accepted" reflects the asker's judgment, not the community's: a high-score answer may be unaccepted
  and an accepted answer may be weak. The accepted-answer rate measures *whether the asker came back
  and closed the loop* as much as answer quality.
- `accepted_answer_id` is the *current* state; earlier acceptances that were later removed leave no
  trace in `posts_questions`.
- Self-accepted answers (11.4% of accepted answers) are a different event (the asker solved their
  own problem), so whether they count is a metric-definition choice.
- If the asker deletes their account, the question stays but loses its owner (`owner_user_id` is
  null). An acceptance made before the deletion is kept, which explains why ownerless questions still
  have accepted answers.

## Voting and score

- `score` = upvotes − downvotes. Voting up requires 15 reputation, voting down 125.
- Bounties (50–500 reputation offered by any user) promote a question for 7 days to attract answers.

**Implications**
- `score`, `view_count`, `comment_count` and `favorite_count` are **cumulative at the snapshot date**.
  They are observed *after* the question was posted and are partly caused by answers (an answered
  question is viewed and voted on more). They cannot be treated as causes of being answered.

## Editing

- Users with 2,000+ reputation edit any post directly; others suggest edits that are reviewed.
- The dump keeps only the **latest** version of `title`, `body` and `tags`, and the date of the last
  edit (`last_edit_date`). The full revision history is in `post_history`.

**Implications**
- Features derived from `body` (length, code blocks, links) describe the post as it ended up, which
  may include improvements made *because* of comments or answers. This is a known limitation for P3.

## Closing and duplicates

- Users with 3,000+ reputation vote to close questions (off-topic, unclear, needs more focus, opinion
  based, duplicate). After enough votes the question is closed. Gold tag-badge holders and moderators
  can close a duplicate on their own.
- Closed questions accept no new answers. They can be edited and reopened.
- Duplicate links are stored in `post_links` (`link_type_id = 3`).

**Implications**
- A question closed quickly (often as a duplicate) is unanswered *by design*, not because nobody could
  answer it. Closure happens after posting, so it explains unanswered questions but is not a quality
  "known at posting time".

## Deletion

- Owners, users with 10,000+ reputation (voting on closed questions) and moderators can delete posts.
- The **Community user** deletes abandoned questions automatically (the "Roomba"). The main rules:
  - **after ~1 year**: no answers, score 0 or less (or 1 with a deleted owner), not locked, few views
    and comments;
  - **after 30 days**: score −1 or less and no answers;
  - **after 9 days closed**: closed (not as a duplicate), score 0 or less, no positively scored or
    accepted answer.
- Deleted posts are **not in the public dump**.

**Implications**
- This is the survivorship effect measured in [data_quality.md](data_quality.md): unanswered,
  low-score questions older than about a year are missing, while recent ones are still present.
  Answer rates are therefore inflated for older periods, and comparisons across the ~2021-09 boundary
  are biased.
- Negative-score unanswered questions disappear after only 30 days, so they are under-represented
  in every period except the last month of the dump.

## Accounts and reputation

- Reputation is earned mostly from upvotes and accepted answers, and unlocks the privileges above.
- `users.reputation` is the value **at the snapshot date**, not at the time a question was posted.

**Implications**
- Current reputation is a biased proxy for the asker's experience at posting time (it includes
  everything they earned afterwards, possibly from that very question). `badges` has award dates, so
  "badges earned before the question" is a point-in-time alternative.

## Sources

- Stack Overflow Help Center: [privileges](https://stackoverflow.com/help/privileges),
  [accepting answers](https://stackoverflow.com/help/someone-answers),
  [answering your own question](https://stackoverflow.com/help/self-answer),
  [closed questions](https://stackoverflow.com/help/closed-questions),
  [deleted questions](https://stackoverflow.com/help/deleted-questions),
  [tagging](https://stackoverflow.com/help/tagging).
- The same pages on the Stack Overflow Teams help center:
  [accepted answer](https://stackoverflowteams.com/help/accepted-answer),
  [self answer](https://stackoverflowteams.com/help/self-answer),
  [deleted questions](https://stackoverflowteams.com/help/deleted-questions).
