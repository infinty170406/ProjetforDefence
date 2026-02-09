#!/bin/sh

echo "Entrypoint script starting..."

# 1. Fallback: If SPRING_DATASOURCE_URL is empty, use Render's default DATABASE_URL
if [ -z "$SPRING_DATASOURCE_URL" ] && [ -n "$DATABASE_URL" ]; then
    echo "SPRING_DATASOURCE_URL is empty. Using DATABASE_URL provided by Render."
    export SPRING_DATASOURCE_URL="$DATABASE_URL"
fi

# 2. Fix Protocol: Change postgres:// or postgresql:// to jdbc:postgresql://
if [ -n "$SPRING_DATASOURCE_URL" ]; then
    case "$SPRING_DATASOURCE_URL" in
        jdbc:*)
            echo "SPRING_DATASOURCE_URL already starts with jdbc:."
            ;;
        postgres://*|postgresql://*)
            echo "Detected non-JDBC protocol. Converting to jdbc:postgresql://..."
            export SPRING_DATASOURCE_URL=$(echo "$SPRING_DATASOURCE_URL" | sed -E 's/^(postgresql|postgres):\/\//jdbc:postgresql:\/\//')
            ;;
    esac
    echo "Final SPRING_DATASOURCE_URL: $(echo $SPRING_DATASOURCE_URL | cut -c1-30)..."
else
    echo "CRITICAL WARNING: SPRING_DATASOURCE_URL is NOT set!"
fi

# Run the application
# We pass it as a system property to ensure it has the highest priority over env vars
exec java -Dspring.datasource.url="$SPRING_DATASOURCE_URL" -jar app.jar
