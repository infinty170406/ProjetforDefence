#!/bin/sh

echo "Entrypoint script starting..."
echo "--- Environment Variables (Masked) ---"
env | grep -E "SPRING_|DATABASE_|DB_|PORT" | sed 's/=\(.*\)/=********/'
echo "--------------------------------------"
echo ""

# 1. Construct JDBC URL from individual database components if available
if [ -n "$DB_HOST" ] && [ -n "$DB_PORT" ] && [ -n "$DB_NAME" ]; then
    echo "Constructing JDBC URL from individual database components..."
    export SPRING_DATASOURCE_URL="jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}"
    echo "JDBC URL constructed from DB_HOST, DB_PORT, DB_NAME"
elif [ -z "$SPRING_DATASOURCE_URL" ] && [ -n "$DATABASE_URL" ]; then
    # Fallback: If individual components not available, use DATABASE_URL
    echo "Individual DB components not found. Using DATABASE_URL provided by Render."
    export SPRING_DATASOURCE_URL="$DATABASE_URL"
    
    # Fix Protocol: Change postgres:// or postgresql:// to jdbc:postgresql://
    case "$SPRING_DATASOURCE_URL" in
        postgres://*) 
            echo "Detected postgres:// protocol. Converting to jdbc:postgresql://..."
            export SPRING_DATASOURCE_URL=$(echo "$SPRING_DATASOURCE_URL" | sed 's|^postgres://|jdbc:postgresql://|')
            ;;
        postgresql://*) 
            echo "Detected postgresql:// protocol. Converting to jdbc:postgresql://..."
            export SPRING_DATASOURCE_URL=$(echo "$SPRING_DATASOURCE_URL" | sed 's|^postgresql://|jdbc:postgresql://|')
            ;;
    esac
fi

# Final check and logging
if [ -n "$SPRING_DATASOURCE_URL" ]; then
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
