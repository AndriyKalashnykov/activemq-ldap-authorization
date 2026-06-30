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
ARG HAWTIO_VERSION=5.2.1
ARG ACTIVEMQ_JAAS_VERSION=6.2.6
# renovate: datasource=maven depName=org.slf4j:slf4j-api
ARG SLF4J_VERSION=2.0.18
# hawtio 5.2.1's WAR bundles jackson-databind 2.19.2 (WEB-INF/lib), which carries
# CVE-2026-54512 + CVE-2026-54513 (both HIGH; the 2.19 line has NO fix). No hawtio
# release ships patched jackson yet, so the RUN below repacks the WAR with the
# patched, Renovate-tracked jackson set (all three must move together — mixing
# minors risks NoSuchMethodError). Re-evaluate when HAWTIO_VERSION bumps to a
# release that bundles patched jackson. No sha256 pin: Maven Central versioned
# coordinates are immutable + HTTPS (same trust model as the WAR/jaas/slf4j
# downloads above), and a hardcoded digest would break Renovate's auto bump.
# JACKSON_VERSION drives databind + core; annotations is separate (coarser
# scheme, no patch releases).
# renovate: datasource=maven depName=com.fasterxml.jackson.core:jackson-databind
ARG JACKSON_VERSION=2.22.0
# renovate: datasource=maven depName=com.fasterxml.jackson.core:jackson-annotations
ARG JACKSON_ANNOTATIONS_VERSION=2.22

# apt upgrade clears base CVEs (blocking Trivy gate). curl fetches the WAR + the
# two jars that put org.apache.activemq.jaas.LDAPLoginModule + GroupPrincipal on
# Tomcat's classpath (the same set the broker uses for LDAP login — no jasypt,
# which only the encrypted-password modules need). unzip/zip explode + repack the
# WAR to swap its vulnerable jackson jars. curl/unzip/zip are removed afterwards.
# DL3003 ignored: the `cd` into a transient explode dir lives inside this single
# RUN (a WORKDIR would persist as an image layer dir, which is wrong for a scratch
# repack); DL3008 (apt version pinning) is the repo-wide accepted advisory.
# hadolint ignore=DL3003
RUN set -eux; \
    apt-get update; apt-get upgrade -y; \
    apt-get install -y --no-install-recommends curl ca-certificates unzip zip; \
    rm -rf "$CATALINA_HOME"/webapps/*; \
    curl -fsSLo "$CATALINA_HOME/webapps/hawtio.war" \
      "https://repo1.maven.org/maven2/io/hawt/hawtio-default/${HAWTIO_VERSION}/hawtio-default-${HAWTIO_VERSION}.war"; \
    curl -fsSLo "$CATALINA_HOME/lib/activemq-jaas-${ACTIVEMQ_JAAS_VERSION}.jar" \
      "https://repo1.maven.org/maven2/org/apache/activemq/activemq-jaas/${ACTIVEMQ_JAAS_VERSION}/activemq-jaas-${ACTIVEMQ_JAAS_VERSION}.jar"; \
    curl -fsSLo "$CATALINA_HOME/lib/slf4j-api-${SLF4J_VERSION}.jar" \
      "https://repo1.maven.org/maven2/org/slf4j/slf4j-api/${SLF4J_VERSION}/slf4j-api-${SLF4J_VERSION}.jar"; \
    cd "$CATALINA_HOME/webapps"; mkdir hawtio-x; cd hawtio-x; unzip -q ../hawtio.war; \
    rm -f WEB-INF/lib/jackson-databind-*.jar WEB-INF/lib/jackson-core-*.jar WEB-INF/lib/jackson-annotations-*.jar; \
    curl -fsSLo "WEB-INF/lib/jackson-databind-${JACKSON_VERSION}.jar" \
      "https://repo1.maven.org/maven2/com/fasterxml/jackson/core/jackson-databind/${JACKSON_VERSION}/jackson-databind-${JACKSON_VERSION}.jar"; \
    curl -fsSLo "WEB-INF/lib/jackson-core-${JACKSON_VERSION}.jar" \
      "https://repo1.maven.org/maven2/com/fasterxml/jackson/core/jackson-core/${JACKSON_VERSION}/jackson-core-${JACKSON_VERSION}.jar"; \
    curl -fsSLo "WEB-INF/lib/jackson-annotations-${JACKSON_ANNOTATIONS_VERSION}.jar" \
      "https://repo1.maven.org/maven2/com/fasterxml/jackson/core/jackson-annotations/${JACKSON_ANNOTATIONS_VERSION}/jackson-annotations-${JACKSON_ANNOTATIONS_VERSION}.jar"; \
    rm -f ../hawtio.war; zip -qr ../hawtio.war .; cd ..; rm -rf hawtio-x; \
    apt-get purge -y curl unzip zip; apt-get autoremove -y; apt-get clean; rm -rf /var/lib/apt/lists/*

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
