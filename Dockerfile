# ---------- Build ----------
FROM maven:3.9.5-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline
COPY src ./src
RUN mvn clean package -DskipTests

# ---------- Runtime ----------
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Add wget for healthcheck (Alpine JRE might not have it or it might be a symlink to busybox)
RUN apk add --no-cache wget

RUN addgroup -S spring && adduser -S spring -G spring
COPY --from=build /app/target/the-guardian-v1-1.0.0.jar app.jar
COPY docker-entrypoint.sh .
RUN chmod +x docker-entrypoint.sh

# Use standard 8080 port for consistency
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=5 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:${PORT:-8080}/actuator/health || exit 1

# Create storage directory and set permissions
RUN mkdir -p /app/data/kyc && chown -R spring:spring /app

USER spring:spring

# JVM optimizations for Render Free Plan:
# -Xmx384m: Limit heap to 384MB to fit within 512MB RAM
# -XX:+UseSerialGC: Use lower memory GC
# -XX:TieredStopAtLevel=1: Faster startup by limiting JIT compilation levels
ENTRYPOINT ["./docker-entrypoint.sh"]
