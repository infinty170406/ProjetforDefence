#!/bin/sh

echo "Entrypoint script starting..."

# 1. Fallback: If SPRING_DATASOURCE_URL is empty, use Render's default DATABASE_URL
if [ -z "$SPRING_DATASOURCE_URL" ] && [ -n "$DATABASE_URL" ]; then
    echo "SPRING_DATASOURCE_URL is empty. Using DATABASE_URL provided by Render."
    export SPRING_DATASOURCE_URL="$DATABASE_URL"
fi

# 2. Protocol Check: Spring Boot expects jdbc:postgresql://
if [ -n "$SPRING_DATASOURCE_URL" ]; then
    echo "SPRING_DATASOURCE_URL: $(echo $SPRING_DATASOURCE_URL | cut -c1-30)..."
    
    if ! echo "$SPRING_DATASOURCE_URL" | grep -q "^jdbc:"; then
        echo "WARNING: SPRING_DATASOURCE_URL does not start with jdbc:. This might cause issues."
    fi
else
    echo "CRITICAL WARNING: SPRING_DATASOURCE_URL is NOT set!"
fi
    echo "CRITICAL WARNING: SPRING_DATASOURCE_URL is NOT set. App will try localhost which will likely fail on Render!"
fi

# Run the application
# We pass it as a system property to ensure it has the highest priority over env vars
exec java -Dspring.datasource.url="$SPRING_DATASOURCE_URL" -jar app.jar
