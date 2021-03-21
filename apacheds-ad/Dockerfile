FROM openjdk:8-jre-alpine

LABEL maintainer="AndriyKalashnykov@gmail.com"

RUN apk add --no-cache openssl
RUN mkdir /ldap
WORKDIR /ldap
RUN wget https://github.com/kwart/ldap-server/releases/download/2017-09-04/ldap-server.jar

COPY users.ldif /ldap/users.ldif

EXPOSE 10389

CMD ["java","-jar","ldap-server.jar", "users.ldif"]