# docker-ldap-amq

LDAP authentication in ActiveMQ

OpenLDAP
	
	https://github.com/monodot/docker-slapd
	https://github.com/nickstenning/docker-slapd
	https://github.com/Enalean/docker-ldap
	https://github.com/dariko/docker-openldap-centos
	https://github.com/openshift/openldap
	https://github.com/osixia/docker-openldap

AMQ + LDAP
		
	https://github.com/monodot/ocp-amq-ldap/blob/master/configure.sh

**To run**

OpenLDAP server
---

	Run
	-
		docker run --rm -p 389:389 -v c:\projects\ihg\projects\docker-ldap-amq\ldif-openldap:/container/service/slapd/assets/config/bootstrap/ldif/custom -e LDAP_DOMAIN=activemq.apache.org -e LDAP_ORGANISATION="Apache ActiveMQ Test Org" -e LDAP_ROOTPASS=admin --name openldap-container osixia/openldap:1.5.0 --copy-service
		
		suffix 			: "dc=activemq,dc=apache,dc=org"
		rootdn			: "cn=admin,dc=activemq,dc=apache,dc=org"
		rootpwd			: "admin"

	SSH to LDAP container
	-
			
		docker exec -it openldap-container bash
		
	Add LDIFF schema
	-
	
		ldapadd -h localhost -p 389 -c -x -D cn=admin,dc=activemq,dc=apache,dc=org -w admin -f /var/lib/ldap/ldif/activemq-openldap.ldif	
	
	Search
	-
		
		Non-SSL
		-

			docker exec openldap-container ldapsearch -x -H ldap://localhost -b cn=mqbroker,ou=Services,dc=activemq,dc=apache,dc=org -D "cn=admin,dc=activemq,dc=apache,dc=org" -w admin
			docker exec openldap-container ldapsearch -x -H ldap://localhost -b ou=Group,ou=ActiveMQ,dc=activemq,dc=apache,dc=org -s sub "(member:=uid=admin)" -D "cn=admin,dc=activemq,dc=apache,dc=org" -w admin
			docker exec openldap-container ldapsearch -x -H ldap://localhost -b cn=ActiveMQ.Advisory.$,ou=Topic,ou=Destination,ou=ActiveMQ,dc=activemq,dc=apache,dc=org -s sub "(cn=admin)" -D "cn=admin,dc=activemq,dc=apache,dc=org" -w admin
		
		SSL
		-
		
			docker exec openldap-container ldapsearch -x -H ldaps://localhost:636 -b cn=mqbroker,ou=Services,dc=activemq,dc=apache,dc=org -D "cn=admin,dc=activemq,dc=apache,dc=org" -w admin
	
ApacheDS LDAP server
---
	
	Run
	-
		docker run --rm -d -p 389:10389 -v C:\projects\ihg\projects\docker-ldap-amq\ldif-apacheds:/bootstrap -e BOOTSTRAP_FILE=/bootstrap/apacheds-activemq-legacyGroupMapping-false.ldif --name apacheds-container greggigon/apacheds
		docker run --rm -d -p 389:10389 -v C:\projects\ihg\projects\docker-ldap-amq\ldif-apacheds:/bootstrap --name apacheds-container greggigon/apacheds
		
		principal	: "uid=admin,ou=system"
		rootpw 		: "secret"
		
	SSH to LDAP container
	-

		docker exec -it apacheds-container bash

	Add LDIFF schema
	-
		docker exec apacheds-container ldapadd -x -H ldap://localhost:10389 -D "uid=admin,ou=system" -w secret -f /bootstrap/apacheds-activemq-legacyGroupMapping-false.ldif
		docker exec apacheds-container ldapadd -x -H ldap://localhost:10389 -D "uid=admin,ou=system" -w secret -f /bootstrap/apacheds-activemq-legacyGroupMapping-true.ldif
		
		suffix 		: "ou=ActiveMQ,ou=system"
		rootdn 		: "cn=admin,dc=activemq,dc=apache,dc=org"
		principal	: "uid=admin,ou=system"
		rootpw 		: "secret"
	
	Search
	-		

		docker exec apacheds-container ldapsearch -x -H ldap://localhost:10389 -b ou=Temp,ou=Destination,ou=ActiveMQ,ou=system -D "uid=admin,ou=system" -w secret
		docker exec apacheds-container ldapsearch -x -H ldap://localhost:10389 -b ou=schema -D "uid=admin,ou=system" -w secret
	

	
