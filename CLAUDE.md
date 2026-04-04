# CLAUDE.md

## Project Description

ActiveMQ LDAP authentication and authorization demo using OpenLDAP and Apache DS.

## Skills

- readme.md -> /readme
- .github/workflows/*.yml -> /ci-workflow

## Improvement Backlog

- [ ] Create Makefile with targets: build, push, up, down, test
- [ ] Add renovate.json for automated dependency updates
- [ ] Upgrade ActiveMQ from 5.16.1 to latest 5.x or 6.x (major migration)
- [ ] Upgrade Jetty libraries from 9.4.35 to latest 9.4.x or 10.x+
- [ ] Upgrade ldaptive from 1.2.4 to latest 2.x (major migration)
- [ ] Replace osixia/openldap:1.5.0 with a maintained alternative (bitnami/openldap or similar)
- [ ] Replace osixia/phpldapadmin:0.9.0 with a maintained alternative
- [ ] Replace ldapaccountmanager/lam:7.4 with latest version
- [ ] Upgrade eclipse-temurin base from JDK 8 to JDK 11+ when ActiveMQ supports it
