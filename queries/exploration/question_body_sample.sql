-- 2% random sample of questions, used to validate the body features (regex precision,
-- prevalence) before body is read in full by stg_question_body_features.
--
-- Why a hash of the id instead of rand(): the sample is reproducible, so anyone re-running
-- this query gets the same questions. Each question has an independent 1-in-50 chance, so
-- every year (2022 included) is represented at about 2%.
--
-- Cost: about 38.6 GB. BigQuery bills the full `body` column even though only 2% of the rows
-- are kept; TABLESAMPLE would cost 0.76 GB but samples storage blocks, which does not
-- guarantee each year is represented in proportion.
with sampled_questions as (
    select
        id as question_id,
        extract(year from creation_date) as creation_year,
        title,
        body,
        tags,
        answer_count,
        accepted_answer_id
    from `bigquery-public-data.stackoverflow.posts_questions`
    where mod(abs(farm_fingerprint(cast(id as string))), 50) = 0
)

select * from sampled_questions
