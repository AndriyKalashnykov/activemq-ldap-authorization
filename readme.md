[![Docker Image CI](https://github.com/AndriyKalashnykov/activemq-ldap-authorization/actions/workflows/docker-image.yml/badge.svg?branch=master)](https://github.com/AndriyKalashnykov/activemq-ldap-authorization/actions/workflows/docker-image.yml)
[![Hits](https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2FAndriyKalashnykov%2Factivemq-ldap-authorization&count_bg=%2333CD56&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=hits&edge_flat=false)](https://hits.seeyoufarm.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
# ActiveMQ LDAP Authentication and Authorization

This project demonstrates how to use <b>OpenLDAP</b> and <b>Apache DS</b> (to mimic <b>Microsoft Active Directory</b>) for Apache ActiveMQ Authentication and Authorization it also shows how to secure ActiveMQ web console

## Pre-requisites

* [docker](https://docs.docker.com/get-docker/)
* [docker-compose](https://docs.docker.com/compose/install/)

## Clone repo

```bash
git clone git@github.com:AndriyKalashnykov/activemq-ldap-authorization.git
cd activemq-ldap-authorization
```

## Provide DockerHub credentials

Edit `./activemq-ldap-authorization/scripts/set-env.sh`, uncomment and set following environment variables:

```bash
# DOCKER_LOGIN=
# DOCKER_PWD=
```

## Run docker-compose to start up ActiveMQ, Open LDAP server and PHP LDAP Admin

```bash
cd 5.1.16
docker-compose up
```

## ActiveMQ web console

In web browser open `http://127.0.0.1:8161/admin/` use <b>login</b>: `admin` and <b>password</b> `admin`

```
open http://127.0.0.1:8161/admin/
```

## PHP LDAP Admin web console

In web browser open `https://localhost:6443/` 
use <b>Login DN</b>: `cn=admin,dc=activemq,dc=apache,dc=org` and <b>Password</b>: `admin`

```bash
open https://localhost:6443/
```

## Test OpenLDAP search

```bash
./scripts/search-openldap.sh
```
## Start up Apache DS server and PHP LDAP Admin

```bash
cd activemq-ldap-authorization/apacheds-ad
docker-compose up
```

## PHP LDAP Admin web console

In web browser open `https://localhost:6443/` 
use <b>Login DN</b>: `cn=mqbroker,ou=Services,ou=ActiveMQ,dc=activemq,dc=apache,dc=org` and <b>Password</b>: `admin`

```bash
open https://localhost:6443/
```
## Test Apache DS search

```bash
./scripts/search-apacheds.sh
```
