-- Use public
SET search_path TO public;

BEGIN;


CREATE TEMP TABLE _lang_map (
  lang_name_lc text,
  code text,
  name text
) ON COMMIT DROP;

INSERT INTO _lang_map(lang_name_lc, code, name) VALUES
  ('english','en','English'),
  ('french','fr','French'),
  ('arabic','ar','Arabic'),
  ('spanish','es','Spanish'),
  ('german','de','German'),
  ('italian','it','Italian'),
  ('portuguese','pt','Portuguese'),
  ('dutch','nl','Dutch');

CREATE TEMP TABLE _src AS
SELECT
  b.*,
  TRIM(b.isbn13)                AS isbn13_t,
  TRIM(b.isbn)                  AS isbn10_t,
  NULLIF(TRIM(b.publisher),'')  AS publisher_t,
  NULLIF(TRIM(b.title),'')      AS title_t,
  NULLIF(TRIM(b.title_long),'') AS title_long_t,
  CASE
    WHEN b.language ~ '^[A-Za-z]{2}$' THEN LOWER(b.language)
    ELSE (SELECT code FROM _lang_map WHERE lang_name_lc = LOWER(TRIM(b.language)) LIMIT 1)
  END                           AS lang2,
  -- final usable title = title or title_long
  COALESCE(NULLIF(TRIM(b.title),''), NULLIF(TRIM(b.title_long),'')) AS title_final
FROM public.books_nd b
WHERE NULLIF(TRIM(b.isbn13),'') IS NOT NULL;




INSERT INTO languages(code, name)
SELECT DISTINCT s.lang2::char(2) AS code,
       COALESCE(lm.name, UPPER(s.lang2)) AS name
FROM _src s
LEFT JOIN _lang_map lm ON lm.code = s.lang2
WHERE s.lang2 IS NOT NULL
ON CONFLICT (code) DO NOTHING;


INSERT INTO publishers(name)
SELECT DISTINCT s.publisher_t
FROM _src s
WHERE s.publisher_t IS NOT NULL
ON CONFLICT (name) DO NOTHING;


INSERT INTO authors(name)
SELECT DISTINCT TRIM(a) AS name
FROM public.books_nd b
CROSS JOIN LATERAL unnest(b.authors) a
WHERE NULLIF(TRIM(a),'') IS NOT NULL
ON CONFLICT (name) DO NOTHING;


INSERT INTO subjects(name)
SELECT DISTINCT TRIM(su) AS name
FROM public.books_nd b
CROSS JOIN LATERAL unnest(b.subjects) su
WHERE NULLIF(TRIM(su),'') IS NOT NULL
ON CONFLICT (name) DO NOTHING;


WITH src_ranked AS (
  SELECT
    s.isbn10_t,
    s.isbn13_t,
    s.title_final,
    s.title_long_t,
    s.publisher_t,
    s.lang2,
    s.pages,
    s.msrp,
    s.binding,
    s.edition,
    s.image,
    s.synopsis,
    s.date_published,
    ROW_NUMBER() OVER (
      PARTITION BY s.isbn13_t
      ORDER BY
        (s.title_final IS NULL),           
        (s.publisher_t IS NULL),            
        (s.date_published IS NULL),         
        COALESCE(length(s.title_final),0) DESC
    ) AS rnk,
    COUNT(*) OVER (PARTITION BY s.isbn10_t) AS c10  
  FROM _src s
  WHERE s.isbn13_t IS NOT NULL
),
src_best AS (
  SELECT

    CASE WHEN c10 = 1 THEN isbn10_t ELSE NULL END AS isbn10_t,
    isbn13_t,
    title_final,
    title_long_t,
    publisher_t,
    lang2,
    pages,
    msrp,
    binding,
    edition,
    image,
    synopsis,
    date_published
  FROM src_ranked
  WHERE rnk = 1
)
INSERT INTO books (
  isbn10, isbn13, title, title_long, publisher_id, language_code, pages,
  msrp_cents, msrp_currency, binding, edition, image_url, synopsis,
  date_published, pub_year, pub_month,
  height_mm, width_mm, thickness_mm, weight_g
)
SELECT
  sb.isbn10_t,
  sb.isbn13_t,
  sb.title_final,         
  sb.title_long_t,
  p.publisher_id,
  sb.lang2::char(2),
  CASE WHEN sb.pages IS NOT NULL AND sb.pages > 0 THEN sb.pages END,
  CASE WHEN sb.msrp  IS NOT NULL AND sb.msrp >= 0 THEN ROUND(sb.msrp * 100)::int END,
  NULL::char(3),
  sb.binding,
  sb.edition,
  sb.image,
  sb.synopsis,
  sb.date_published,
  CASE WHEN sb.date_published IS NOT NULL THEN EXTRACT(YEAR  FROM sb.date_published)::smallint END,
  CASE WHEN sb.date_published IS NOT NULL THEN EXTRACT(MONTH FROM sb.date_published)::smallint END,
  NULL, NULL, NULL, NULL
FROM src_best sb
LEFT JOIN publishers p ON p.name = sb.publisher_t
WHERE sb.title_final IS NOT NULL
ON CONFLICT (isbn13) DO UPDATE
SET title          = EXCLUDED.title,
    title_long     = EXCLUDED.title_long,
    publisher_id   = EXCLUDED.publisher_id,
    language_code  = EXCLUDED.language_code,
    pages          = EXCLUDED.pages,
    msrp_cents     = EXCLUDED.msrp_cents,
    msrp_currency  = EXCLUDED.msrp_currency,
    binding        = EXCLUDED.binding,
    edition        = EXCLUDED.edition,
    image_url      = EXCLUDED.image_url,
    synopsis       = EXCLUDED.synopsis,
    date_published = EXCLUDED.date_published,
    pub_year       = EXCLUDED.pub_year,
    pub_month      = EXCLUDED.pub_month;


INSERT INTO book_authors (book_id, author_id, seq, role)
SELECT
  bk.book_id,
  a.author_id,
  ua.ord::smallint,
  'Author'
FROM public.books_nd b
JOIN books bk ON bk.isbn13 = TRIM(b.isbn13)
JOIN LATERAL unnest(b.authors) WITH ORDINALITY AS ua(name, ord) ON TRUE
JOIN authors a ON a.name = TRIM(ua.name)
WHERE NULLIF(TRIM(ua.name),'') IS NOT NULL
ON CONFLICT DO NOTHING;


INSERT INTO book_subjects (book_id, subject_id)
SELECT
  bk.book_id,
  s.subject_id
FROM public.books_nd b
JOIN books bk ON bk.isbn13 = TRIM(b.isbn13)
JOIN LATERAL unnest(b.subjects) su(name) ON TRUE
JOIN subjects s ON s.name = TRIM(su.name)
WHERE NULLIF(TRIM(su.name),'') IS NOT NULL
ON CONFLICT DO NOTHING;


INSERT INTO book_related_ids (book_id, rel_type, rel_value)
SELECT
  bk.book_id,
  kv.key,
  kv.value
FROM public.books_nd b
JOIN books bk ON bk.isbn13 = TRIM(b.isbn13)
JOIN LATERAL jsonb_each_text(b.related) AS kv(key, value) ON TRUE
ON CONFLICT DO NOTHING;

COMMIT;


