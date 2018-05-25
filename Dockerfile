FROM gradle:jdk8-alpine
VOLUME /tmp
USER root
ARG PROJECT_PATH
WORKDIR /home/gradle/project
COPY ${PROJECT_PATH} .
ENTRYPOINT ["gradle", "bootRun", "-x", "test"]