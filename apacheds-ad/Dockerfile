FROM openjdk:8-jre

LABEL maintainer="AndriyKalashnykov@gmail.com"

RUN apt-get update && apt-get upgrade --yes && apt-get install openssl --yes && apt-get clean autoclean && apt-get autoremove --yes && rm -rf /var/lib/{apt,dpkg,cache,log}/

RUN mkdir -p /ldap/ldif
WORKDIR /ldap
RUN wget https://github.com/kwart/ldap-server/releases/download/2017-09-04/ldap-server.jar

RUN useradd -r -M -d  /ldap ldap && \
    chown -R ldap:ldap /ldap && \
    chown -h ldap:ldap /ldap

USER ldap

# COPY users.ldif /ldap/ldif/users.ldif

EXPOSE 10389

CMD ["java","-jar","ldap-server.jar", "/ldap/ldif/users.ldif"]