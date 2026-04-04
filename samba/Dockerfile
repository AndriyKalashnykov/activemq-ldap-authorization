FROM ubuntu:24.04

RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install \
      samba krb5-config winbind smbclient \
      iproute2 openssl vim && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN rm -f /etc/krb5.conf
RUN mkdir -p /opt/ad-scripts

WORKDIR /opt/ad-scripts

CMD chmod +x *.sh && ./samba-ad-setup.sh && ./samba-ad-run.sh
