#! /bin/bash

let SYNC_BOOT_PARTITIONS=1 ### переменная, хранящая состояние синхронизации boot разделов: 0 - синхронизированы, 1 - несинхронизированы


#######################################
#
# 	Функция создания строки fstab на основе входных параметров
#
#	Входные параметры:
#
#	Возвращаемое значение:
#
#	переменная COMPILED_FSTAB_STR
#
#	Коды возвратов:
#
#######################################

COMPILED_FSTAB_STR=""

function compile_fstab_string() {
	local device_uuid="$1"
	local mount_point="$2"
	local fs_type="$3"
	local mount_options="$4"
	local mount_error="$5"

	local fstab_str="UUID=${device_uuid} ${mount_point} ${fs_type} "

	if [[ ! -z $mount_options ]]; then
		local mount_options_arr=($mount_options)
		local mount_options_arr_length=${#mount_options_arr[@]}
		for ((i=0; i<mount_options_arr_length; i++)); do
			if [[ $i -eq $((mount_options_arr_length-1)) ]]; then
				fstab_str+="${mount_options_arr[$i]} "
				break
			fi

			fstab_str+="${mount_options_arr[$i]},"
		done
	fi

	if [[ ! -z $mount_error ]]; then
		fstab_str+="errors=${mount_error} "
	fi

	fstab_str+="0 1"

	COMPILED_FSTAB_STR="$fstab_str"
}


#######################################
#
# 	Функция, проверяющая есть ли дубликаты точек монтирования в файле fstab
#
#	Входные параметры:
#
#   Строка, содержащая путь до файла fstab
#
#	Коды возвратов:
#
#	0 - дубликаты отсутствуют
#	1 - присутствуют дубликаты
#
#######################################

function is_fstab_mpoints_have_duplicates() {
	local fstab_path="$1"

	local fstab_mount_points=$(cat "$fstab_path" | grep "^UUID=" | grep -Po "[[:space:]]/[^\s]*" | xargs | tr ' ' '\n')
	local fstab_uniq_mount_points=$(echo "$fstab_mount_points" | uniq | xargs)
	local let mount_point_repeat_count=0
	OLD_IFS=$IFS
	IFS=' '
	for fstab_uniq_mount_point in $fstab_uniq_mount_points; do
		mount_point_repeat_count=$(echo "$fstab_mount_points" | grep "^$fstab_uniq_mount_point$" | wc -l)
		if [ $mount_point_repeat_count -ne 1 ]; then
			IFS=$OLD_IFS
			return 0
		fi
	done
	IFS=$OLD_IFS

	return 1

}


#######################################
#
# 	Функция, выполняющая задачу сравнения хэш-сумм boot разделов
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - хэш-суммы равны
#	1 - хэш-сумму неравны
#
#######################################

function is_boot_hash_equal() {
	local madatory_boot_partitions="/dev/sda1 /dev/sdb1 /dev/sdc1"
	local folder_name1="/tmp/boot1"
	local folder_name2="/tmp/boot2"

	if [ -d ${folder_name1} ]; then
		local date_time=`echo $(($(date +%s%N)/1000000))`
		local folder_name1="${folder_name1}_${date_time}"
	fi

	if [ -d ${folder_name2} ]; then
		local date_time=`echo $(($(date +%s%N)/1000000))`
		local folder_name2="${folder_name2}_${date_time}"
	fi

	mkdir -p "${folder_name1}" "${folder_name2}"

	local first_boot_partition=$(echo "$madatory_boot_partitions" | cut -d ' ' -f1)
	mount $(echo "${first_boot_partition}") "${folder_name1}"
	local prev_boot_sum=$(find "$folder_name1" -type f -exec sha256sum {} + | awk '{print $1}' | sort | sha256sum)
	local folder_name1_was_first=1

	local error_found=0
	local current_folder=""
	for boot_partition in $(echo "$madatory_boot_partitions" | cut -d ' ' -f1 --complement); do
		if lsblk | grep "$folder_name1" >/dev/null; then
			mount $(echo "${boot_partition}") "${folder_name2}"
			local current_boot_sum=$(find "$folder_name2" -type f -exec sha256sum {} + | awk '{print $1}' | sort | sha256sum)
		else
			mount $(echo "${boot_partition}") "${folder_name1}"
			local current_boot_sum=$(find "$folder_name1" -type f -exec sha256sum {} + | awk '{print $1}' | sort | sha256sum)
		fi

		if ! echo "$current_boot_sum" | grep "$prev_boot_sum" >/dev/null; then
			((error_found++))
			break
		fi

		prev_boot_sum=$(echo "$current_boot_sum")

		if [ $folder_name1_was_first -eq 1 ]; then
			umount "$folder_name1"
			folder_name1_was_first=0
		else
			umount "$folder_name2"
			folder_name1_was_first=1
		fi
	done

	umount "$folder_name1" 2>/dev/null
	umount "$folder_name2" 2>/dev/null
	rm -rf "$folder_name1" "$folder_name2"

	if [ $error_found -eq 1 ]; then
		return 1
	fi

	return 0
}


#######################################
#
# 	Функция, рассчитывающая минимально необходимое кол-во дисков в системе
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - минимальное кол-во дисков присутствует в системе
#	1 - минимальное кол-во дисков не присутствует в системе
#
#######################################

function is_minimal_count_disks() {
	local let disk_count=0

	local disk=""
	local block_type=""

	OLD_IFS=$IFS
	IFS=$'\n'
	local disks_lines=$(lsblk | grep "^sd[a-z]")
	for disk_line in $disks_lines; do
		disk=$(echo $disk_line | xargs | cut -d ' ' -f1)
		block_type=$(ls -l /dev/disk/by-path | grep $disk | head -n 1 | xargs | cut -d ' ' -f9 | cut -d '-' -f3)
		if ! echo "$block_type" | grep "usb" >/dev/null; then
			((disk_count++))
		fi
	done
	IFS=$OLD_IFS

	if [ $disk_count -ge 3 ]; then
		return 0
	fi

	return 1
}


#######################################
#
# 	Агрегирующая функция, которая проверяет минимальные требования к дисковой подсистеме
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - дисковая подсистема соответствует минимальным требованиям
#	1 - дисковая подсистема не имеет минимальное кол-во дисков
#	2 - на требуемых дисках не размечаны boot разделы
#	3 - порядок инициализации дисков не соответствует требованиям
#
#######################################

function check_devices_requirements() {
	if ! is_minimal_count_disks; then
		return 1
	fi

	if ! is_boot_partitions_exists; then
		return 2
	fi

	if ! is_valid_disk_order; then
		return 3
	fi

	return 0
}


#######################################
#
# 	Функция, которая проверяет порядок инициализации дисков
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - порядок инициализации дисков соотвествует требованиям
#	1 - порядок инициализации дисков не соотвествует требованиям
#
#######################################

function is_valid_disk_order() {
	local first_atabus_devices_count=$(dmesg | grep -P "ata[1-4]: SATA link up" | wc -l)
	if [[ ! $first_atabus_devices_count -eq 4 ]]; then
		return 1
	fi

	return 0
}


#######################################
#
# 	Функция, которая проверяет монтирование boot раздела
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - boot раздел примонтирован
#	1 - boot раздел непримонтирован
#
#######################################

function is_boot_partition_mounted() {
	if ! lsblk | grep -P "sda1|sdb1|sdc1" | grep "boot" >/dev/null; then
		return 1
	fi

	return 0
}


#######################################
#
# 	Функция, которая проверяет размечанные boot разделы на требуемых дисках
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - boot разделы присутствуют на требуемых дисках
#	1 - boot разделы отсутствуют на требуемых дисках
#
#######################################

function is_boot_partitions_exists() {
	local all_boot_list=$(get_boot_list)
	local madatory_boot_partitions="/dev/sda1 /dev/sdb1 /dev/sdc1"

	local all_boot_list=$(echo "$all_boot_list" | tr '\n' ' ')
	if ! echo "$all_boot_list" | grep "$madatory_boot_partitions" >/dev/null; then
		return 1
	fi

	return 0
}


#######################################
#
# 	Функция, которая возвращает активный (примонтированный) boot раздел
#
#	Входные параметры:
#
#	Возвращаемое значение:
#
#	Абсолютный путь активного boot раздела
#	
#######################################

function get_active_boot() {
	local device=$(lsblk --output NAME,MOUNTPOINT | grep "/boot" | cut -d ' ' -f1 | grep -P -o "sd[a-c]1")
	local device_path="/dev/${device}"

	echo "$device_path"
}


#######################################
#
# 	Функция, которая возвращает второстепенные (непримонтированные) boot разделы
#
#	Входные параметры:
#
#	Возвращаемое значение:
#
#	Строку, содержащую через пробел абсолютные пути до второстепенных boot разделов 
#	
#######################################

function get_slaves_boot_list() {
	local device_list=$(lsblk --output NAME,MOUNTPOINT | grep -P "sd[a-c]1" | grep -v "/boot" | grep -P -o "sd[a-c]1")

	OLD_IFS=$IFS
	IFS=$'\n'
	for device in $device_list; do 
		device_path_list+="/dev/${device}\n"
	done
	IFS=$OLD_IFS

	echo -e "${device_path_list::-2}"
}


#######################################
#
# 	Функция, которая возвращает все boot разделы
#
#	Входные параметры:
#
#	Возвращаемое значение:
#
#	Строку, содержащую через пробел абсолютные пути до всех boot разделов 
#	
#######################################

function get_boot_list() {
	local device_list=$(lsblk --output NAME,MOUNTPOINT | grep -P -o "sd[a-z]1")

	OLD_IFS=$IFS
	IFS=$'\n'
	for device in $device_list; do
		device_path_list+="/dev/${device}\n"
	done
	IFS=$OLD_IFS

	echo -e "${device_path_list}"
}


#######################################
#
# 	Функция, которая копирует данные с активного boot раздела на второстепенные
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - копирование прошло успешно 
#	1 - ни один boot раздел не примонтирован в системе
#	2 - при копирование произошла ошибка
#
#######################################

function copy_boot() {
	if ! is_boot_partition_mounted; then
		return 1
	fi

	master_boot=$(get_active_boot)
	echo -e "В качестве master boot раздела выбран диск: ${master_boot}" | tee -a ${OUTPUT_FILE}

	all_slaves_boot_list=$(get_slaves_boot_list)
	imported_slaves_boot_list=$(echo -e "${all_slaves_boot_list}" | grep -P "sd[a-c]1" | tr "\n" ",")
	imported_slaves_boot_list="${imported_slaves_boot_list::-1}"
	echo "В качестве boot разделов, на которые производится копирования master: ${imported_slaves_boot_list}" | tee -a ${OUTPUT_FILE}

	OLD_IFS=$IFS
	IFS=$','
	for slave_boot in $imported_slaves_boot_list; do
		dd if=${master_boot} of=${slave_boot} bs=1K status=progress 2>&1
		exit_code=$?
		if [ $exit_code -ne 0 ]; then
			IFS=$OLD_IFS
			return 2
		fi
	done
	IFS=$OLD_IFS
	sync;sync;sync;sync

	return 0
}


#######################################
#
# 	Функция, которая возвращает список блочных устройств с подключением SATA
#
#	Входные параметры:
#
#	Возвращаемое значение:
#
#	переменная LIST_DISKS
#
#######################################

LIST_DISKS=""

function get_disk_subsystem_info() {
	disks_lines=$(lsblk | grep "^sd[a-z]")
	OLD_IFS=$IFS
	IFS=$'\n'
	for disk_line in $disks_lines; do
		disk=$(echo $disk_line | xargs | cut -d ' ' -f1)
		block_type=$(ls -l /dev/disk/by-path | grep $disk | head -n 1 | xargs | cut -d ' ' -f9 | cut -d '-' -f3)
		if ! echo "$block_type" | grep "usb" >/dev/null; then
			LIST_DISKS+="$disk "
		fi
	done
	IFS=$OLD_IFS
}


#######################################
#
# 	Функция, которая проверяет вендора дисков
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - все вендоры дисков соответствуют требуемому
#	1 - не все вендоры дисков соответствуют требуемому
#
#######################################

function check_disks_vendor() {
	local let error_count=0

	OLD_IFS=$IFS
	IFS=$' '
	for disk in $LIST_DISKS; do
		disk_model=$(cat /sys/class/block/${disk}/device/model)
		disk_vendor=$(echo $disk_model | cut -d ' ' -f1)
		if ! echo $disk_vendor | grep INTEL >/dev/null; then
			echo -e "${red}Вендором диска ${disk} не является INTEL. Модель диска ${disk_model}${normal}" | tee -a ${OUTPUT_FILE}
			((error_count++))
		else
			echo -e "Вендором диска ${disk} является INTEL" | tee -a ${OUTPUT_FILE}
		fi
	done
	IFS=$OLD_IFS

	if [ $error_count -ne 0 ]; then
		return 1
	fi

	return 0
}


#######################################
#
# 	Функция, проверяющая параметры S.M.A.R.T.
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - параметры S.M.A.R.T. соответствуют требуемым
#	1 - параметры S.M.A.R.T. не соответствуют требуемым
#
#######################################

function check_disks_smart() {
	smartctl --scan >/dev/null

	local smart_error_check="5 196 197"
	local let error_count=0

	OLD_IFS=$IFS
	IFS=$' '
	for disk in $LIST_DISKS; do
		smart_availability=$(smartctl -a /dev/${disk} | grep "SMART support is" | xargs | cut -d ':' -f2 | cut -d '-' -f1 | xargs)
		if echo "$smart_availability" | grep 'Available' >/dev/null; then
			declare -a temp_arr
			let temp_arr_idx=0
			while read line; do
				temp_arr[$temp_arr_idx]=$(echo "$line" | xargs)
				((temp_arr_idx++))
			done <<< $(smartctl -A /dev/${disk})
			normalized_smart_table=$(printf '%s\n' "${temp_arr[@]}")

			let error_flag=0

			for error_check in $smart_error_check; do
				error_value_line=$(echo "$normalized_smart_table" | cut -d' ' -f1 | grep -n $error_check | cut -d ':' -f1 | head -n 1 | xargs)
				if [ -z $error_value_line ];then
					continue
				fi
				error_value=$(echo "$normalized_smart_table" | head -n $error_value_line | tail -n 1 | xargs | cut -d ' ' -f10)
				if ! echo "$error_value" | grep "0" >/dev/null; then
					echo -e "${orange}Диск ${disk} имеет ошибки${normal}" | tee -a ${OUTPUT_FILE}
					let error_flag=1
					((error_count++))
					break
				fi
			done

			if [ $error_flag -eq 0 ]; then
				echo "Диск ${disk} не имеет ошибок" | tee -a ${OUTPUT_FILE}
			fi

			power_on=$(echo "$normalized_smart_table" | grep "Power_On_Hours" | xargs | cut -d ' ' -f10)
			echo "Время работы диска ${disk} ${power_on} часов" | tee -a ${OUTPUT_FILE}
		else
			echo -e "${orange}Диск ${disk} не поддерживает SMART${normal}" | tee -a ${OUTPUT_FILE}
			((error_count++))
		fi
	done
	IFS=$OLD_IFS

	if [ $error_count -ne 0 ]; then
		return 1
	fi

	return 0
}


#######################################
#
# 	Функция-обертка над функцией копирования boot разделов с возможностью проверки хэш-суммы разделов
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - boot разделы уже синхронизированы (имееют одни и те же данные)
#	1 - ни один boot раздел непримонтирован
#	2 - возникла ошибка во время копирования
#	3 - повторные попытки копирования непривели к положительному результату (данные разные)
#	4 - повторное копирование прошло успешно (имееют одни и те же данные)
#
#######################################

function copy_boot_ack() {
	local let max_fix_count=2
	local let curr_fix_count=0

	if is_boot_hash_equal; then
		SYNC_BOOT_PARTITIONS=0
		return 0
	fi

	while true; do
		if [ $curr_fix_count -lt $max_fix_count ]; then
			echo -e "${red}boot разделы не идентичны друг другу${normal}"
			echo -e "${orange}попытка копирование master boot на соседние boot разделы...${normal}" | tee -a ${OUTPUT_FILE}

			copy_boot
			exit_code=$?
			if [ $exit_code -eq 1 ]; then
				return 1
			elif [ $exit_code -eq 2 ]; then
				return 2
			fi

			echo -e "${orange}копирование master boot раздела выполнено успешно${normal}" | tee -a ${OUTPUT_FILE}

			((curr_fix_count++))
		else
			SYNC_BOOT_PARTITIONS=1
			return 3
		fi

		if is_boot_hash_equal; then
			SYNC_BOOT_PARTITIONS=0
			echo -e "${orange}при копировании ошибок не выявлено${normal}"
			return 4
		else
			echo -e "${orange}проверка результата копирования выявила ошибки${normal}"
		fi
	done
}

#######################################
#
# 	Функция управления потоком копирования boot разделов
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - копирование прошло успешно
#	1 - копирование прошло неудачно и пользователь отказался от повторных попыток
#
#######################################

function init_copy_boot() {
	local let exit_code=0

	while true; do
		copy_boot_ack
		exit_code=$?
		if [ $exit_code -eq 0 ]; then
			echo "boot разделы идентичны друг другу" | tee -a ${OUTPUT_FILE}
			break
		elif [ $exit_code -eq 1 ]; then
			echo -e "${red}boot раздел не примонтирован${normal}" | tee -a ${OUTPUT_FILE}
		elif [ $exit_code -eq 2 ]; then
			echo -e "${red}Произошла непредвиденная ошибка во время копирования${normal}"
		elif [ $exit_code -eq 3 ]; then
			echo -e "${red}Повторные попытки копирования не привели к успеху${normal}"
		elif [ $exit_code -eq 4 ]; then
			echo "boot разделы были успешно засинхронизированы"
			break
		fi

		ask_about_retry_copy_boot
		exit_code=$?
		if [ $exit_code -ne 0 ]; then
			return 1
		fi
	done

	return 0
}