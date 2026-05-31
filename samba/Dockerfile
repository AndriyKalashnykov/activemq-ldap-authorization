FROM ubuntu:26.04

# Ubuntu 26.04 stopped pulling the AD-DC pieces in as `samba` dependencies
# (they were transitively installed on 24.04), so each is named explicitly:
#   - samba-ad-dc        : the AD Domain Controller daemon (/usr/sbin/samba)
#     and control files — else "samba: command not found" at DC startup.
#   - samba-ad-provision : AD DS schema (ad-schema/*.ldf) for `samba-tool
#     domain provision` — else "AD_DS_Attributes_Windows_Server_v1903.ldf not found".
#   - samba-dsdb-modules : the DSDB ldb modules (encrypted_secrets, descriptor,
#     password_hash, repl_meta_data, …) — else "Unable to load modules for
#     secrets.ldb" during provisioning. (Also a samba-ad-dc dependency.)
#   - samba-vfs-modules  : VFS modules the DC uses to serve sysvol/netlogon.
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install \
      samba samba-ad-dc samba-ad-provision samba-dsdb-modules samba-vfs-modules \
      krb5-config winbind smbclient ldap-utils \
      iproute2 openssl vim && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Remove Canonical's `pebble` service-manager binary baked into the ubuntu:26.04
# base (~10 MB Go binary, not apt-managed). The DC is launched via the CMD
# below, never via pebble, so it is dead weight carrying 8 HIGH Go-stdlib CVEs.
RUN rm -f /usr/bin/pebble && rm -f /etc/krb5.conf && mkdir -p /opt/ad-scripts

WORKDIR /opt/ad-scripts

CMD ["/bin/bash", "-c", "chmod +x *.sh && ./samba-ad-setup.sh && ./samba-ad-run.sh"]
