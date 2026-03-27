#!/bin/bash

[[ "${BASH_SOURCE[0]}" = "$0" ]] && set -e


[[ "${BASH_SOURCE[0]}" = "$0" ]] || return 0

_init_globals() { 
  declare -g ODOO_RC="${ODOO_RC:-/etc/odoo/odoo.conf}"
  declare -g ODOO_RUNTIME="${ODOO_RUNTIME:-/var/lib/odoo/runtime.conf}"
  declare -g PASSWORD_FILE  # obsolete
  declare -g -A DB_PARMS
}

_init() { 
  _init_globals
  _load_db_parms_from_file "$ODOO_RC"
  _load_db_parms_from_file "$ODOO_RUNTIME"
  _load_db_parms_from_env
  # if PASSWORD_FILE is specified, it overrides previous settings
  _load_db_password_from_file "$PASSWORD_FILE"
}

_load_password_file() { 
: <<'END_DESCRIPTION'
	load the database password from the specified file
	
END_DESCRIPTION
	[[ "$1" ]] || return 0
	if ! [[ -r "$1" ]]; then
	    echo >&2 "[WARNING] Password file $1 does not exist. Ignoring."
            return 0
        elif ! [[ -s "$1" ]]; then
	    echo >&2 "[WARNING] Password file $1 is empty. Ignoring."
            return 0
        else
	    DB_PARMS[db_password]="$(< "$1")"
	fi
}

_load_db_parms_from_env() { 
	# set the postgres database host, port, user and password according to the environment
	# Passing on command-line is inherently unsafe
        # Do not overwrite existing variables
	: ${DB_PARMS[db_host]:="${DB_HOST:-db}"}
	: ${DB_PARMS[db_port]:="${DB_PORT:-5432}"}
	: ${DB_PARMS[db_user]:="${USER:-${DB_ENV_POSTGRES_USER:-${POSTGRES_USER:-'odoo'}}}"}
	: ${DB_PARMS[db_name]:="${DB_ENV_POSTGRES_DBNAME:-${POSTGRES_DBNAME:-'odoo'}}"}
	: ${DB_PARMS[db_password]:="${PASSWORD:-${DB_ENV_POSTGRES_PASSWORD:-${POSTGRES_PASSWORD:-'odoo'}}}"}
}

DB_ARGS=()
function check_config() {
    param="$1"
    value="$2"
    if grep -q -E "^\s*\b${param}\b\s*=" "$ODOO_RC" ; then       
        value=$(grep -E "^\s*\b${param}\b\s*=" "$ODOO_RC" |cut -d " " -f3|sed 's/["\n\r]//g')
    fi;
    DB_ARGS+=("--${param}")
    DB_ARGS+=("${value}")
}
check_config "db_host" "$HOST"
check_config "db_port" "$PORT"
check_config "db_user" "$USER"
check_config "db_password" "$PASSWORD"

case "${1---}" in
    -- | odoo)
        shift
        if [[ "$1" == "scaffold" ]] ; then
            exec odoo "$@"
        else
            wait_for_psql ${DB_ARGS[@]} --timeout=30
            exec odoo "$@" "${DB_ARGS[@]}"
        fi
        ;;
    -*)
        wait_for_psql ${DB_ARGS[@]} --timeout=30
        exec odoo "$@" "${DB_ARGS[@]}"
        ;;
    *)
        exec "$@"
esac

exit 1
