# ActiveMQ/AMQ LDAP Authentication and Authorization

## ActiveMQ

```bash
cd /tmp
curl -Lo apache-activemq-5.16.1-bin.tar.gz  https://www.apache.org/dist/activemq/5.16.1/apache-activemq-5.16.1-bin.tar.gz
tar zxvf apache-activemq-5.16.1-bin.tar.gz
sudo mv /tmp/apache-activemq-5.16.1 /opt/
/opt/apache-activemq-5.16.1/bin/activemq start
# sudo useradd activemq

# ActiveMQ LDAP Web Console
# https://eleipold.wordpress.com/author/eleipold/ 
# https://www.workhorseintegrations.com/2020/05/14/securing-activemq-console-with-ldap/

curl -Lo /opt/apache-activemq-5.16.1/lib/jetty-jaas-9.4.35.v20201120.jar https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-jaas/9.4.35.v20201120/jetty-jaas-9.4.35.v20201120.jar

curl -Lo /opt/apache-activemq-5.16.1/lib/jetty-plus-9.4.35.v20201120.jar https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-plus/9.4.35.v20201120/jetty-plus-9.4.35.v20201120.jar

curl -Lo /opt/apache-activemq-5.16.1/lib/jetty-security-9.4.35.v20201120.jar https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-security/9.4.35.v20201120/jetty-security-9.4.35.v20201120.jar

curl -Lo /opt/apache-activemq-5.16.1/lib/ldaptive-1.3.0.jar https://repo1.maven.org/maven2/org/ldaptive/ldaptive/1.3.0/ldaptive-1.3.0.jar

/opt/apache-activemq-5.16.1/bin/activemq start && tail -f /opt/apache-activemq-5.16.1/data/activemq.log

cp /opt/apache-activemq-5.16.1/conf/activemq.xml ~/projects/activemq-ldap-authorization/conf
cp /opt/apache-activemq-5.16.1/conf/jetty.xml ~/projects/activemq-ldap-authorization/conf
cp /opt/apache-activemq-5.16.1/conf/login.config ~/projects/activemq-ldap-authorization/conf
cp /opt/apache-activemq-5.16.1/conf/log4j.properties ~/projects/activemq-ldap-authorization/conf

cp ./conf/activemq.xml /opt/apache-activemq-5.16.1/conf/
cp ./conf/jetty.xml /opt/apache-activemq-5.16.1/conf/
cp ./conf/login.config /opt/apache-activemq-5.16.1/conf/
cp ./conf/log4j.properties /opt/apache-activemq-5.16.1/conf/


open http://localhost:8161/admin

/opt/apache-activemq-5.16.1/bin/activemq stop
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

