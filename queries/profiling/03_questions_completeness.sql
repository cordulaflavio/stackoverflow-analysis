-- Completeness and uniqueness of the posts_questions columns the analysis may rely on.
-- `title` and `body` are left out on purpose: together they cost ~37 GB to scan.
-- Estimated scan (dry-run): 2.15 GB.
with questions as (
    select
        id,
        post_type_id,
        owner_user_id,
        accepted_answer_id,
        answer_count,
        comment_count,
        favorite_count,
        score,
        view_count,
        tags,
        last_edit_date,
        community_owned_date
    from `bigquery-public-data.stackoverflow.posts_questions`
)

select
    count(*) as questions,
    count(*) - count(distinct id) as duplicate_ids,
    countif(post_type_id != 1) as not_question_post_type,
    countif(owner_user_id is null) as null_owner_user_id,
    countif(accepted_answer_id is null) as null_accepted_answer_id,
    countif(answer_count is null) as null_answer_count,
    countif(comment_count is null) as null_comment_count,
    countif(favorite_count is null) as null_favorite_count,
    countif(score is null) as null_score,
    countif(view_count is null) as null_view_count,
    countif(tags is null or tags = '') as missing_tags,
    countif(last_edit_date is null) as never_edited,
    countif(community_owned_date is not null) as community_owned
from questions
