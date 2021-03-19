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

ldapsearch -x -H ldap://localhost:389 -a always -D "cn=admin,dc=activemq,dc=apache,dc=org" -w admin -b "ou=Group,ou=ActiveMQ,dc=activemq,dc=apache,dc=org" -s sub "(&(objectClass=groupOfNames)(member:=uid=admin))" cn

docker exec openldap ldapsearch -x -H ldap://localhost:389 -b ou=Group,ou=ActiveMQ,dc=activemq,dc=apache,dc=org -s sub "(&(objectClass=groupOfNames)(member:=uid=admin))" -D "cn=admin,dc=activemq,dc=apache,dc=org" -w admin cn

# lsof -i:389
# netstat -anp tcp | grep LISTEN | grep 389
# nmap -sT -O localhost | grep 389
```
