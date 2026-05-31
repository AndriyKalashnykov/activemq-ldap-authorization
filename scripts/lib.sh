#!/usr/bin/env bash
# Sourceable helper library — pure functions only, NO top-level side effects.
# Sourced by e2e/*.sh and unit-tested directly by tests/templating.bats.
#
# These functions model the env-var -> config templating that 5.16.1/init.sh
# performs at container startup (replacing `##### VAR #####` tokens with the
# value of the matching environment variable). Extracting them here makes the
# substitution logic unit-testable without spinning up a container.

# template_tokens <file>
# Print every distinct `VAR` named by a `##### VAR #####` placeholder in <file>.
template_tokens() {
  local file="$1"
  grep -oE '##### [A-Z_]+ #####' "$file" 2>/dev/null \
    | sed -E 's/##### (.+) #####/\1/' \
    | sort -u
}

# apply_template <file>
# In place, replace each `##### VAR #####` token with the value of the
# environment variable VAR, but ONLY when VAR is set (matching init.sh, which
# guards every substitution with `if [ ! -z "$VAR" ]`). An unset variable
# leaves its placeholder untouched — by design, so has_unresolved_placeholders
# can flag a missing-config mistake.
apply_template() {
  local file="$1" var val
  while IFS= read -r var; do
    [ -z "$var" ] && continue
    if [ -n "${!var+set}" ]; then
      val="${!var}"
      # `|` delimiter mirrors init.sh; values here are DNs/hosts/ports, no `|`.
      sed -i "s|##### ${var} #####|${val}|g" "$file"
    fi
  done < <(template_tokens "$file")
}

# has_unresolved_placeholders <file>
# Return 0 (success) if any `##### ... #####` placeholder remains in <file>.
# Used by the e2e harness to assert the live broker config was fully resolved.
has_unresolved_placeholders() {
  grep -q '#####' "$1"
}

# flag_enabled <value>
# Opt-in predicate: true only for the literal string "yes". Documents the flag
# convention at the predicate end and avoids the YAML-boolean coercion trap
# (an unquoted `true` is a boolean, not the string "yes").
flag_enabled() {
  [ "${1:-no}" = "yes" ]
}
