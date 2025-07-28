#!/bin/bash

DB_NAME="defaultdb"
DB_USER="avnadmin"
DB_HOST="welab-anir.e.aivencloud.com"     
DB_PORT="15498"

export PGPASSWORD="$PGPASSWORD"



psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f schema.sql

