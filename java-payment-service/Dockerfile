FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /workspace/java-payment-service
COPY java-payment-service/pom.xml .
RUN mvn dependency:go-offline -B
COPY java-payment-service/src ./src
COPY proto ../proto
RUN mvn package -DskipTests -B

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=build /workspace/java-payment-service/target/*.jar app.jar
EXPOSE 9090
ENTRYPOINT ["java", "-jar", "app.jar"]
