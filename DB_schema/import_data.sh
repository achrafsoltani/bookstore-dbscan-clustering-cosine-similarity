#!/bin/bash

DB_NAME="defaultdb"
DB_USER="avnadmin"
DB_HOST="welab-anir.e.aivencloud.com"
DB_PORT="15498"

export PGPASSWORD="$PGPASSWORD"

echo "Importing Books..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
  -c "\copy Books FROM 'BX_Books_final.csv' DELIMITER ';' CSV HEADER QUOTE '\"' ESCAPE '\"';"

echo "Importing Users..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
  -c "\copy Users FROM 'BX_Users_clean.csv' DELIMITER ';' CSV HEADER;"

echo "Importing Ratings..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
  -c "\copy Ratings FROM 'BX_Ratings_clean.csv' DELIMITER ';' CSV HEADER;"

