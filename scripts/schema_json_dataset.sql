DROP TABLE IF EXISTS books_nd;
DROP TABLE IF EXISTS books_nd_raw;


CREATE TABLE books_nd_raw (
  id  bigserial PRIMARY KEY,
  doc jsonb NOT NULL
);

-- Typed/normalized view of the JSON
CREATE TABLE books_nd (
  isbn                 text PRIMARY KEY,
  isbn13               text,
  title                text,
  title_long           text,
  authors              text[],
  subjects             text[],
  language             text,
  publisher            text,
  pages                integer,
  msrp                 numeric,
  binding              text,
  edition              text,
  image                text,
  dimensions           text,
  related              jsonb,
  synopsis             text,
  date_published_text  text,
  date_published       date
);

-- Optional helpful indexes
CREATE INDEX IF NOT EXISTS idx_books_nd_authors  ON books_nd USING gin (authors);
CREATE INDEX IF NOT EXISTS idx_books_nd_subjects ON books_nd USING gin (subjects);
CREATE INDEX IF NOT EXISTS idx_books_nd_raw_doc  ON books_nd_raw USING gin (doc);

