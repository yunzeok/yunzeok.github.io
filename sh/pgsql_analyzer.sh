#!/bin/bash

##################
# Utility functions
##################

syno_getopt()
{
	local opt_cmd="$1"
	shift 1

	while getopts "$opt_cmd" opt; do
		if [[ -z "$OPTARG" ]]; then
			eval "opt_${opt}"="-"
		else
			eval "opt_${opt}"="$OPTARG"
		fi
	done
}

cecho()
{
	local color="$1"
	local message="$2"

	local NC='\033[0m'
	local code

	case "$color" in
		red)    code="1;31" ;;
		green)  code="1;32" ;;
		blue)   code="1;34" ;;
		gray)   code="0;37" ;;
		yellow) code="1;33" ;;
		*)      code="1;37" ;;
	esac

	code='\033['$code'm'
	echo "${code}${message}${NC}"
}

errecho()
{
	echo -e "$@" >&2
}

LOG()
{
	local level="$1"
	local message="$2"
	local timestamp="$(date +'%Y-%m-%d %H:%M:%S')"

	# Echo to screen
	local color
	case "$level" in
		"ERROR"|"WARNING") color="red" ;;
		"NOTICE")          color="blue" ;;
		"INFO")          color="green" ;;
		*)                 color="gray" ;;
	esac

	formatted=$(cecho yellow "$timestamp ")$(cecho $color "[$level] $message")
	errecho $formatted

}

log_check_result()
{
	local name="$1"
	local result="$2"

	if [[ "$result" = "true" || "$result" = "0" ]]; then
		LOG INFO "Running $name ... Pass"
		return 0
	else
		LOG WARNING "Running $name ... Error found, please check messages above."
		return 1
	fi
}

db_query()
{
	local db="$1"
	local sql="$2"

	psql -At -F $'\t' -U postgres $db -c "$sql"
}

##################
# Test functions
##################

findfile()
{
	local pattern="$1"
	local path="$2"
	local files="${path} ${path}.1 ${path}.1.xz ${path}.2.xz"
	local limit=20
	local result=false
	local extentsion file msg

	for file in $files; do
		if [[ ! -f "$file" ]]; then
			continue
		fi

		LOG DEBUG "Searching error message from file: $file ..."
		extension="${file##*.}"

		case "$extension" in
			gz)
				msg="$(zcat "$file" | grep "$pattern" | tail -n $limit)"
				;;
			xz)
				msg="$(xzcat "$file" | grep "$pattern" | tail -n $limit)"
				;;
			*)
				msg="$(cat "$file" | grep "$pattern" | tail -n $limit)"
				;;
		esac

		if [[ -n "$msg" ]]; then
			result=true
			echo "$msg"
			break
		fi
	done

	$result && return 0 || return 1
}

has_permission()
{
	local path="$1"
	local permission="$2"
	local user="$3"
	local group="$4"
	local result=true
	local re f_permission f_user f_group

	# Check path exists
	if [[ ! -e "$path" ]]; then
		LOG ERROR "File or directory does not exists: $path"
		return 1
	fi

	# Check path permission
	if [[ -n "$permission" ]]; then
		re="${permission//-/.}"
		f_permission="$(stat -c "%A" "$path")"

		if [[ ! "$f_permission" =~ $re ]]; then
			LOG ERROR "Permission $permission is not match, path: $path, permission: $f_permission"
			result=false
		fi
	fi

	# Check path user
	if [[ -n "$user" ]]; then
		f_user="$(stat -c "%U" "$path")"

		if [[ "$f_user" != "$user" ]]; then
			LOG ERROR "User $user is not match, path: $path, user: $f_user"
			result=false
		fi
	fi

	# Check path group
	if [[ -n "$group" ]]; then
		f_group="$(stat -c "%G" "$path")"

		if [[ "$f_group" != "$group" ]]; then
			LOG ERROR "Group $group is not match, path: $path, user: $f_group"
			result=false
		fi
	fi

	$result && return 0 || return 1
}

##################
# Test cases
##################


disklog_check()
{
	local files="/var/log/dmesg /var/log/messages"
	local result=true
	local file

	for file in $files; do
		if findfile "exception Emask\|status: {\|error: {\|SError: {" "$file"; then
			LOG ERROR "Disk error(s) are found in $file"
			result=false
		fi
	done

	for file in $files; do
		if findfile "EXT4-fs .*: error\|EXT4-fs error\|EXT4-fs warning\|read error corrected" "$file"; then
			LOG ERROR "Disk ext-4 error(s) are found in $file"
			result=false
		fi
	done

	log_check_result disklog_check $result
}

tune2fs_check()
{
	local devs="/dev/md0 /dev/sda1 $(cut -d ' ' -f 1 /run/synostorage/volumetab)"
	local result=true
	local dev

	for dev in $devs; do
		if tune2fs -l "$dev" 2> /dev/null | grep "FS Error"; then
			LOG ERROR "Filesystem error(s) are found in tune2fs -l $dev"
			result=false
		fi
	done

	log_check_result tune2fs_check $result
}

permission_check()
{
	# Check directory permission
	local volume="$(servicetool --get-service-volume pgsql)"
	local result=true

	has_permission "$volume"                          drwxr-xr-x                   || result=false
	has_permission "${volume}/@database"              drwxr-xr-x admin    users    || result=false
	has_permission "${volume}/@database/pgsql"        drwx------ postgres postgres || result=false

	log_check_result permission_check $result
}

user_check()
{
	# Check root user name and postgres entry point
	local count
	local result=true

	# Check root name
	count=$(cat /etc/passwd | grep -c ':x:0:0:')

	if [[ "$count" -ne 1 ]]; then
		LOG ERROR "User: root has $count rows in /etc/passwd"
		result=false
	fi

	if ! cat /etc/passwd | grep 'root:x:0:0:' > /dev/null 2>&1; then
		LOG ERROR "User: root is not found in /etc/passwd"
		result=false
	fi

	# Check postgres entry point
	count=$(cat /etc/passwd | grep -c 'postgres')
	if [[ "$count" -ne 1 ]]; then
		LOG ERROR "User: postgres has $count rows in /etc/passwd"
		result=false
	fi

	if ! cat /etc/passwd | grep postgres | grep '/var/services/pgsql:/bin/sh' > /dev/nuill 2>&1; then
		LOG ERROR "User: postgres entry point(/var/services/pgsql:/bin/sh) has been modified"
		result=false
	fi

	log_check_result user_check $result
}

pglog_check()
{
	local result=true
	if findfile "FATAL" "/var/log/postgresql.log"; then
		LOG ERROR "Fatal error(s) are found in postgresql log"
		result=false
	fi

	log_check_result pglog_check $result
}

volume_check()
{
	local volume="$(servicetool --get-service-volume pgsql)"
	local result=true
	local avail

	if ! df -BG | grep -q "$volume"; then
		LOG WARNING "Failed to parse volume size, Please check available space of volume manually"
		log_check_result volume_check false
		return
	fi

	# Get available volume space in Gigabytes
	avail=$(df -BG | grep "$volume" | awk '{print $4}' | sed 's/G//g')

	if ((avail <= 1)); then
		LOG ERROR "Available volume space is smaller than 1GB"
		result=false
	fi

	log_check_result volume_check $result
}

calendar_check()
{
	local result=true
	local answer=n

	if tail -n 20 /var/log/postgresql.log | grep '/tmp/synocalendar'; then
		result=false
		read -p "Hit Calendar bug, missing directory: /tmp/synocalendar. Do you want to fix it? (Y/n):" answer
		echo ""

		if [[ -z "$answer" || "$answer" = "Y" || "$answer" = "y" ]]; then
			LOG INFO "Directory created: /tmp/synocalendar. Restart pgsql manullay later ('synoservice --restart pgsql' on DSM6, '/usr/syno/bin/synosystemctl restart pgsql-adapter' on DSM7)."
			mkdir /tmp/synocalendar
			chown postgres:postgres /tmp/synocalendar
		fi
	fi

	log_check_result calendar_check $result
}

##### Main and help function

rebuild_database()
{
	local volume="$(servicetool --get-service-volume pgsql)"
	local path="${volume}/@database/pgsql"
	local dsm_version=`synogetkeyvalue /etc.defaults/VERSION major`

	LOG INFO "Rebuilding database ..."
	
	if [[ "$dsm_version" = "7" ]]; then
		if ! /usr/syno/bin/synosystemctl stop-service-by-reason rebuild pgsql-adapter; then
			LOG ERROR "Failed to stop pgsql"
			return 1
		fi
	else
		if ! synoservice --pause-by-reason pgsql rebuild; then
			LOG ERROR "Failed to stop pgsql"
			return 1
		fi
	fi

	BACKUP_PATH=${path}-$(date -u +"%Y%m%dT%H%M%SZ")
	mv "$path" "$BACKUP_PATH"
	LOG INFO "Backup Success: $BACKUP_PATH"
	rm /var/services/pgsql

	if ! servicetool --set-pgsql; then
		LOG ERROR "Failed to create psgql directory"
		return 1
	fi

	if [[ "$dsm_version" = "7" ]]; then
		if ! /usr/syno/bin/synosystemctl start-service-by-reason rebuild pgsql-adapter; then
			LOG ERROR "Failed to start pgsql"
			return 1
		fi
	else
		if ! synoservice --resume-by-reason pgsql rebuild; then
			LOG ERROR "Failed to start pgsql"
			return 1
		fi
	fi
	LOG INFO "Rebuild done."
}

vacuum_all()
{
	local result=true

	##### List all databases
	dbs="$(db_query postgres 'SELECT datname FROM pg_database WHERE datistemplate = false')"
	echo "Database list: $dbs"


	##### Vaccum
	for db in $dbs; do
		# Skip large size database
		if [[ "$db" = "synoips" ]]; then
			LOG DEBUG "Skip to vacuum $db"
			continue
		fi

		LOG DEBUG "Vacuuming $db"
		if ! db_query $db "VACUUM FULL"; then
			LOG WARNING "Failed to vacuum $db"
			result=false
		fi
	done

	log_check_result vacuum_all $result
}

recreate_database()
{
	local package="$1"
	local db=$(cat /var/packages/${package}/conf/resource | jq -r '.["pgsql-db"]["create-database"][0]["db-name"]')
	local db_tmp="${db}_$(date +'%Y%m%d%H%M%S')"

	if ! db_query postgres "ALTER DATABASE $db RENAME TO $db_tmp"; then
		LOG ERROR "Failed to rename database from $db to $db_tmp"
		return 1
	fi

	if ! synopkghelper update $package pgsql-db; then
		LOG ERROR "Failed to create database for package: $package"
		return 1
	fi
}


show_usage()
{
	cat << EOF
Description:
	Analysis pgsql issues
Usage:
	$0 [options]

Options:
	-h            Show this help
	-r            Rebuild pgsql database
	-d <package>  Recreate database
	-v            Vacuum all databases (exluding synoips)

EOF
}

main()
{
	syno_getopt "hvrd:" "$@"
	shift $((OPTIND-1))

	if [[ -n "$opt_h" ]]; then
		show_usage
		return
	fi

	##### Rebuild database
	if [[ -n "$opt_r" ]]; then
		rebuild_database
		return $?
	fi

	##### Vacuum every databases
	if [[ -n "$opt_v" ]]; then
		vacuum_all
		return $?
	fi


	##### Recreate database for package
	if [[ -n "$opt_d" ]]; then
		recreate_database "$opt_d"
		return $?
	fi

	##### Check
	pglog_check
	disklog_check
	tune2fs_check
	permission_check
	user_check
	volume_check
	calendar_check
}

main "$@"
