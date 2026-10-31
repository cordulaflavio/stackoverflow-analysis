# Stack Overflow rules that shape the data

The dump is a snapshot of a living site. Site rules decide what gets recorded, what changes after posting, and what disappears, so they matter as much as the schema. This page lists the rules that affect this analysis and what each one implies.

Rules come from the Stack Overflow Help Center and official Meta discussions (links at the end). Thresholds and policies have changed over time. The historical deletion criteria below describe the rules documented before October 9, 2026; they are relevant to understanding how the September 2022 dump was formed, but should not be treated as a guarantee that every site or period applied identical rules.

## Asking and answering

- A question needs **1 to 5 tags**. Creating a tag that does not exist yet requires reputation (1,500).
- Anyone with an account can answer; a question can have any number of answers.
- **Closed** questions accept no new answers (see below).

**Implications**

- Tags are the *current* tags, not necessarily the ones used at posting time: editors can retag a question later, and tag synonyms are merged into a master tag. Q1 and Q2 group by tags as they stand in the dump.
- 119 questions carry 6 tags (see [data_quality.md](data_quality.md)): legacy rows from before the limit was enforced.

## Accepting an answer

- Only the **asker** can accept an answer, and only **one** answer per question.
- The asker can change or remove the acceptance at any time.
- The asker can accept **their own answer**, but only after **48 hours**, and it earns no reputation.
- Accepting someone else's answer gives +15 reputation to the answerer and +2 to the asker.

**Implications**

- "Accepted" reflects the asker's judgment, not the community's: a high-score answer may be unaccepted and an accepted answer may be weak. The accepted-answer rate measures *whether the asker came back and closed the loop* as much as answer quality.
- `accepted_answer_id` is the *current* state; earlier acceptances that were later removed leave no trace in `posts_questions`.
- Self-accepted answers (11.4% of accepted answers) are a different event (the asker solved their own problem), so whether they count is a metric-definition choice.
- If the asker deletes their account, the question stays but loses its owner (`owner_user_id` is null). An acceptance made before the deletion is kept, which explains why ownerless questions can still have accepted answers.

## Voting and score

- `score` = upvotes − downvotes. Voting up requires 15 reputation, voting down 125.
- Bounties (50–500 reputation offered by any user) promote a question for 7 days to attract answers.

**Implications**

- `score`, `view_count`, `comment_count` and `favorite_count` are **cumulative at the snapshot date**. They are observed *after* the question was posted and are partly caused by answers (an answered question is viewed and voted on more). They cannot be treated as causes of being answered.

## Editing

- Users with 2,000+ reputation edit any post directly; others suggest edits that are reviewed.
- The dump keeps only the **latest** version of `title`, `body` and `tags`, and the date of the last edit (`last_edit_date`). The full revision history is in `post_history`.

**Implications**

- Features derived from `body` (length, code blocks, links) describe the post as it ended up, which may include improvements made *because of* comments or answers. This is a known limitation for Q3.

## Closing and duplicates

- Users with 3,000+ reputation vote to close questions (off-topic, unclear, needs more focus, opinion based, duplicate). After enough votes the question is closed. Gold tag-badge holders and moderators can close a duplicate on their own.
- Closed questions accept no new answers. They can be edited and reopened.
- Duplicate links are stored in `post_links` (`link_type_id = 3`).

**Implications**

- A question closed quickly (often as a duplicate) is unanswered *by design*, not necessarily because nobody could answer it. Closure happens after posting, so it explains unanswered questions but is not a quality signal known at posting time.

## Deletion and the Roomba

The Community user automatically deletes certain questions under specific conditions. These rules are especially important for interpreting historical data because deleted posts are **not included in the public dump**.

**Historical rules documented before October 9, 2026**

The three main automatic deletion routines were:

- **RemoveDeadQuestions (after more than 30 days):**
  - Score of −1 or lower.
  - No answers.
  - Not locked.
  - Not migrated from another site.
  - No active bounty.

- **RemoveAbandonedQuestions (after more than 365 days):**
  - Score of 0 or less, or score of 1 or less if the owner's account was deleted or the user was dissociated from the post.
  - No answers.
  - Not locked.
  - View count less than or equal to the question's age in days multiplied by 1.5.
  - One or zero comments.
  - Not on a Meta site.

- **RemoveAbandonedClosed (more than 9 days after closure):**
  - Not closed as a duplicate.
  - Score of 0 or less.
  - Not locked.
  - No answers with a score greater than 0.
  - No accepted answer.
  - No pending reopen votes.
  - Not edited in the previous 9 days.

These are conditional rules, not automatic deletion based on age or score alone. The routines were evaluated periodically: the historical documentation described the first two checks as weekly and the closed-question check as daily.

**Changes effective October 9, 2026**

Stack Exchange disabled **RemoveDeadQuestions** and **RemoveAbandonedQuestions**. The separate migration-related routines, RemoveRejectedMigrations and RemoveMigrationStubs, were not changed.

**RemoveAbandonedClosed** remains, with revised criteria:
- The waiting period changed from 9 days after closure to 14 days since the last edit.
- Questions must have no non-deleted answers.
- The other eligibility conditions remain, including not being a duplicate, having a score of 0 or less, not being locked, and having no pending reopen votes.
- A question is considered for deletion the first time it crosses the eligibility threshold. It is reconsidered only if it is edited or reopened and closed again.
- The check runs daily.

These changes describe the current policy as of this document's last verification. They do not change the historical rules relevant to the September 2022 snapshot.

**Implications**

- This is a survivorship effect: certain unanswered, low-score questions may have been automatically deleted after meeting the historical criteria. Since deleted posts are absent from the public dump, the remaining questions do not represent every question originally posted.
- The one-year rule could disproportionately remove older unanswered questions with low scores, few views and few comments. This can inflate observed answer rates in older cohorts and complicate comparisons across time.
- The 30-day rule could also remove some unanswered questions with scores of −1 or lower. Its effect depends on the other eligibility conditions, so it is not accurate to say that every negative-score unanswered question disappears after 30 days.
- The closed-question rule affects a different population: questions closed for reasons other than duplication that remain unanswered and meet the other conditions. Such questions may disappear even when their age is less than one year.
- These mechanisms create potential survivorship bias, but the rules alone do not establish how many questions were deleted from the dump or the exact magnitude of the resulting bias. The analysis in [data_quality.md](data_quality.md) examines the observed pattern; comparisons should therefore be interpreted with this limitation in mind.

## Accounts and reputation

- Reputation is earned mostly from upvotes and accepted answers, and unlocks the privileges above.
- `users.reputation` is the value **at the snapshot date**, not at the time a question was posted.

**Implications**

- Current reputation is a biased proxy for the asker's experience at posting time (it includes everything they earned afterwards, possibly from that very question). `badges` has award dates, so "badges earned before the question" is a point-in-time alternative.

## Sources

- Stack Overflow Help Center:
  - [Privileges](https://stackoverflow.com/help/privileges)
  - [Accepting answers](https://stackoverflow.com/help/someone-answers)
  - [Answering your own question](https://stackoverflow.com/help/self-answer)
  - [Closed questions](https://stackoverflow.com/help/closed-questions)
  - [Deleted questions](https://stackoverflow.com/help/deleted-questions)
  - [Tagging](https://stackoverflow.com/help/tagging)
  - [Automatic question deletion](https://stackoverflow.com/help/auto-deleted-questions)
- Official Meta Stack Exchange:
  - [We've reworked automatic question deletion. Let's talk about why](https://meta.stackexchange.com/questions/419988/we-ve-reworked-automatic-question-deletion-let-s-talk-about-why)
  - [How does deleting work? What can cause a post to be deleted, and what does that actually mean?](https://meta.stackexchange.com/questions/5221/how-does-deleting-work-what-can-cause-a-post-to-be-deleted-and-what-does-that)
- Stack Overflow Teams Help Center:
  - [Accepted answer](https://stackoverflowteams.com/help/accepted-answer)
  - [Self answer](https://stackoverflowteams.com/help/self-answer)
  - [Deleted questions](https://stackoverflowteams.com/help/deleted-questions)
