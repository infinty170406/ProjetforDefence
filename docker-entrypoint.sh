#!/bin/sh

# Auto-correct Render's postgres:// URL to Spring Boot's jdbc:postgresql:// format
if [ -n "$SPRING_DATASOURCE_URL" ]; then
  if echo "$SPRING_DATASOURCE_URL" | grep -q "^postgres://"; then
    echo "Converting SPRING_DATASOURCE_URL from postgres:// to jdbc:postgresql://..."
    export SPRING_DATASOURCE_URL=$(echo "$SPRING_DATASOURCE_URL" | sed 's|^postgres://|jdbc:postgresql://|')
  fi
fi

# Run the application
exec java -jar app.jar
