#!/bin/sh

echo "Entrypoint script starting..."

# 1. Fallback: If SPRING_DATASOURCE_URL is empty, use Render's default DATABASE_URL
if [ -z "$SPRING_DATASOURCE_URL" ] && [ -n "$DATABASE_URL" ]; then
    echo "SPRING_DATASOURCE_URL is empty. Using DATABASE_URL provided by Render."
    export SPRING_DATASOURCE_URL="$DATABASE_URL"
fi

# 2. Fix Protocol: Change postgres:// to jdbc:postgresql://
if [ -n "$SPRING_DATASOURCE_URL" ]; then
    # Check if it starts with postgres:// (common in Render)
    if echo "$SPRING_DATASOURCE_URL" | grep -q "^postgres://"; then
        echo "Detected postgres:// protocol. Converting to jdbc:postgresql://..."
        export SPRING_DATASOURCE_URL=$(echo "$SPRING_DATASOURCE_URL" | sed 's|^postgres://|jdbc:postgresql://|')
    fi
    
    echo "SPRING_DATASOURCE_URL is valid."
else
    echo "CRITICAL WARNING: SPRING_DATASOURCE_URL is NOT set. App will try localhost which will likely fail on Render!"
fi

# Run the application
exec java -jar app.jar
