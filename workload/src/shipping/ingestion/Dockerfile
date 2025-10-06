FROM openjdk:17.0.1-jdk-slim as base
WORKDIR /usr/src/app
EXPOSE 80

FROM maven:3.6.3-openjdk-17-slim as maven
WORKDIR /usr/src/app

COPY pom.xml ./
RUN mvn clean dependency:go-offline

FROM maven as build
WORKDIR /usr/src/app

COPY src ./src
RUN mvn compile

FROM build as testrunner
WORKDIR /usr/src/app

ENTRYPOINT ["mvn", "verify"]

FROM build as package
WORKDIR /usr/src/app

RUN mvn package -Dmaven.test.skip=true -Dcheckstyle.skip=true -Dmaven.javadoc.skip=true

FROM base as final

WORKDIR /app

ADD https://github.com/Microsoft/ApplicationInsights-Java/releases/download/3.6.2/applicationinsights-agent-3.6.2.jar ./appinsights/applicationinsights-agent-3.6.2.jar
ADD /etc/AI-Agent.xml ./appinsights/AI-Agent.xml

COPY --from=package /usr/src/app/target/ingestion-0.1.0.jar ./

ENTRYPOINT ["java","-Djava.security.egdfile=file:/dev/./urandom","-javaagent:/app/appinsights/applicationinsights-agent-3.6.2.jar","-jar","ingestion-0.1.0.jar"]
