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

RUN addgroup -S spring && adduser -S spring -G spring
COPY --from=build /app/target/the-guardian-v1-1.0.0.jar app.jar
COPY docker-entrypoint.sh .
RUN chmod +x docker-entrypoint.sh

HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

RUN chown -R spring:spring /app

USER spring:spring

ENTRYPOINT ["./docker-entrypoint.sh"]
