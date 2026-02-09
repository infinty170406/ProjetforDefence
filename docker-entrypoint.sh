#!/bin/sh

echo "Entrypoint script starting..."

# 1. Fallback: If SPRING_DATASOURCE_URL is empty, use Render's default DATABASE_URL
if [ -z "$SPRING_DATASOURCE_URL" ] && [ -n "$DATABASE_URL" ]; then
    echo "SPRING_DATASOURCE_URL is empty. Using DATABASE_URL provided by Render."
    export SPRING_DATASOURCE_URL="$DATABASE_URL"
fi

# 2. Fix Protocol: Ensure it starts with jdbc:postgresql://
if [ -n "$SPRING_DATASOURCE_URL" ]; then
    case "$SPRING_DATASOURCE_URL" in
        jdbc:*)
            echo "SPRING_DATASOURCE_URL already starts with jdbc:. Good."
            ;;
        postgres://*|postgresql://*)
            echo "Detected non-JDBC postgres protocol. Converting..."
            export SPRING_DATASOURCE_URL=$(echo "$SPRING_DATASOURCE_URL" | sed -E 's/^(postgresql|postgres):\/\//jdbc:postgresql:\/\//')
            ;;
        *)
            echo "WARNING: SPRING_DATASOURCE_URL has an unrecognized format: $(echo $SPRING_DATASOURCE_URL | cut -c1-15)..."
            ;;
    esac
    
    # Final check
    if echo "$SPRING_DATASOURCE_URL" | grep -q "^jdbc:postgresql://"; then
        echo "Final SPRING_DATASOURCE_URL starts with jdbc:postgresql:// (OK)"
    else
        echo "ERROR: Final SPRING_DATASOURCE_URL does NOT start with jdbc:postgresql:// ($SPRING_DATASOURCE_URL)"
    fi
else
    echo "CRITICAL WARNING: SPRING_DATASOURCE_URL is NOT set. App will try localhost which will likely fail on Render!"
fi

# Run the application
exec java -jar app.jar
