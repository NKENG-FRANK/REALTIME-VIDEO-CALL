#!/bin/sh
set -e

echo "Checking if database is initialized..."

# Wait for postgres to be ready
until PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c '\q' > /dev/null 2>&1; do
  >&2 echo "Postgres is unavailable - sleeping"
  sleep 2
done

>&2 echo "Postgres is up - checking schema"

# Check if users table exists
TABLE_EXISTS=$(PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users');" | tr -d '[:space:]')

if [ "$TABLE_EXISTS" = "f" ] || [ -z "$TABLE_EXISTS" ]; then
    echo "Database is not initialized. Initializing..."
    if [ -f "schema.sql" ]; then
        PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f schema.sql
        echo "Database initialization complete."
    else
        echo "Error: schema.sql not found!"
        exit 1
    fi
else
    echo "Database is already initialized."
fi

# Execute the main command
exec "$@"
