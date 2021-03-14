# ActiveMQ/AMQ LDAP Authentication and Authorization

## ActiveMQ

```bash
./scripts/install-activemq.sh

# ActiveMQ LDAP Web Console
# https://eleipold.wordpress.com/author/eleipold/ 
# https://www.workhorseintegrations.com/2020/05/14/securing-activemq-console-with-ldap/
# https://github.com/tmielke/abloggerscode/blob/b154059f7df4c87fba26d7e65ad1dbb374a713c3/Articles/Blog/AMQJettyLDAP/jetty.xml

cp /opt/apache-activemq-5.16.1/conf/activemq.xml ~/projects/activemq-ldap-authorization/5.16.1/conf
cp /opt/apache-activemq-5.16.1/conf/jetty.xml ~/projects/activemq-ldap-authorization/5.16.1/conf
cp /opt/apache-activemq-5.16.1/conf/login.config ~/projects/activemq-ldap-authorization/5.16.1/conf
cp /opt/apache-activemq-5.16.1/conf/log4j.properties ~/projects/activemq-ldap-authorization/5.16.1/conf
cp /opt/apache-activemq-5.16.1/bin/env ~/projects/activemq-ldap-authorization/5.16.1/bin/

open http://localhost:8161/admin

# search for a group 

ldapsearch -x -H ldap://localhost:389 -a always -D "cn=admin,dc=activemq,dc=apache,dc=org" -w admin -b "ou=Group,ou=ActiveMQ,dc=activemq,dc=apache,dc=org" -s sub "(&(objectClass=groupOfNames)(member=uid=admin,ou=user,ou=activemq,dc=activemq,dc=apache,dc=org))"  cn

604a6bdf conn=1001 fd=12 ACCEPT from IP=172.17.0.1:50938 (IP=0.0.0.0:389)
604a6bdf conn=1001 op=0 BIND dn="cn=admin,dc=activemq,dc=apache,dc=org" method=128
604a6bdf conn=1001 op=0 BIND dn="cn=admin,dc=activemq,dc=apache,dc=org" mech=SIMPLE ssf=0
604a6bdf conn=1001 op=0 RESULT tag=97 err=0 text=
604a6bdf conn=1001 op=1 SRCH base="ou=User,ou=ActiveMQ,dc=activemq,dc=apache,dc=org" scope=2 deref=3 filter="(&(objectClass=uidObject)(uid=admin))"
604a6bdf conn=1001 op=1 SEARCH RESULT tag=101 err=0 nentries=1 text=
604a6bdf conn=1002 fd=13 ACCEPT from IP=172.17.0.1:50942 (IP=0.0.0.0:389)
604a6bdf conn=1002 op=0 BIND dn="uid=admin,ou=User,ou=ActiveMQ,dc=activemq,dc=apache,dc=org" method=128
604a6bdf conn=1002 op=0 BIND dn="uid=admin,ou=User,ou=ActiveMQ,dc=activemq,dc=apache,dc=org" mech=SIMPLE ssf=0
604a6bdf conn=1002 op=0 RESULT tag=97 err=0 text=
604a6bdf conn=1002 op=1 SRCH base="ou=Group,ou=ActiveMQ,dc=activemq,dc=apache,dc=org" scope=2 deref=3 filter="(&(objectClass=groupOfNames)(member=uid=admin,ou=user,ou=activemq,dc=activemq,dc=apache,dc=org))"
604a6bdf conn=1002 op=1 SRCH attr=cn
604a6bdf conn=1002 op=1 SEARCH RESULT tag=101 err=32 nentries=0 text=
604a6bdf conn=1001 op=2 UNBIND
604a6bdf conn=1001 fd=12 closed


ldapsearch -x -H ldap://localhost:389 -a always -D "cn=admin,dc=activemq,dc=apache,dc=org" -w admin -b "ou=Group,ou=ActiveMQ,dc=activemq,dc=apache,dc=org" -s sub "(&(objectClass=groupOfNames)(member:=uid=admin))" cn

docker exec openldap ldapsearch -x -H ldap://localhost:389 -b ou=Group,ou=ActiveMQ,dc=activemq,dc=apache,dc=org -s sub "(&(objectClass=groupOfNames)(member:=uid=admin))" -D "cn=admin,dc=activemq,dc=apache,dc=org" -w admin cn

604a5395 conn=1017 fd=12 ACCEPT from IP=172.17.0.1:52720 (IP=0.0.0.0:389)
604a5395 conn=1017 op=0 BIND dn="cn=admin,dc=activemq,dc=apache,dc=org" method=128
604a5395 conn=1017 op=0 BIND dn="cn=admin,dc=activemq,dc=apache,dc=org" mech=SIMPLE ssf=0
604a5395 conn=1017 op=0 RESULT tag=97 err=0 text=
604a5395 conn=1017 op=1 SRCH base="ou=Group,ou=ActiveMQ,dc=activemq,dc=apache,dc=org" scope=2 deref=3 filter="(&(objectClass=groupOfNames)(member:=uid=admin))"
604a5395 conn=1017 op=1 SRCH attr=cn
604a5395 conn=1017 op=1 SEARCH RESULT tag=101 err=0 nentries=1 text=
604a5395 conn=1017 op=2 UNBIND
604a5395 conn=1017 fd=12 closed

./activemq producer --user admin --password adimn --destination TEST --message hello --messageCount 10
```

### Clone and build custom jetty

```shell
git clone git@github.com:eclipse/jetty.project.git
cd jetty.project/
git checkout tags/jetty-9.4.35.v20201120 -b my-jetty-9.4.35.v20201120

```

## RH Opened Issues

* https://issues.jboss.org/browse/ENTESB-9310#
* https://access.redhat.com/support/cases/#/case/02150943

Resolution, KB article:

* https://access.redhat.com/solutions/3600321

## JBoss A-MQ 6.3 Rollup 8 on Karaf

Download and extract jboss-a-mq-6.3.0.redhat-347: https://access.redhat.com/jbossnetwork/restricted/softwareDownload.html?softwareId=59151

## Start dockerized OpenLDAP 2.4.44 with existing ldif data


```bash
cd activemq-ldap-authorization
docker run --rm -d -p 389:389 -v $(PWD)\ldif:/container/service/slapd/assets/config/bootstrap/ldif/custom -e LDAP_DOMAIN=activemq.apache.org -e LDAP_ORGANISATION="Apache ActiveMQ Test Org" -e LDAP_ROOTPASS=admin --name openldap-container osixia/openldap:1.5.0 --copy-service
```

Verify that ldif files are mounted

```bash
docker exec -it openldap-container ls /container/service/slapd/assets/config/bootstrap/ldif/custom
```
