-- The only model that reads `body` (36 GB). It is built once and stores a few small
-- features per question, so no downstream rebuild ever pays for the text again.
-- Disabled until the feature list is final: adding a feature later means reading `body` again.
-- Routine runs skip it: dbt build --exclude tag:heavy
{{ config(materialized='table', tags=['heavy'], enabled=false) }}

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
        array_length(regexp_extract_all(body, r'<img ')) as image_count
    from questions
)

select * from features
