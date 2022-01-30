# This package provides a simple client around Vault to read approle token IDs
# and response-wrapped secrets.

{ pkgs }:

let
  defaultArgs = "-format=json -ca-cert=${../config/certificate.pem}";
  vault = "${pkgs.vault}/bin/vault";
  jq = "${pkgs.jq}/bin/jq";

in pkgs.writeShellScriptBin "vault-client" ''
  set -eo pipefail

  function assert_role {
    if [[ -z "$2" ]]; then
      echo "$1 requires a role name argument." >&2
      exit 1
    fi
  }

  if (( $# < 1 )); then
    echo "vault-client requires a command." >&2
    exit 1
  fi

  case "$1" in
    "role-id")
      assert_role "role-id" "$2"
      ${vault} read ${defaultArgs} auth/approle/role/"$2"/role-id \
        | ${jq} -r .data.role_id
      ;;

    "role-token")
      assert_role "role-token" "$2"
      ${vault} write -force -wrap-ttl=5m ${defaultArgs} auth/approle/role/"$2"/secret-id \
        | ${jq} -r .wrap_info.token
      ;;

    *)
      echo "Unknown command: $1" >&2
      exit 1
      ;;
  esac
''
