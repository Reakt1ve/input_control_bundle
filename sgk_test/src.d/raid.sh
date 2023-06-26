#! /bin/bash


#######################################
#
# 	Функция проверки существования требуемого RAID-массива
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - требуемый RAID-массив присутствуют в системе
#	1 - требуемый RAID-массив отсутствуют в системе
#
#######################################

function is_RAID_exists() {
	local madatory_md="$1"

	if grep "$madatory_md" /proc/mdstat >/dev/null; then
		return 0
	fi

	return 1
}


#######################################
#
# 	Функция проверки присутствия записей об RAID-массиве в файлe boot.conf
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - требуемый RAID-массив присутствует в boot.conf (если требуется)
#	1 - требуемый RAID-массив имеет ошибки в boot.conf
#
#######################################

function is_RAID_in_boot() {
	local madatory_md="$1"
	local boot_conf_path="$2"

	local madatory_boot_labels=" \
Astra \
Recovery \
"

	db_get_raid_mount_to "$HOSTNAME" "$madatory_md"
	local mount_to=$DB_RAID_MOUNT_POINT
	if ! echo "$mount_to" | grep "^/$" >/dev/null; then
		return 0
	fi

	local md_uuid=$(blkid /dev/${madatory_md} | awk '{print $2}' | awk -F "\"" '{print $2}')

	OLD_IFS=$IFS
	IFS=$' '
	for madatory_boot_label in $madatory_boot_labels; do
		if ! grep -A 4 "^label=${madatory_boot_label}$" "$boot_conf_path" | grep "root=UUID=${md_uuid}" >/dev/null; then
			IFS=$OLD_IFS
			return 1
		fi
	done
	IFS=$OLD_IFS

	return 0
}


#######################################
#
# 	Функция проверки присутствия записей об RAID-массиве в файлe fstab
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - требуемый RAID-массив присутствует в fstab (если требуется)
#	1 - требуемый RAID-массив имеет ошибки в fstab
#
#######################################

function is_RAID_in_fstab() {
	local madatory_md="$1"
	local fstab_path="$2"

	db_get_raid_mount_to "$HOSTNAME" "$madatory_md"
	local mount_to="$DB_RAID_MOUNT_POINT"
	if [ -z $mount_to ]; then
		return 0
	fi

	if is_fstab_mpoints_have_duplicates "$fstab_path"; then
		return 1
	fi

	local md_uuid=$(blkid /dev/${madatory_md} | awk '{print $2}' | awk -F "\"" '{print $2}')
	db_get_raid_mount_error "$HOSTNAME" "$madatory_md"
	local mount_error="$DB_RAID_MOUNT_ERROR"
	db_get_raid_mount_fstype "$HOSTNAME" "$madatory_md"
	local fs_type="$DB_RAID_MOUNT_FSTYPE"
	db_get_raid_mount_options "$HOSTNAME" "$madatory_md"
	local mount_opts="$DB_RAID_MOUNT_OPT_LIST"

	compile_fstab_string "$md_uuid" "$mount_to" "$fs_type" "$mount_opts" "$mount_error"
	local fstab_str_regex=$(echo "$COMPILED_FSTAB_STR" | sed "s/ /[\\\s]*/g")

	if grep -P "^$fstab_str_regex$" "$fstab_path" >/dev/null; then
		return 0
	fi

	return 1
}


#######################################
#
# 	Функция проверки имеет ли RAID-массив spare диски
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - RAID-массив имеет spare диски
#	1 - RAID-массив не имеет spare диски
#
#######################################

function RAID_have_spare_disks() {
	local madatory_md="$1"

	db_get_raid_spares_count "$HOSTNAME" "$madatory_md"
	local let spare_disks_count=$DB_RAID_SPARES_COUNT

	if [ $spare_disks_count -ge 1 ]; then
		return 0
	fi

	return 1
}


#######################################
#
# 	Функция проверки в mdadm.conf указания группы
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - группа присутствует
#	1 - неверное кол-во параметров групп
#	2 - группа отсутствует
#
#######################################

function check_mdadm_file_group() {
	local madatory_md="$1"
	local mdadm_conf="$2"
	local spare_group="$3"

	local group_regex="[[:space:]]spare-group=[^\s]*"

	local token_count=$(grep -Po "$group_regex" $mdadm_conf | wc -l)
	if [ $token_count -ne 1 ]; then
		return 1
	fi

	local config_group=$(cat "$mdadm_conf" | grep "$madatory_md" | \
		grep -Po "$group_regex" | cut -d '=' -f2 | grep -Po "[^\s]*")

	if ! echo "$config_group" | grep -P "^$spare_group$" >/dev/null; then
		return 2
	fi

	return 0
}


#######################################
#
# 	Функция проверки в mdadm.conf указания RAID в качестве spare
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - параметр spares присутствует (если требуется)
#	1 - неверное кол-во параметра
#	2 - параметр spares отсутствует
#
#######################################

function check_mdadm_file_spare() {
	local madatory_md="$1"
	local mdadm_conf="$2"
	local spares_count="$3"

	local spare_regex="[[:space:]]spares=[^\s]*"
	local token_count=$(grep "$madatory_md" "$mdadm_conf" | grep -Po "$spare_regex" | wc -l)

	if [ -z $spares_count ]; then
		if [ $token_count -ne 0 ]; then
			return 1
		fi
	else
		if [ $token_count -ne 1 ]; then
			return 1
		fi

		local spare_group_count=$(cat "$mdadm_conf" | grep "$madatory_md" | \
			grep -Po "$spare_regex" | cut -d '=' -f2 | grep -Po "[^\s]*")

		if ! echo "$spare_group_count" | grep -P "^$spares_count$" >/dev/null; then
			return 2
		fi
	fi

	return 0
}


#######################################
#
# 	Функция проверки сервиса mdadm monitor
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - сервис работает
#	1 - сервис не работает
#
#######################################

function check_mdadm_monitor() {
	if ! ps --format command | \
		grep "^mdadm --monitor --pid-file /var/run/mdadm/monitor.pid --daemonise --scan --syslog$" >/dev/null; then
		return 1
	fi

	return 0
}

#######################################
#
# 	Функция проверки RAID группы для требуемого RAID-массива
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - RAID группы успешно проверены
#	1 - RAID-массив имеет неверную группу
#	2 - RAID-массив имеет неверное кол-во spare дисков
#	3 - Отключен сервис мониторинга RAID групп
#
#######################################

function check_RAID_group() {
	local madatory_md="$1"
	
	db_get_raid_spare_group "$HOSTNAME" "$madatory_md"
	local raid_spare_group="$DB_RAID_SPARE_GROUP"
	if [ -z $raid_spare_group ]; then
		return 0
	fi

	local mdadm_conf="/etc/mdadm/mdadm.conf"

	check_mdadm_file_group "$madatory_md" "$mdadm_conf" "$raid_spare_group"
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		return 1
	fi

	local let spares_count=0
	db_get_raid_spares_count "$HOSTNAME" "$madatory_md"
	spares_count=$DB_RAID_SPARES_COUNT
	check_mdadm_file_spare "$madatory_md" "$mdadm_conf" "$spares_count"
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		return 2
	fi

	check_mdadm_monitor
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		return 3
	fi

	return 0
}


#######################################
#
# 	Функция проверки размера единичного диска требуемого RAID-массива
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - RAID-массив имеет верный размер единичного диска
#	1 - RAID-массив имеет неверный размер единичного диска
#
#######################################

function check_RAID_unit_size_property() {
	local madatory_md="$1"
	
	db_get_raid_unit_size "$HOSTNAME" "$madatory_md"
	local raid_unit_size="$DB_RAID_UNIT_SIZE"

	local system_raid_unit_size=$(lsblk --raw | grep -m1 "$madatory_md" | cut -d ' ' -f4)

	if echo "$system_raid_unit_size" | grep "^$raid_unit_size$" >/dev/null; then
		return 0
	fi

	return 1
} 


#######################################
#
# 	Функция проверки уровня требуемого RAID-массива
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - RAID-массив имеет верный уровень
#	1 - RAID-массив имеет неверный уровень
#
#######################################

function check_RAID_level_property() {
	local madatory_md="$1"

	db_get_raid_level "$HOSTNAME" "$madatory_md"
	local raid_level="$DB_RAID_LEVEL"

	local raid_info=$(mdadm -D /dev/${madatory_md})
	local system_raid_level=$(echo "$raid_info"| grep "Raid Lev" | awk '{print $4}' | grep -o "[0-9]")

	if echo "$system_raid_level" | grep "^$raid_level$" >/dev/null; then
		return 0
	fi

	return 1
}


#######################################
#
# 	Функция проверки активных дисков требуемого RAID-массива
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - RAID-массив имеет верные активные диски
#	1 - RAID-массив имеет неверные активные диски
#
#######################################

function check_RAID_active_disks() {
	local madatory_md="$1"

	db_get_raid_active_list "$HOSTNAME" "$madatory_md"
	local raid_active_disks_list="$DB_RAID_ACTIVE_LIST"

	local raid_info=$(mdadm -D /dev/${madatory_md})
	local system_raid_actives=$(echo "$raid_info" | grep "active.*/dev/sd" | grep -Po "sd[a-z](0|[1-9]+)" | tr '\n' ' ')

	local let is_iter_objects_ended=1
	local let error_founded=0
	OLD_IFS=$IFS
	IFS=$' '
	for raid_active_disk in $raid_active_disks_list; do
		for system_raid_active in $system_raid_actives; do
			if echo "$raid_active_disk" | grep "^$system_raid_active$" >/dev/null; then
				is_iter_objects_ended=0
				break
			fi
		done

		if [ $is_iter_objects_ended -eq 1 ]; then
			error_founded=1
		fi
		is_iter_objects_ended=1
	done
	IFS=$OLD_IFS

	if [ $error_founded -eq 1 ]; then
		return 1
	fi

	return 0
}


#######################################
#
# 	Функция проверки spare дисков требуемого RAID-массива
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - RAID-массив имеет верные spare диски
#	1 - RAID-массив имеет неверные spare диски
#
#######################################

function check_RAID_spare_disks() {
	local madatory_md="$1"

	DB_RAID_MOUNT_FSTYPE "$HOSTNAME" "$madatory_md"
	local raid_spare_disks_list="$DB_RAID_SPARE_LIST"

	local raid_info=$(mdadm -D /dev/${madatory_md})
	local system_raid_spares=$(echo "$raid_info" | grep "spare.*/dev/sd" | grep -Po "sd[a-z](0|[1-9]+)")

	local let is_iter_objects_ended=1
	local let error_founded=0
	OLD_IFS=$IFS
	IFS=$' '
	for raid_spare_disk in $raid_spare_disks_list; do
		for system_raid_spare in $system_raid_spares; do
			if echo "$raid_spare_disk" | grep "^$system_raid_spare$" >/dev/null; then
				is_iter_objects_ended=0
				break
			fi
		done

		if [ $is_iter_objects_ended -eq 1 ]; then
			error_founded=1
		fi
		is_iter_objects_ended=1
	done
	IFS=$OLD_IFS

	if [ $error_founded -eq 1 ]; then
		return 1
	fi

	return 0
}


#######################################
#
# 	Функция проверки всех ключевых параметров требуемого RAID-массива
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - RAID-массив имеет верные параметры
#	1 - RAID-массив имеет неверный размер дисков
#	2 - RAID-массив имеет неверный уровень RAID
#	3 - RAID-массив имеет неверные активные диски 
#	4 - RAID-массив имеет неверные диски горячей замены (spare)
#
#######################################

function check_RAID_all_properties() {
	local madatory_md="$1"

	local let exit_code=0

	check_RAID_unit_size_property "$madatory_md"
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		return 1
	fi

	check_RAID_level_property "$madatory_md"
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		return 2
	fi

	check_RAID_active_disks "$madatory_md"
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		return 3
	fi

	check_RAID_spare_disks "$madatory_md"
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		return 4
	fi

	return 0
}


#######################################
#
# 	Функция обработки RAID-массивов
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - обработка RAID-массивов прошла успешно
#   1 - сервер является АРМ Т1, где не требуется RAID
#	2 - требуемые RAID-массивы отсутсвуют в системе
#	3 - неверно настроен один из параметров RAID-массивов
#	4 - один из RAID-массивов отсутствует в файле fstab
#	5 - один из RAID-массивов отсутствует в файле boot.conf
#	6 - один из RAID-массивов имеет ошибки в mdadm.conf
#
#######################################

function check_RAID() {
	db_get_server_type "$HOSTNAME"
	local server_type=$DB_SERVER_TYPE
	if echo "$server_type" | grep "ARM T1" >/dev/null; then
		return 1
	fi

	db_get_raid_list "$HOSTNAME"
	local madatory_raid_list="$DB_RAID_LIST"

	OLD_IFS=$IFS
	IFS=$' '
	for madatory_raid in $madatory_raid_list; do
		if ! is_RAID_exists "$madatory_raid"; then
			echo -e "${orange}RAID ${madatory_raid} не настроен${normal}" | tee -a ${OUTPUT_FILE}
			IFS=$OLD_IFS
			return 2
		fi

		check_RAID_all_properties "$madatory_raid"
		exit_code=$?
		if [ $exit_code -eq 1 ]; then
			echo -e "${orange}Неверный размер дисков RAID ${madatory_raid}${normal}" | tee -a ${OUTPUT_FILE}
			IFS=$OLD_IFS
			return 3
		elif [ $exit_code -eq 2 ]; then
			echo -e "${orange}Неверный уровень RAID ${madatory_raid}${normal}" | tee -a ${OUTPUT_FILE}
			IFS=$OLD_IFS
			return 3
		elif [ $exit_code -eq 3 ]; then
			echo -e "${orange}Неверное количество активных дисков в RAID ${madatory_raid}${normal}" | tee -a ${OUTPUT_FILE}
			IFS=$OLD_IFS
			return 3
		elif [ $exit_code -eq 4 ]; then
			echo -e "${orange}Неверное количество spare дисков в RAID ${madatory_raid}${normal}" | tee -a ${OUTPUT_FILE}
			IFS=$OLD_IFS
			return 3
		fi

		if ! is_RAID_in_fstab "$madatory_raid" "/etc/fstab"; then
			echo -e "${orange}Запись RAID ${madatory_raid} имеет ошибки в fstab${normal}" | tee -a ${OUTPUT_FILE}
			IFS=$OLD_IFS
			return 4
		fi

		if ! is_RAID_in_boot "$madatory_raid" "/boot/boot.conf"; then
			echo -e "${orange}Запись RAID ${madatory_raid} имеет ошибки в boot.conf${normal}" | tee -a ${OUTPUT_FILE}
			IFS=$OLD_IFS
			return 5
		fi

		check_RAID_group "$madatory_raid"
		exit_code=$?
		if [ $exit_code -eq 1 ]; then
			echo -e "${orange}RAID ${madatory_raid} имеет неверную группу в mdadm.conf${normal}" | tee -a ${OUTPUT_FILE}
			IFS=$OLD_IFS
			return 6
		elif [ $exit_code -eq 2 ]; then
			echo -e "${orange}RAID ${madatory_raid} имеет неверное кол-во spare дисков в mdadm.conf${normal}" | tee -a ${OUTPUT_FILE}
			IFS=$OLD_IFS
			return 6
		elif [ $exit_code -eq 3 ]; then
			echo -e "${orange}Отключен сервис мониторинга RAID групп${normal}" | tee -a ${OUTPUT_FILE}
			IFS=$OLD_IFS
			return 6
		fi

		if RAID_have_spare_disks "$madatory_raid"; then
			echo -e "${orange}RAID ${madatory_raid} настроен с резервом${normal}" | tee -a ${OUTPUT_FILE}
		else
			echo -e "${orange}RAID ${madatory_raid} настроен без резерва${normal}" | tee -a ${OUTPUT_FILE}
		fi
	done
	IFS=$OLD_IFS

	return 0
}
