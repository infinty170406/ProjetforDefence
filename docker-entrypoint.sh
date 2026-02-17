#!/bin/sh

echo "Entrypoint script starting..."
echo "--- Environment Variables (Masked) ---"
env | grep -E "SPRING_|DATABASE_|PORT" | sed 's/=\(.*\)/=********/'
echo "--------------------------------------"


# 1. Clean up SPRING_DATASOURCE_URL if it's a literal placeholder like ${DB_HOST}
if echo "$SPRING_DATASOURCE_URL" | grep -q '\${'; then
    echo "SPRING_DATASOURCE_URL contains unresolved placeholders. Clearing it to force fallback."
    export SPRING_DATASOURCE_URL=""
fi

# 2. Fallback: If SPRING_DATASOURCE_URL is empty, use Render's default DATABASE_URL
if [ -z "$SPRING_DATASOURCE_URL" ] && [ -n "$DATABASE_URL" ]; then
    echo "SPRING_DATASOURCE_URL is empty or invalid. Using DATABASE_URL provided by Render."
    export SPRING_DATASOURCE_URL="$DATABASE_URL"
fi

# 3. Fix Protocol: Change postgres:// to jdbc:postgresql://
if [ -n "$SPRING_DATASOURCE_URL" ]; then
    if echo "$SPRING_DATASOURCE_URL" | grep -q "^postgres://"; then
        echo "Detected postgres:// protocol. Converting to jdbc:postgresql://..."
        export SPRING_DATASOURCE_URL=$(echo "$SPRING_DATASOURCE_URL" | sed 's|^postgres://|jdbc:postgresql://|')
    fi
    
    # Final check: ensure it starts with jdbc:postgresql://
    if ! echo "$SPRING_DATASOURCE_URL" | grep -q "^jdbc:postgresql://"; then
        echo "WARNING: SPRING_DATASOURCE_URL does not start with jdbc:postgresql://. Current value: $(echo "$SPRING_DATASOURCE_URL" | cut -c 1-20)..."
    fi
    
    # Masking password for logging
    MASKED_URL=$(echo "$SPRING_DATASOURCE_URL" | sed 's|:[^:@]*@|:****@|')
    echo "Final SPRING_DATASOURCE_URL: $MASKED_URL"
else
    echo "CRITICAL WARNING: SPRING_DATASOURCE_URL is NOT set. App will likely fail on Render!"
fi

# Log the port
echo "Application will start on port: ${PORT:-8080}"

# Run the application
exec java -jar app.jar
