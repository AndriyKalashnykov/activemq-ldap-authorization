#!/usr/bin/env bats
# Unit tests for scripts/lib.sh — the env-var -> config templating logic that
# 5.16.1/init.sh runs at container startup. Sources the REAL lib.sh (never a
# copy) so the production substitution code is what's exercised.

setup() {
  here="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  # shellcheck source=scripts/lib.sh
  source "$here/../scripts/lib.sh"
  tmp="$(mktemp)"
}

teardown() {
  rm -f "$tmp"
}

@test "template_tokens lists each distinct placeholder once" {
  printf 'url=ldap://##### LDAP_HOST #####:##### LDAP_PORT #####\nuser=##### LDAP_HOST #####\n' > "$tmp"
  run template_tokens "$tmp"
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'LDAP_HOST\nLDAP_PORT')" ]
}

@test "apply_template substitutes a set env var" {
  printf 'host=##### LDAP_HOST #####\n' > "$tmp"
  LDAP_HOST=openldap apply_template "$tmp"
  run cat "$tmp"
  [ "$output" = "host=openldap" ]
}

@test "apply_template replaces every occurrence of the same token" {
  printf 'a=##### LDAP_HOST #####\nb=##### LDAP_HOST #####\n' > "$tmp"
  LDAP_HOST=ldaphost apply_template "$tmp"
  run grep -c 'ldaphost' "$tmp"
  [ "$output" = "2" ]
}

@test "apply_template leaves the placeholder when the env var is unset" {
  printf 'host=##### LDAP_HOST #####\n' > "$tmp"
  unset LDAP_HOST
  apply_template "$tmp"
  run cat "$tmp"
  [ "$output" = "host=##### LDAP_HOST #####" ]
}

@test "has_unresolved_placeholders detects a leftover token" {
  printf 'host=##### LDAP_HOST #####\n' > "$tmp"
  run has_unresolved_placeholders "$tmp"
  [ "$status" -eq 0 ]
}

@test "has_unresolved_placeholders passes once all tokens resolved" {
  printf 'host=##### LDAP_HOST #####\n' > "$tmp"
  LDAP_HOST=openldap apply_template "$tmp"
  run has_unresolved_placeholders "$tmp"
  [ "$status" -ne 0 ]
}

@test "flag_enabled is true only for the literal 'yes' (YAML-boolean guard)" {
  run flag_enabled yes
  [ "$status" -eq 0 ]
  run flag_enabled true
  [ "$status" -ne 0 ]
  run flag_enabled ""
  [ "$status" -ne 0 ]
}
