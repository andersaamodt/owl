#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
engine_root="$repo_root/mail-engine"
engine_backend="$engine_root/scripts/owl-desktop-backend.sh"

[ -f "$engine_root/Cargo.toml" ] || {
  printf '%s\n' "stellar-mail-backend: bundled mail engine source is missing" >&2
  exit 1
}

export OWL_BUILD_STATE_ROOT="${STELLAR_MAIL_ENGINE_BUILD_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/stellar/mail-engine}"

if [ -n "${STELLAR_MAIL_ENGINE_BIN-}" ]; then
  export OWL_BIN="$STELLAR_MAIL_ENGINE_BIN"
elif [ -x "$repo_root/libexec/stellar-mail/owl" ]; then
  export OWL_BIN="$repo_root/libexec/stellar-mail/owl"
fi

action=${1-}
root=${2-}

addresses_file() {
  printf '%s\n' "$root/.stellar/mail-addresses.json"
}

mail_domain() {
  env_file="$root/.env"
  [ -f "$env_file" ] || return 0
  smtp_host=$(awk -F= '
    tolower($1) == "smtp_host" {
      value = substr($0, index($0, "=") + 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      print tolower(value)
      exit
    }
  ' "$env_file")
  case "$smtp_host" in
    smtp.*) printf '%s\n' "${smtp_host#smtp.}" ;;
    127.0.0.1|localhost|'') ;;
    *) printf '%s\n' "$smtp_host" ;;
  esac
}

default_addresses_json() {
  jq -cn '{schema:"stellar-addresses/v1",catch_all:false,aliases:[]}'
}

load_addresses_json() {
  file=$(addresses_file)
  if [ ! -f "$file" ]; then
    default_addresses_json
    return
  fi
  jq -ce '
    select(
      .schema == "stellar-addresses/v1" and
      (.catch_all | type) == "boolean" and
      (.aliases | type) == "array" and
      (.aliases | all(
        (.local_part | type) == "string" and
        (.label | type) == "string" and
        (.forwards | type) == "array" and
        (.forwards | all(.[]; type == "string")) and
        (.enabled | type) == "boolean"
      ))
    )
  ' "$file" 2>/dev/null || {
    printf '%s\n' "stellar-mail-backend: invalid address configuration: $file" >&2
    return 1
  }
}

save_addresses_json() {
  config=$1
  file=$(addresses_file)
  mkdir -p "$(dirname "$file")"
  tmp=$(mktemp "$(dirname "$file")/.mail-addresses.XXXXXX")
  printf '%s\n' "$config" | jq -S . >"$tmp"
  chmod 0600 "$tmp"
  mv "$tmp" "$file"
}

valid_local_part() {
  printf '%s\n' "$1" | jq -Rse '
    gsub("[\\r\\n]"; "") as $value
    | ($value | length) > 0 and
      ($value | length) <= 64 and
      ($value | test("^[a-z0-9.!#$%&*+/=?^_`{|}~-]+$")) and
      (($value | startswith(".")) | not) and
      (($value | endswith(".")) | not) and
      (($value | contains("..")) | not)
  ' | grep -qx true
}

normalize_local_part() {
  value=$(printf '%s' "${1-}" | tr '[:upper:]' '[:lower:]' | tr -d '\r\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  case "$value" in
    *@*)
      supplied_domain=${value##*@}
      configured_domain=$(mail_domain)
      if [ -n "$configured_domain" ] && [ "$supplied_domain" != "$configured_domain" ]; then
        printf '%s\n' "stellar-mail-backend: receiving addresses must use @$configured_domain" >&2
        return 1
      fi
      value=${value%@*}
      ;;
  esac
  valid_local_part "$value" || {
    printf '%s\n' "stellar-mail-backend: use a valid email name such as me, work, or receipts" >&2
    return 1
  }
  [ "$value" != postmaster ] || {
    printf '%s\n' "stellar-mail-backend: postmaster is a built-in address" >&2
    return 1
  }
  printf '%s\n' "$value"
}

forwarding_json() {
  raw=${1-}
  printf '%s' "$raw" | jq -Rsce '
    split(",")
    | map(ascii_downcase | gsub("^\\s+|\\s+$"; ""))
    | map(select(length > 0))
    | if all(test("^[a-z0-9.!#$%&*+/=?^_`{|}~-]+@[a-z0-9.-]+\\.[a-z]{2,}$"))
      then unique
      else error("invalid forwarding address")
      end
  ' 2>/dev/null || {
    printf '%s\n' "stellar-mail-backend: forwarding destinations must be complete email addresses" >&2
    return 1
  }
}

address_list_json() {
  config=$(load_addresses_json)
  domain=$(mail_domain)
  catch_all=$(printf '%s\n' "$config" | jq -c '.catch_all')
  printf '%s\n' "$config" | jq -c \
    --arg domain "$domain" \
    --argjson catch_all "$catch_all" '
      .aliases
      | map(. + {
          address:(if $domain == "" then .local_part else (.local_part + "@" + $domain) end),
          destination:"Stellar Inbox",
          system:false
        })
      | ([{
          local_part:"postmaster",
          address:(if $domain == "" then "postmaster" else ("postmaster@" + $domain) end),
          label:"Postmaster",
          forwards:[],
          enabled:true,
          destination:"Stellar Inbox",
          system:true
        }] + .) as $addresses
      | {
          ok:true,
          schema:"stellar-address-list/v1",
          domain:$domain,
          catch_all:$catch_all,
          addresses:$addresses
        }
    '
}

address_routes_text() {
  domain=$(mail_domain)
  [ -n "$domain" ] || {
    printf '%s\n' "stellar-mail-backend: configure the email domain before publishing addresses" >&2
    return 1
  }
  config=$(load_addresses_json)
  printf '%s\n' "$config" | jq -r --arg domain "$domain" '
    def destination:
      (["stellar-inbox@localhost"] + .forwards) | join(",");
    ["postmaster@" + $domain + " stellar-inbox@localhost"] +
    [
      .aliases[]
      | select(.enabled == true)
      | (.local_part + "@" + $domain + " " + destination)
    ] +
    (if .catch_all then ["@" + $domain + " stellar-inbox@localhost"] else [] end)
    | .[]
  '
}

base64_one_line() {
  base64 | tr -d '\r\n'
}

case "$action" in
  address-list)
    address_list_json
    ;;
  address-save)
    domain=$(mail_domain)
    [ -n "$domain" ] || {
      printf '%s\n' "stellar-mail-backend: configure the email domain before creating addresses" >&2
      exit 2
    }
    local_part=$(normalize_local_part "${3-}") || exit 2
    label=$(printf '%s' "${4-}" | tr -d '\r\n')
    forwards=$(forwarding_json "${5-}") || exit 2
    case "${6-on}" in
      on|true|1|yes) enabled=true ;;
      *) enabled=false ;;
    esac
    full_address="$local_part@$domain"
    if printf '%s\n' "$forwards" | jq -e --arg address "$full_address" 'index($address) != null' >/dev/null; then
      printf '%s\n' "stellar-mail-backend: an address cannot forward to itself" >&2
      exit 2
    fi
    config=$(load_addresses_json)
    updated=$(printf '%s\n' "$config" | jq -c \
      --arg local_part "$local_part" \
      --arg label "$label" \
      --argjson forwards "$forwards" \
      --argjson enabled "$enabled" '
        .aliases = (
          [.aliases[] | select(.local_part != $local_part)] +
          [{local_part:$local_part,label:$label,forwards:$forwards,enabled:$enabled}]
          | sort_by(.local_part)
        )
      ')
    save_addresses_json "$updated"
    address_list_json
    ;;
  address-delete)
    local_part=$(normalize_local_part "${3-}") || exit 2
    config=$(load_addresses_json)
    updated=$(printf '%s\n' "$config" | jq -c --arg local_part "$local_part" '
      .aliases = [.aliases[] | select(.local_part != $local_part)]
    ')
    save_addresses_json "$updated"
    address_list_json
    ;;
  address-set-catch-all)
    case "${3-off}" in
      on|true|1|yes) catch_all=true ;;
      off|false|0|no) catch_all=false ;;
      *)
        printf '%s\n' "stellar-mail-backend: address-set-catch-all requires on or off" >&2
        exit 2
        ;;
    esac
    config=$(load_addresses_json)
    updated=$(printf '%s\n' "$config" | jq -c --argjson catch_all "$catch_all" '.catch_all=$catch_all')
    save_addresses_json "$updated"
    address_list_json
    ;;
  address-routing-plan)
    routes=$(address_routes_text)
    printf '%s\n' "$routes" | jq -Rsc '
      split("\n") | map(select(length > 0))
      | {ok:true,schema:"stellar-address-routing-plan/v1",postfix_map:.}
    '
    ;;
  settings-controls)
    settings=$(sh "$engine_backend" "$@")
    addresses=$(address_list_json)
    printf '%s\n' "$settings" | jq -c --argjson addresses "$addresses" '. + {addresses:$addresses}'
    ;;
  settings-remote-deploy|address-publish)
    export STELLAR_ADDRESS_ROUTES_B64=$(address_routes_text | base64_one_line)
    exec sh "$engine_backend" "$@"
    ;;
  *)
    exec sh "$engine_backend" "$@"
    ;;
esac
