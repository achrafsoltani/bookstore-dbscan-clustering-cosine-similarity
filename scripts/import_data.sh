#!/usr/bin/env bash
set -euo pipefail

DB_NAME="RecommanderSys"
DB_USER="postgres"
DB_HOST="localhost"
DB_PORT="5432"

# Dossier du script, pour que les chemins CSV marchent quel que soit l'endroit d'où tu lances le script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Chemins CSV (tu peux aussi passer d'autres chemins via variables d'env USERS_CSV / RATINGS_CSV)
USERS_CSV="${USERS_CSV:-$SCRIPT_DIR/BX_Users_clean.csv}"
RATINGS_CSV="${RATINGS_CSV:-$SCRIPT_DIR/BX_Ratings_clean.csv}"

echo "==> Using Users CSV:   $USERS_CSV"
echo "==> Using Ratings CSV: $RATINGS_CSV"

# Vérif fichiers
[[ -f "$USERS_CSV" ]]   || { echo "Fichier introuvable: $USERS_CSV"; exit 1; }
[[ -f "$RATINGS_CSV" ]] || { echo "Fichier introuvable: $RATINGS_CSV"; exit 1; }

echo "==> Importing Users (stage + upsert)..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<SQL
\set ON_ERROR_STOP on
BEGIN;

-- Table de stage Users
CREATE TEMP TABLE users_stage (
  user_id   INT,
  Location  TEXT,
  Age_raw   TEXT
);

-- Charge le CSV (NOTE: on laisse le shell substituer la variable)
\copy users_stage(user_id, Location, Age_raw) FROM '${USERS_CSV}' DELIMITER ';' CSV HEADER;

INSERT INTO Users(user_id, Location, Age)
SELECT
  s.user_id,
  NULLIF(s.Location, '') AS Location,
  CASE
    WHEN NULLIF(regexp_replace(COALESCE(s.Age_raw,''), '[^0-9]', '', 'g'), '') = '' THEN NULL
    ELSE
      CASE
        WHEN (NULLIF(regexp_replace(COALESCE(s.Age_raw,''), '[^0-9]', '', 'g'), ''))::INT BETWEEN 5 AND 120
          THEN (NULLIF(regexp_replace(COALESCE(s.Age_raw,''), '[^0-9]', '', 'g'), ''))::INT
        ELSE NULL
      END
  END AS Age
FROM users_stage s
ON CONFLICT (user_id) DO UPDATE
SET Location = EXCLUDED.Location,
    Age      = EXCLUDED.Age;

COMMIT;
SQL

echo "==> Importing Ratings (stage -> validation user_id uniquement)..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<SQL
\set ON_ERROR_STOP on
BEGIN;

CREATE TEMP TABLE ratings_stage (
  user_id INT,
  ISBN TEXT,
  Book_rating_text TEXT
);

\copy ratings_stage(user_id, ISBN, Book_rating_text) FROM '${RATINGS_CSV}' DELIMITER ';' CSV HEADER;

WITH cleaned AS (
  SELECT
    rs.user_id,
    TRIM(rs.ISBN)::VARCHAR(45) AS ISBN,
    CASE
      WHEN NULLIF(regexp_replace(COALESCE(rs.Book_rating_text,''), '[^0-9\-]', '', 'g'), '') = '' THEN NULL
      ELSE (NULLIF(regexp_replace(COALESCE(rs.Book_rating_text,''), '[^0-9\-]', '', 'g'), ''))::SMALLINT
    END AS Book_rating
  FROM ratings_stage rs
),
inserted AS (
  INSERT INTO Ratings(user_id, ISBN, Book_rating)
  SELECT c.user_id, c.ISBN, c.Book_rating
  FROM cleaned c
  JOIN Users u ON u.user_id = c.user_id
  ON CONFLICT (user_id, ISBN) DO NOTHING
  RETURNING 1
),
counts AS (
  SELECT
    (SELECT COUNT(*) FROM ratings_stage) AS staged_total,
    (SELECT COUNT(*) FROM inserted)      AS inserted_total
)
SELECT staged_total,
       inserted_total,
       (staged_total - inserted_total) AS skipped_total
FROM counts;

COMMIT;
SQL

echo "==> Done."

