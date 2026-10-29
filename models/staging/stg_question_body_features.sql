-- The only model that reads `body` (36 GB). It is built once and stores a few small
-- features per question, so no downstream rebuild ever pays for the text again.
-- The feature list was validated on a 2% sample first (queries/exploration/), because adding
-- a feature later means reading `body` again.
-- Build it once with: dbt build --select tag:heavy
-- Routine runs skip it: dbt build --exclude tag:heavy
{{ config(materialized='table', tags=['heavy']) }}

with questions as (
    select
        id as question_id,
        body
    from {{ source('stackoverflow', 'posts_questions') }}
),

features as (
    select
        question_id,
        -- Visible text only: HTML tags are stripped so markup does not inflate the length.
        length(regexp_replace(body, r'<[^>]+>', '')) as body_length,
        -- Code blocks render as <pre><code>; inline <code> alone is not a block.
        array_length(regexp_extract_all(body, r'<pre[ >]')) as code_block_count,
        array_length(regexp_extract_all(body, r'<a ')) as link_count,
        array_length(regexp_extract_all(body, r'<img ')) as image_count,
        -- The asker reports an error: the words are searched outside code blocks only, because
        -- inside code they are mostly identifiers and strings (catch blocks, "error.jsp").
        -- A 20-question check on a 2% sample put precision at about 90% (60-75% on the whole body).
        regexp_contains(
            regexp_replace(body, r'(?s)<pre.*?</pre>', ' '),
            r'(?i)\b(error|exception|traceback)'
        ) as has_error_report
    from questions
)

select * from features
