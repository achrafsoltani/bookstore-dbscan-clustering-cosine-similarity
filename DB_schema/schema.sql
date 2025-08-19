
DROP TABLE IF EXISTS book_related_ids;
DROP TABLE IF EXISTS book_subjects;
DROP TABLE IF EXISTS book_authors;
DROP TABLE IF EXISTS books;
DROP TABLE IF EXISTS subjects;
DROP TABLE IF EXISTS authors;
DROP TABLE IF EXISTS publishers;
DROP TABLE IF EXISTS languages;
DROP TABLE IF EXISTS Ratings;
DROP TABLE IF EXISTS Users;
DROP TABLE IF EXISTS books_nd;
DROP TABLE IF EXISTS books_nd_raw;
DROP TABLE IF EXISTS Ratings;
DROP TABLE IF EXISTS Users;


CREATE TABLE books_nd_raw (
  id  bigserial PRIMARY KEY,
  doc jsonb NOT NULL
);

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




CREATE TABLE languages (
  code char(2) PRIMARY KEY,
  name text NOT NULL
);


CREATE TABLE publishers (
  publisher_id bigserial PRIMARY KEY,
  name text UNIQUE NOT NULL
);


CREATE TABLE authors (
  author_id bigserial PRIMARY KEY,
  name text UNIQUE NOT NULL
);


CREATE TABLE subjects (
  subject_id bigserial PRIMARY KEY,
  name text UNIQUE NOT NULL,
  scheme text
);


CREATE TABLE books (
  book_id bigserial PRIMARY KEY,
  isbn10  text UNIQUE,
  isbn13  text UNIQUE NOT NULL,
  title   text NOT NULL,
  title_long text,
  publisher_id bigint REFERENCES publishers(publisher_id),
  language_code char(2) REFERENCES languages(code),
  pages integer CHECK (pages > 0),

  msrp_cents integer CHECK (msrp_cents IS NULL OR msrp_cents >= 0),
  msrp_currency char(3),
  binding text,
  edition text,
  image_url text,
  synopsis text,
  date_published date,
  pub_year  smallint,
  pub_month smallint CHECK (pub_month BETWEEN 1 AND 12),

  height_mm integer,
  width_mm  integer,
  thickness_mm integer,
  weight_g integer
);


CREATE TABLE book_authors (
  book_id bigint REFERENCES books(book_id) ON DELETE CASCADE,
  author_id bigint REFERENCES authors(author_id) ON DELETE RESTRICT,
  seq smallint,   -- order of authors
  role text,      -- e.g., editor, illustrator
  PRIMARY KEY (book_id, author_id)
);


CREATE TABLE book_subjects (
  book_id bigint REFERENCES books(book_id) ON DELETE CASCADE,
  subject_id bigint REFERENCES subjects(subject_id) ON DELETE RESTRICT,
  PRIMARY KEY (book_id, subject_id)
);


CREATE TABLE book_related_ids (
  book_id bigint REFERENCES books(book_id) ON DELETE CASCADE,
  rel_type text,
  rel_value text,
  PRIMARY KEY (book_id, rel_type)
);


CREATE TABLE Users (
    user_id INT PRIMARY KEY,
    Location VARCHAR(250),
    Age INT
);

CREATE TABLE Ratings (
    user_id INT,
    ISBN VARCHAR(45),
    Book_rating SMALLINT,
    PRIMARY KEY (user_id, ISBN),
    FOREIGN KEY (user_id) REFERENCES Users(user_id)
);

