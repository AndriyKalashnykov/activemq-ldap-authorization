# ActiveMQ/AMQ LDAP Authentication and Authorization

## ActiveMQ

```bash
./scripts/install-activemq.sh

# ActiveMQ LDAP Web Console
# https://eleipold.wordpress.com/author/eleipold/ 
# https://www.workhorseintegrations.com/2020/05/14/securing-activemq-console-with-ldap/
# https://github.com/tmielke/abloggerscode/blob/b154059f7df4c87fba26d7e65ad1dbb374a713c3/Articles/Blog/AMQJettyLDAP/jetty.xml



cp /opt/apache-activemq-5.16.1/conf/activemq.xml ~/projects/activemq-ldap-authorization/conf
cp /opt/apache-activemq-5.16.1/conf/jetty.xml ~/projects/activemq-ldap-authorization/conf
cp /opt/apache-activemq-5.16.1/conf/login.config ~/projects/activemq-ldap-authorization/conf
cp /opt/apache-activemq-5.16.1/conf/log4j.properties ~/projects/activemq-ldap-authorization/conf

open http://localhost:8161/admin


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

Create folder for ldif file to be mounted and picked up by OpenLDAP. Start local OpenLDAP sever with provided ldif file by mounting /tmp/ldif

```bash
mkdir /tmp/ldif

cp ./ldif-openldap/activemq-openldap.ldif /tmp/ldif

docker run -d --rm -p 389:389 -v /tmp/ldif:/container/service/slapd/assets/config/bootstrap/ldif/custom -e LDAP_DOMAIN=activemq.apache.org -e LDAP_ORGANISATION="Apache ActiveMQ Test Org" -e LDAP_ROOTPASS=admin --name openldap-container osixia/openldap:1.2.1 --copy-service
```

or

```bash
docker run --rm -d -p 389:389 -v $(PWD)\ldif-openldap:/container/service/slapd/assets/config/bootstrap/ldif/custom -e LDAP_DOMAIN=activemq.apache.org -e LDAP_ORGANISATION="Apache ActiveMQ Test Org" -e LDAP_ROOTPASS=admin --name openldap-container osixia/openldap:1.2.1 --copy-service
```

Verify that ldif files are mounted

```bash
docker exec -it openldap-container ls /container/service/slapd/assets/config/bootstrap/ldif/custom
```
	
### activemq-openldap.ldif

```text
suffix	: "dc=activemq,dc=apache,dc=org"
rootdn	: "cn=admin,dc=activemq,dc=apache,dc=org"
rootpwd	: "admin"

Defined users 
	admin
		dn: "uid=admin,ou=User,ou=ActiveMQ,dc=activemq,dc=apache,dc=org"
		userPassword: "admin"

	client
		dn: "uid=client,ou=User,ou=ActiveMQ,dc=activemq,dc=apache,dc=org"
		userPassword: "admin"
```

### AMQ Config changes
-	
	$AMQ_HOME/etc/activemq.xml 
	-
		
		Provided in attachement.
	
	$AMQ_HOME/etc/system.properties
	-
		# enabled LDAP Authentication
		karaf.admin.role=admin
		hawtio.authenticationEnabled=true
		hawtio.realm=karaf
		hawtio.role=admin
		hawtio.rolePrincipalClasses=org.apache.karaf.jaas.boot.principal.RolePrincipal,org.apache.karaf.jaas.modules.RolePrincipal,org.apache.karaf.jaas.boot.principal.GroupPrincipal
		
	$AMQ_HOME/etc/org.apache.karaf.features.cfg
	-
		Added feature (activemq-camel,camel-spring,camel-ognl) to be available for deployed camelroutes-topic-durable.xml
		
		featuresBoot=config,deployer,cxf-specs,fabric,patch,mq-fabric,war,hawtio-offline,hawtio-redhat-amq-branding,activemq-camel,camel-spring,camel-ognl
	
	
	$AMQ_HOME/deploy/ldap-module.xml
	-
		Provided in attachement.	

	$AMQ_HOME/deploy/camelroutes-topic-durable.xml
	-
	
		Provided in attachement.

