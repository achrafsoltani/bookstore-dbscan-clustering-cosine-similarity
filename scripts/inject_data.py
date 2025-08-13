
import os, json, getpass
from datetime import datetime
from decimal import Decimal, InvalidOperation

import psycopg2
from psycopg2.extras import Json

# ---- config ----
JSONL_PATH = "split_files/split_1.jsonl"
DB_NAME = "RecommanderSys"
DB_USER = "postgres"
DB_HOST = "127.0.0.1"
DB_PORT = 5432
BATCH_COMMIT = 1000
MAX_ERRORS = 200
# ----------------

def get_password():
    pw = os.environ.get("PGPASSWORD")
    return pw if pw else getpass.getpass(f"Postgres password for user '{DB_USER}': ")

def parse_pages(val):
    if val is None: return None
    try:
        n = int(str(val).strip())
        return n if 0 < n < 10000 else None
    except Exception:
        return None

def parse_msrp(val):
    if val is None: return None
    try:
        return Decimal(str(val).strip())
    except (InvalidOperation, ValueError):
        return None

def parse_date_fields(raw):
    if raw is None: return (None, None)
    s = str(raw).strip()
    if not s: return (None, None)
    try:
        if len(s) >= 10 and s[4] == '-' and s[7] == '-':
            d = datetime.strptime(s[:10], "%Y-%m-%d").date()
            return (s, d.isoformat())
    except Exception:
        pass
    if len(s) >= 4 and s[:4].isdigit():
        try:
            d = datetime.strptime(s[:4] + "-01-01", "%Y-%m-%d").date()
            return (s, d.isoformat())
        except Exception:
            pass
    return (s, None)

def as_list(val):
    if isinstance(val, list):
        return [str(x).strip() for x in val if x is not None]
    if isinstance(val, str):
        s = val.strip()
        return [s] if s else []
    return []

def ensure_indexes(cur):
    cur.execute("""
        CREATE UNIQUE INDEX IF NOT EXISTS ux_books_nd_raw_isbn
        ON books_nd_raw ((doc->>'isbn'));
    """)

def upsert_raw(cur, doc):
    cur.execute("""
        INSERT INTO books_nd_raw (doc)
        VALUES (%s)
        ON CONFLICT ((doc->>'isbn')) DO UPDATE
        SET doc = EXCLUDED.doc;
    """, (Json(doc),))

def upsert_typed(cur, doc):
    isbn = (doc.get("isbn") or "").strip()
    if not isbn: return

    isbn13     = doc.get("isbn13")
    title      = doc.get("title")
    title_long = doc.get("title_long")
    authors    = as_list(doc.get("authors"))
    subjects   = as_list(doc.get("subjects"))
    language   = doc.get("language")
    publisher  = doc.get("publisher")
    pages      = parse_pages(doc.get("pages"))
    msrp       = parse_msrp(doc.get("msrp"))
    binding    = doc.get("binding")
    edition    = str(doc.get("edition")) if doc.get("edition") is not None else None
    image      = doc.get("image")
    dimensions = doc.get("dimensions")
    related    = doc.get("related") if isinstance(doc.get("related"), dict) else None
    synopsis   = doc.get("synopsis")
    txt, dte   = parse_date_fields(doc.get("date_published"))

    cur.execute("""
        INSERT INTO books_nd (
          isbn, isbn13, title, title_long, authors, subjects, language, publisher,
          pages, msrp, binding, edition, image, dimensions, related, synopsis,
          date_published_text, date_published
        )
        VALUES (
          %(isbn)s, %(isbn13)s, %(title)s, %(title_long)s, %(authors)s, %(subjects)s, %(language)s, %(publisher)s,
          %(pages)s, %(msrp)s, %(binding)s, %(edition)s, %(image)s, %(dimensions)s, %(related)s, %(synopsis)s,
          %(date_txt)s, %(date_val)s
        )
        ON CONFLICT (isbn) DO UPDATE SET
          isbn13              = EXCLUDED.isbn13,
          title               = EXCLUDED.title,
          title_long          = EXCLUDED.title_long,
          authors             = EXCLUDED.authors,
          subjects            = EXCLUDED.subjects,
          language            = EXCLUDED.language,
          publisher           = EXCLUDED.publisher,
          pages               = EXCLUDED.pages,
          msrp                = EXCLUDED.msrp,
          binding             = EXCLUDED.binding,
          edition             = EXCLUDED.edition,
          image               = EXCLUDED.image,
          dimensions          = EXCLUDED.dimensions,
          related             = EXCLUDED.related,
          synopsis            = EXCLUDED.synopsis,
          date_published_text = EXCLUDED.date_published_text,
          date_published      = EXCLUDED.date_published;
    """, dict(
        isbn=isbn, isbn13=isbn13, title=title, title_long=title_long,
        authors=authors, subjects=subjects, language=language, publisher=publisher,
        pages=pages, msrp=msrp, binding=binding, edition=edition, image=image,
        dimensions=dimensions, related=Json(related) if related is not None else None,
        synopsis=synopsis, date_txt=txt, date_val=dte
    ))

def main():
    conn = psycopg2.connect(
        dbname=DB_NAME,
        user=DB_USER,
        password=get_password(),
        host=DB_HOST,
        port=DB_PORT,
    )
    conn.autocommit = False
    cur = conn.cursor()

    ensure_indexes(cur)

    total = ok = skipped = errors = batch = 0

    with open(JSONL_PATH, "r", encoding="utf-8", errors="ignore") as f:
        for line_no, line in enumerate(f, 1):
            total += 1
            s = line.strip()
            if not s:
                skipped += 1
                continue
            try:
                doc = json.loads(s)
            except Exception as e:
                errors += 1; skipped += 1
                print(f"[Line {line_no}] Bad JSON: {e}")
                if errors >= MAX_ERRORS:
                    print(f"Hit MAX_ERRORS={MAX_ERRORS}. Stopping.")
                    break
                continue

            isbn = (doc.get("isbn") or "").strip()
            if not isbn:
                errors += 1
                print(f"[Line {line_no}] Skipped: missing ISBN")
                if errors >= MAX_ERRORS:
                    print(f"Hit MAX_ERRORS={MAX_ERRORS}. Stopping.")
                    break
                continue

            try:
                upsert_raw(cur, doc)
                upsert_typed(cur, doc)
                batch += 1; ok += 1
                if batch >= BATCH_COMMIT:
                    conn.commit(); batch = 0
            except Exception as e:
                conn.rollback(); batch = 0
                errors += 1
                print(f"[Line {line_no}] DB error: {e}")
                if errors >= MAX_ERRORS:
                    print(f"Hit MAX_ERRORS={MAX_ERRORS}. Stopping.")
                    break

    if batch:
        conn.commit()

    cur.close()
    conn.close()
    print(f"Done. Total: {total}, Upserted: {ok}, Skipped: {skipped}, Errors: {errors}")

if __name__ == "__main__":
    main()

