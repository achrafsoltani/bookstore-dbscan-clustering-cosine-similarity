#!/bin/bash

DB_NAME="RecommanderSys"
DB_USER="postgres"
DB_HOST="localhost"     
DB_PORT="5432"

export PGPASSWORD="$PGPASSWORD"



psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f schema_csv_dataset.sql

