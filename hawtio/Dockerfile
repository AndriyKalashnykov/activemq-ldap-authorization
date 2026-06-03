# hawtio management console for the ActiveMQ broker, LDAP-secured via the SAME
# LDAPLogin JAAS realm the broker + its web console use. Standalone deployment
# (the canonical pattern — ActiveMQ 6.x cannot embed current hawtio; see AMQ-9300):
# the hawtio WAR runs in Tomcat and connects to the broker's Jolokia endpoint
# (/api/jolokia), which is itself LDAP-protected.
FROM tomcat:11.0-jre25-temurin-jammy

# Pinned, Renovate-trackable versions (via the generic # renovate: customManager
# in renovate.json). ACTIVEMQ_JAAS_VERSION is intentionally NOT annotated — it is
# coupled to the broker's ActiveMQ version (which is itself manually bumped).
# renovate: datasource=maven depName=io.hawt:hawtio-default
ARG HAWTIO_VERSION=5.2.0
ARG ACTIVEMQ_JAAS_VERSION=6.2.6
# renovate: datasource=maven depName=org.slf4j:slf4j-api
ARG SLF4J_VERSION=2.0.18

# apt upgrade clears base CVEs (blocking Trivy gate). curl fetches the WAR + the
# two jars that put org.apache.activemq.jaas.LDAPLoginModule + GroupPrincipal on
# Tomcat's classpath (the same set the broker uses for LDAP login — no jasypt,
# which only the encrypted-password modules need). curl is removed afterwards.
RUN set -eux; \
    apt-get update; apt-get upgrade -y; \
    apt-get install -y --no-install-recommends curl ca-certificates; \
    rm -rf "$CATALINA_HOME"/webapps/*; \
    curl -fsSLo "$CATALINA_HOME/webapps/hawtio.war" \
      "https://repo1.maven.org/maven2/io/hawt/hawtio-default/${HAWTIO_VERSION}/hawtio-default-${HAWTIO_VERSION}.war"; \
    curl -fsSLo "$CATALINA_HOME/lib/activemq-jaas-${ACTIVEMQ_JAAS_VERSION}.jar" \
      "https://repo1.maven.org/maven2/org/apache/activemq/activemq-jaas/${ACTIVEMQ_JAAS_VERSION}/activemq-jaas-${ACTIVEMQ_JAAS_VERSION}.jar"; \
    curl -fsSLo "$CATALINA_HOME/lib/slf4j-api-${SLF4J_VERSION}.jar" \
      "https://repo1.maven.org/maven2/org/slf4j/slf4j-api/${SLF4J_VERSION}/slf4j-api-${SLF4J_VERSION}.jar"; \
    apt-get purge -y curl; apt-get autoremove -y; apt-get clean; rm -rf /var/lib/apt/lists/*

# hawtio auth: enabled, JAAS realm "LDAPLogin", roles read from ActiveMQ's
# GroupPrincipal (the class the broker maps LDAP groups to). hawtio.roles gates
# console access to members of the admins/users LDAP groups.
ENV CATALINA_OPTS="-Dhawtio.authenticationEnabled=true \
-Dhawtio.realm=LDAPLogin \
-Djava.security.auth.login.config=/usr/local/tomcat/conf/login.config \
-Dhawtio.rolePrincipalClasses=org.apache.activemq.jaas.GroupPrincipal \
-Dhawtio.roles=admins,users"

COPY login.config /usr/local/tomcat/conf/login.config
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
