#! /bin/bash


#######################################
#
# 	Функция возврата IP-адреса репозитория из БД по входному хостнейму
#
#	Входные параметры:
#
#   Строка, содержащая хостнейм
#
#	Возвращаемое значение:
#
#	переменная 'DB_REPO_IP_ADDRESS'
#
#######################################

DB_REPO_IP_ADDRESS=""
function db_get_repo_ip() {
	local user_hostname="$1"
	local json_db="./db/repository.json"
	local ip=$(jq -r ".repositories[] | \
		select(.contur_data.SVTs[].hostname == \"$user_hostname\") | \
		.contur_data.remote_repo" $json_db)

	DB_REPO_IP_ADDRESS="$ip"
}


#######################################
#
# 	Функция возврата списка основных репозиториев из БД по входному хостнейму
#
#	Входные параметры:
#
#   Строка, содержащая хостнейм
#
#	Возвращаемое значение:
#
#	переменная 'DB_REPO_MAIN_LIST'
#
#######################################

DB_REPO_MAIN_LIST=""
function db_get_repo_main() {
	local user_hostname="$1"
	local json_db="./db/repository.json"

	local mainrepo_count=$(jq ".repositories[] | \
		select(.contur_data.SVTs[].hostname == \"$user_hostname\") | \
		.contur_data.main | length" $json_file)

	local path=""
	local os=""
	local pools=""

	for (( repo_idx = 0; repo_idx < mainrepo_count ; repo_idx++ )); do
		path=$(jq -r ".repositories[] | \
			select(.contur_data.SVTs[].hostname == \"$user_hostname\") | \
			.contur_data.main[${repo_idx}].path" $json_file)
		os=$(jq -r ".repositories[] | \
			select(.contur_data.SVTs[].hostname == \"$user_hostname\") | \
			.contur_data.main[${repo_idx}].os" $json_file)
		pools=$(jq -r ".repositories[] | \
			select(.contur_data.SVTs[].hostname == \"$user_hostname\") | \
			.contur_data.main[${repo_idx}].pools | \
			@sh" $json_file | tr -d \')

		DB_REPO_MAIN_LIST+="$path|$os|$pools;"
	done
}


#######################################
#
# 	Функция возврата IP-адреса из БД по входному хостнейму
#
#	Входные параметры:
#
#   Строка, содержащая хостнейм
#
#	Возвращаемое значение:
#
#	переменная 'DB_IP_ADDRESS'
#
#######################################

DB_IP_ADDRESS=""
function db_get_ip_address() {
	local user_hostname="$1"
	local json_db="./db/device_info.json"
	local ip=$(jq -r ".devices_info[].contur_data.device_types[].devices_list[] | \
		select(.hostname == \"$user_hostname\") | \
		.network_module.interfaces[].interface_data.ip" $json_db)

	DB_IP_ADDRESS="$ip"
}


#######################################
#
# 	Функция возврата маски подсети из БД по входному хостнейму
#
#	Входные параметры:
#
#   Строка, содержащая хостнейм
#
#	Возвращаемое значение:
#
#	переменная 'DB_NETMASK'
#
#######################################

DB_NETMASK=""
function db_get_netmask() {
	local user_hostname="$1"
	local json_db="./db/device_info.json"
	local netmask=$(jq -r ".devices_info[].contur_data.device_types[].devices_list[] | \
		select(.hostname == \"$user_hostname\") | \
		.network_module.interfaces[].interface_data.netmask" $json_db)

	DB_NETMASK="$netmask"
}


#######################################
#
# 	Функция возврата шлюза по умолчанию из БД по входному хостнейму
#
#	Входные параметры:
#
#   Строка, содержащая хостнейм
#
#	Возвращаемое значение:
#
#	переменная 'DB_GATEWAY'
#
#######################################

DB_GATEWAY=""
function db_get_gateway() {
	local user_hostname="$1"
	local json_db="./db/device_info.json"
	local gateway=$(jq -r ".devices_info[].contur_data.device_types[].devices_list[] | \
		select(.hostname == \"$user_hostname\") | \
		.network_module.interfaces[].interface_data.gateway" $json_db)

	DB_GATEWAY="$gateway"
}


#######################################
#
# 	Функция возврата сети из БД по входному хостнейму
#
#	Входные параметры:
#
#   Строка, содержащая хостнейм
#
#	Возвращаемое значение:
#
#	переменная 'DB_NETWORK'
#
#######################################

DB_NETWORK=""
function db_get_network() {
	local user_hostname="$1"
	local json_db="./db/device_info.json"
	local network=$(jq -r ".devices_info[].contur_data.device_types[].devices_list[] | \
		select(.hostname == \"$user_hostname\") | \
		.network_module.interfaces[].interface_data.network" $json_db)

	DB_NETWORK="$network"
}


#######################################
#
# 	Функция возврата статического интерфейса из БД по входному хостнейму
#
#	Входные параметры:
#
#   Строка, содержащая хостнейм
#
#	Возвращаемое значение:
#
#	переменная 'DB_ETH'
#
#######################################

DB_ETH=""
function db_get_static_eth() {
	local user_hostname="$1"
	local json_db="./db/device_info.json"
	local eth=$(jq -r ".devices_info[].contur_data.device_types[].devices_list[] | \
		select(.hostname == \"$user_hostname\") | \
		.network_module.interfaces[].name" $json_db)

	DB_ETH="$eth"
}


#######################################
#
# 	Проверка из БД существует-ли хостнейм 
#
#	Входные параметры:
#
#   Строка, содержащая хостнейм
#
#	Коды возвратов:
#
#	0 - хостнейм существует
#	1 - хостнейм не существует
#
#######################################

function db_is_hostname_exists() {
	local user_hostname="$1"
	local json_db="./db/device_info.json"
	local returned_hostname=$(jq -r ".devices_info[].contur_data.device_types[].devices_list[] | \
		select(.hostname == \"$user_hostname\")" $json_db)

	if [ -z "$returned_hostname" ]; then
		return 1
	fi

	return 0

}


#######################################
#
# 	Функция возврата типа СВТ из БД по входному хостнейму
#
#	Входные параметры:
#
#   Строка, содержащая хостнейм
#
#	Возвращаемое значение:
#
#	переменная 'DB_SERVER_TYPE'
#
#######################################

DB_SERVER_TYPE=""
function db_get_server_type() {
	local user_hostname="$1"
	local json_db="./db/device_info.json"
	local server_type=$(jq -r ".devices_info[].contur_data.device_types[] | \
		select(.devices_list[].hostname == \"$user_hostname\") | \
		.device_type" $json_db)

	DB_SERVER_TYPE="$server_type"
}


#######################################
#
# 	Проверка из БД является-ли хостнейм bonding серверов 
#
#	Входные параметры:
#
#   Строка, содержащая хостнейм
#
#	Коды возвратов:
#
#	0 - является bonding
#	1 - не является bonding
#
#######################################

function db_is_hostname_bonding() {
	local user_hostname="$1"
	local json_db="./db/device_info.json"
	local interface_type=$(jq -r ".devices_info[].contur_data.device_types[].devices_list[] | \
		select(.hostname == \"$user_hostname\") | \
		.network_module.interfaces[].interface_data.type" $json_db)

	if ! echo "$interface_type" | grep "^bonding$" >/dev/null; then
		return 1
	fi

	return 0
}


#######################################
#
# 	Функция возврата списка slaves bonding из БД по входному хостнейму
#
#	Входные параметры:
#
#   Строка, содержащая хостнейм
#
#	Возвращаемое значение:
#
#	переменная 'DB_BONDING_SLAVES'
#
#######################################

DB_BONDING_SLAVES=""
function db_get_bonding_slaves() {
	local user_hostname="$1"
	local json_db="./db/device_info.json"
	local bonding_slaves=$(jq -r ".devices_info[].contur_data.device_types[].devices_list[] | \
		select(.hostname == \"$user_hostname\") | \
		.network_module.interfaces[].interface_data.slaves[].name" $json_db)

	DB_BONDING_SLAVES=""

	OLD_IFS=$IFS
	IFS=$'\n'
	for bonding_slave in $bonding_slaves; do
		DB_BONDING_SLAVES+="$bonding_slave "
	done
	IFS=$OLD_IFS
}


#######################################
#
# 	Функция возврата списка dns серверов из БД по входному хостнейму
#
#	Входные параметры:
#
#   Строка, содержащая хостнейм
#
#	Возвращаемое значение:
#
#	переменная 'DB_DNS_SERVERS'
#
#######################################

DB_DNS_SERVERS=""
function db_get_dns_servers() {
	local user_hostname="$1"
	local json_db="./db/device_info.json"
	local dns_servers=$(jq -r ".devices_info[].contur_data.device_types[].devices_list[] | \
		select(.hostname == \"$user_hostname\") | \
		.network_module.dns_servers[].ip" $json_db)

	DB_DNS_SERVERS=""

	OLD_IFS=$IFS
	IFS=$'\n'
	for dns_server in $dns_servers; do
		DB_DNS_SERVERS+="$dns_server "
	done
	IFS=$OLD_IFS
}


#######################################
#
# 	Функция возврата списка ntp серверов из БД по входному хостнейму
#
#	Входные параметры:
#
#   Строка, содержащая хостнейм
#
#	Возвращаемое значение:
#
#	переменная 'DB_NTP_SERVERS'
#
#######################################

DB_NTP_SERVERS=""
function db_get_ntp_servers() {
	local user_hostname="$1"
	local json_db="./db/device_info.json"
	local ntp_servers=$(jq -r ".devices_info[].contur_data.device_types[].devices_list[] | \
		select(.hostname == \"$user_hostname\") | \
		.ntp_servers[].ip" $json_db)

	DB_NTP_SERVERS=""

	OLD_IFS=$IFS
	IFS=$'\n'
	for ntp_server in $ntp_servers; do
		DB_NTP_SERVERS+="$ntp_server "
	done
	IFS=$OLD_IFS
}


function db_is_IB_owner() {
	local user_hostname="$1"
	local json_db="./db/device_info.json"

	local IB_owner=$(jq -r ".devices_info[].contur_data.device_types[] | \
		select(.devices_list[].hostname == \"$user_hostname\") | \
		.IB_owner" $json_db)

	if echo "$IB_owner" | grep "true" >/dev/null; then
		return 0
	fi

	return 1
}

#######################################
#
# 	Функция возврата списка МЭ для blackhole из БД по входному хостнейму
#
#	Входные параметры:
#
#   Строка, содержащая хостнейм
#
#	Возвращаемое значение:
#
#	переменная 'DB_BLACKHOLE_LIST'
#
#######################################

DB_BLACKHOLE_LIST=""
function db_get_blackhole_list() {
	local user_hostname="$1"
	local json_db="./db/device_info.json"
	local blackhole_list=$(jq -r ".devices_info[].contur_data | \
		select(.device_types[].devices_list[].hostname == \"$user_hostname\") | \
		.blackhole[].ip" $json_db)

	DB_BLACKHOLE_LIST=""

	OLD_IFS=$IFS
	IFS=$'\n'
	for blackhole_elem in $blackhole_list; do
		DB_BLACKHOLE_LIST+="$blackhole_elem "
	done
	IFS=$OLD_IFS
}


#######################################
#
# 	Функция возврата списка всех хостнеймов из БД
#
#	Входные параметры:
#
#	Возвращаемое значение:
#
#	переменная 'DB_ALL_HOSTNAMES'
#
#######################################

DB_ALL_HOSTNAMES=""
function db_get_all_hostnames() {
	local json_db="./db/device_info.json"
	local all_hostnames=$(jq -r ".devices_info[].contur_data.device_types[].devices_list[].hostname | \
		select(length > 0)" $json_db)

	DB_ALL_HOSTNAMES=""

	OLD_IFS=$IFS
	IFS=$'\n'
	for hostname_elem in $all_hostnames; do
		DB_ALL_HOSTNAMES+="$hostname_elem "
	done
	IFS=$OLD_IFS
}


#######################################
#
# 	Проверка из БД существует ли raid для выбранного хостнейма 
#
#	Входные параметры:
#
#   Строка, содержащая хостнейм
#
#	Коды возвратов:
#
#	0 - raid существует
#	1 - raid несуществует
#
#######################################

function db_is_raid_exists() {
	local user_hostname="$1"
	local json_db="./db/device_info.json"

	local raid_keys_length=$(jq -r ".devices_info[].contur_data.device_types[] | \
		select(.devices_list[].hostname == \"$user_hostname\") | \
		.raid_module | length" $json_db)

	if [ $raid_keys_length -ne 0 ]; then
		return 0
	fi

	return 1
}


#######################################
#
# 	Функция возврата списка всех RAID-массивов из БД
#
#	Входные параметры:
#
#   Строка, содержащая хостнейм
#
#	Возвращаемое значение:
#
#	переменная 'DB_RAID_LIST'
#
#######################################

DB_RAID_LIST=""
function db_get_raid_list() {
	local user_hostname="$1"
	local json_db="./db/device_info.json"

	DB_RAID_LIST=""
	
	local raid_list=$(jq -r ".devices_info[].contur_data.device_types[] | \
		select(.devices_list[].hostname == \"$user_hostname\") | \
		.raid_module.mdadm_list[].mdadm_name" $json_db)

	OLD_IFS=$IFS
	IFS=$'\n'
	for raid_elem in $raid_list; do
		DB_RAID_LIST+="$raid_elem "
	done
	IFS=$OLD_IFS
}

#######################################
#
# 	Функция возврата уровня RAID-массива из БД
#
#	Входные параметры:
#
#   Строка, содержащая хостнейм
#
#   Строка, содержащая имя RAID-массива
#
#	Возвращаемое значение:
#
#	переменная 'DB_RAID_LEVEL'
#
#######################################

DB_RAID_LEVEL=""
function db_get_raid_level() {
	local user_hostname="$1"
	local mdadm_name="$2"
	local json_db="./db/device_info.json"

	local raid_level=$(jq -r ".devices_info[].contur_data.device_types[] | \
		select(.devices_list[].hostname == \"$user_hostname\") | \
		.raid_module.mdadm_list[] | \
		select(.mdadm_name == \"$mdadm_name\") | .level" $json_db)

	DB_RAID_LEVEL="$raid_level"
}


#######################################
#
# 	Функция возврата типа файловой системы RAID-массива из БД
#
#	Входные параметры:
#
#   Строка, содержащая хостнейм
#
#   Строка, содержащая имя RAID-массива
#
#	Возвращаемое значение:
#
#	переменная 'DB_RAID_MOUNT_FSTYPE'
#
#######################################

DB_RAID_MOUNT_FSTYPE=""
function db_get_raid_mount_fstype() {
	local user_hostname="$1"
	local mdadm_name="$2"
	local json_db="./db/device_info.json"

	local fs_type=$(jq -r ".devices_info[].contur_data.device_types[] | \
		select(.devices_list[].hostname == \"$user_hostname\") | \
		.raid_module.mdadm_list[] | \
		select(.mdadm_name == \"$mdadm_name\") | .mount.fs_type" $json_db)

	DB_RAID_MOUNT_FSTYPE="$fs_type"
}


#######################################
#
# 	Функция возврата точки монтирования RAID-массива из БД
#
#	Входные параметры:
#
#   Строка, содержащая хостнейм
#
#   Строка, содержащая имя RAID-массива
#
#	Возвращаемое значение:
#
#	переменная 'DB_RAID_MOUNT_POINT'
#
#######################################

DB_RAID_MOUNT_POINT=""
function db_get_raid_mount_to() {
	local user_hostname="$1"
	local mdadm_name="$2"
	local json_db="./db/device_info.json"

	local mount_point=$(jq -r ".devices_info[].contur_data.device_types[] | \
		select(.devices_list[].hostname == \"$user_hostname\") | \
		.raid_module.mdadm_list[] | \
		select(.mdadm_name == \"$mdadm_name\") | .mount.to" $json_db)

	DB_RAID_MOUNT_POINT="$mount_point"
}


#######################################
#
# 	Функция возврата действия при ошибке монтирования RAID-массива из БД
#
#	Входные параметры:
#
#   Строка, содержащая хостнейм
#
#   Строка, содержащая имя RAID-массива
#
#	Возвращаемое значение:
#
#	переменная 'DB_RAID_MOUNT_ERROR'
#
#######################################

DB_RAID_MOUNT_ERROR=""
function db_get_raid_mount_error() {
	local user_hostname="$1"
	local mdadm_name="$2"
	local json_db="./db/device_info.json"

	local mount_error=$(jq -r ".devices_info[].contur_data.device_types[] | \
		select(.devices_list[].hostname == \"$user_hostname\") | \
		.raid_module.mdadm_list[] | \
		select(.mdadm_name == \"$mdadm_name\") | .mount.error" $json_db)

	DB_RAID_MOUNT_ERROR="$mount_error"
}


DB_RAID_MOUNT_OPT_LIST=""
function db_get_raid_mount_options() {
	local user_hostname="$1"
	local mdadm_name="$2"
	local json_db="./db/device_info.json"

	DB_RAID_MOUNT_OPT_LIST=""

	local mount_opt_list=$(jq -r ".devices_info[].contur_data.device_types[] | \
		select(.devices_list[].hostname == \"$user_hostname\") | \
		.raid_module.mdadm_list[] | \
		select(.mdadm_name == \"$mdadm_name\") | \
		.mount.options[].name" $json_db)

	OLD_IFS=$IFS
	IFS=$'\n'
	for mount_opt in $mount_opt_list; do
		DB_RAID_MOUNT_OPT_LIST+="$mount_opt "
	done
	IFS=$OLD_IFS
}


#######################################
#
# 	Функция возврата размер элемента RAID-массива из БД
#
#	Входные параметры:
#
#   Строка, содержащая хостнейм
#
#   Строка, содержащая имя RAID-массива
#
#	Возвращаемое значение:
#
#	переменная 'DB_RAID_UNIT_SIZE'
#
#######################################

DB_RAID_UNIT_SIZE=""
function db_get_raid_unit_size() {
	local user_hostname="$1"
	local mdadm_name="$2"
	local json_db="./db/device_info.json"

	local unit_size=$(jq -r ".devices_info[].contur_data.device_types[] | \
		select(.devices_list[].hostname == \"$user_hostname\") | \
		.raid_module.mdadm_list[] | \
		select(.mdadm_name == \"$mdadm_name\") | .unit_size" $json_db)

	DB_RAID_UNIT_SIZE="$unit_size"
}


#######################################
#
# 	Функция возврата списка активных дисков RAID-массива из БД
#
#	Входные параметры:
#
#   Строка, содержащая хостнейм
#
#   Строка, содержащая имя RAID-массива
#
#	Возвращаемое значение:
#
#	переменная 'DB_RAID_ACTIVE_LIST'
#
#######################################

DB_RAID_ACTIVE_LIST=""
function db_get_raid_active_list() {
	local user_hostname="$1"
	local mdadm_name="$2"
	local json_db="./db/device_info.json"

	DB_RAID_ACTIVE_LIST=""

	local raid_active_list=$(jq -r ".devices_info[].contur_data.device_types[] | \
		select(.devices_list[].hostname == \"$user_hostname\") | \
		.raid_module.mdadm_list[] | \
		select(.mdadm_name == \"$mdadm_name\") | .active_disks[].name" $json_db)

	OLD_IFS=$IFS
	IFS=$'\n'
	for raid_active_elem in $raid_active_list; do
		DB_RAID_ACTIVE_LIST+="$raid_active_elem "
	done
	IFS=$OLD_IFS
}


#######################################
#
# 	Функция возврата списка  дисков горячей замены RAID-массива из БД
#
#	Входные параметры:
#
#   Строка, содержащая хостнейм
#
#   Строка, содержащая имя RAID-массива
#
#	Возвращаемое значение:
#
#	переменная 'DB_RAID_SPARE_LIST'
#
#######################################

DB_RAID_SPARE_LIST=""
function db_get_raid_spare_list() {
	local user_hostname="$1"
	local mdadm_name="$2"
	local json_db="./db/device_info.json"

	DB_RAID_SPARE_LIST=""

	local raid_spare_list=$(jq -r ".devices_info[].contur_data.device_types[] | \
		select(.devices_list[].hostname == \"$user_hostname\") | \
		.raid_module.mdadm_list[] | \
		select(.mdadm_name == \"$mdadm_name\") | .spare_disks[].name" $json_db)

	OLD_IFS=$IFS
	IFS=$'\n'
	for raid_spare_elem in $raid_spare_list; do
		DB_RAID_SPARE_LIST+="$raid_spare_elem "
	done
	IFS=$OLD_IFS
}


#######################################
#
# 	Функция возврата кол-ва spare дисков RAID-массива из БД
#
#	Входные параметры:
#
#   Строка, содержащая хостнейм
#
#   Строка, содержащая название RAID-массива
#
#	Возвращаемое значение:
#
#	переменная 'DB_RAID_SPARES_COUNT'
#
#######################################

let DB_RAID_SPARES_COUNT=0
function db_get_raid_spares_count() {
	local user_hostname="$1"
	local mdadm_name="$2"
	local json_db="./db/device_info.json"

	local let raid_spares_count=$(jq -r ".devices_info[].contur_data.device_types[] | \
		select(.devices_list[].hostname == \"$user_hostname\") | \
		.raid_module.mdadm_list[] | \
		select(.mdadm_name == \"$mdadm_name\") | \
		.spare_disks[] | length" $json_db)

	if [ -z $raid_spares_count ]; then
		raid_spares_count=0
	fi

	DB_RAID_SPARES_COUNT=$raid_spares_count
}

#######################################
#
# 	Функция возврата RAID группы из БД
#
#	Входные параметры:
#
#   Строка, содержащая хостнейм
#
#   Строка, содержащая название RAID-массива
#
#	Возвращаемое значение:
#
#	переменная 'DB_RAID_SPARE_GROUP'
#
#######################################

DB_RAID_SPARE_GROUP=""
function db_get_raid_spare_group() {
	local user_hostname="$1"
	local mdadm_name="$2"
	local json_db="./db/device_info.json"

	local raid_spare_group=$(jq -r ".devices_info[].contur_data.device_types[] | \
		select(.devices_list[].hostname == \"$user_hostname\") | \
		.raid_module.spare_group[] | \ 
		select(.group_members[].name == \"$mdadm_name\") | .name_group" $json_db)

	DB_RAID_SPARE_GROUP="$raid_spare_group"
}