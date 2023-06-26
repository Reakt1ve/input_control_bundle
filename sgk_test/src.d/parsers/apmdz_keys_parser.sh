#! /bin/bash

let ROW_CONSISTENT_ERROR=0 ### переменная, содержащая номер строки в файле со списком ключей АПМДЗ, где произошла ошибка


#######################################
#
# 	Функция генерации файла со списком ключей АПМДЗ
#
#	Входные параметры:
#
#	Коды возвратов:
#
#######################################

function generate_apmdz_keys_file() {
	local apmdz_keys_file_path="$1"

	db_get_all_hostnames

	echo "хостнейм,серийный_номер,дата_окончания" > "$apmdz_keys_file_path"	
	OLD_IFS=$IFS
	IFS=$' '
	for hostname_elem in $DB_ALL_HOSTNAMES; do
		echo "${hostname_elem},," >> "$apmdz_keys_file_path"
	done
	IFS=$OLD_IFS
}


#######################################
#
# 	Функция добавления нового хостнейма в файл со списком ключей АПМДЗ
#
#	Входные параметры:
#
#	Коды возвратов:
#
#######################################

function add_apmdz_keys_entity() {
	local user_hostname="$1"
	local apmdz_keys_file_path="$2"

	echo "${user_hostname},," >> "$apmdz_keys_file_path"
}


#######################################
#
# 	Функция выборки строки с хостнеймом в файле со списком ключей АПМДЗ
#
#	Входные параметры:
#
#	Возвращаемое значение:
#
#	переменная 'APMDZ_KEYS_SELECTED_ROW'
#
#	Коды возвратов:
#
#######################################

APMDZ_KEYS_SELECTED_ROW=""

function select_entity_row() {
	local user_hostname="$1"
	local apmdz_keys_file_path="$2"

	selected_row=$(grep "$user_hostname" "$apmdz_keys_file_path")
	APMDZ_KEYS_SELECTED_ROW=$(echo $selected_row)
}


#######################################
#
# 	Функция проверки дупликатов хостнейма в файле со списком ключей АПМДЗ
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - дупликаты необнаружены
#	1 - дупликаты обнаружены
#
#######################################

function have_entity_duplicates() {
	local apmdz_keys_file_path="$1"

	db_get_all_hostnames

	OLD_IFS=$IFS
	IFS=$' '
	for hostname_elem in $DB_ALL_HOSTNAMES; do
		local let rows_count=$(grep "$hostname_elem" "$apmdz_keys_file_path" | wc -l) 
		if [ $rows_count -gt 1 ]; then
			ROW_CONSISTENT_ERROR=$(grep -m 1 -n "$hostname_elem" "$apmdz_keys_file_path" | cut -d ':' -f1)
			IFS=$OLD_IFS
			return 0
		fi
	done
	IFS=$OLD_IFS

	return 1
}


#######################################
#
# 	Функция проверки существования хостнейма в файле со списком ключей АПМДЗ
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - хостнейм существует
#	1 - хостнейм несуществует
#
#######################################

function is_apmdz_keys_entity_exists() {
	local user_hostname="$1"
	local apmdz_keys_file_path="$2"

	if ! grep "$user_hostname" "$apmdz_keys_file_path" > /dev/null; then
		return 1
	fi

	return 0
}


#######################################
#
# 	Функция проверки валидности строки с хостнеймом в файле со списком ключей АПМДЗ
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - строка валидна
#	1 - строка невалидна
#
#######################################

function is_row_entity_valid() {
	local apmdz_keys_file_path="$1"
	local row_entity_regex="^[^,]*,[^,]*,[^,]*$"

	local line=""
	local let line_num=0
	while read line; do
		((line_num++))
		if ! echo "$line" | grep -P "$row_entity_regex" >/dev/null; then
			ROW_CONSISTENT_ERROR=$(echo $line_num)
			return 1
		fi
	done < "$apmdz_keys_file_path"

	return 0
}


#######################################
#
# 	Функция проверки маркера предудущей записи в файле со списком ключей АПМДЗ
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - запись производилась
#	1 - запись не производилась
#
#######################################

function in_apmdz_row_was_write() {
	local user_hostname="$1"
	local apmdz_keys_file_path="$2"

	local apmdz_write_mark_regex="^[a-z0-9\-]+.(potu|pou).su,[0-9]{4}И,[0-9]{1,2}-[0-9]{1,2}-[0-9]{4}$"

	select_entity_row "$user_hostname" "$apmdz_keys_file_path"

	if echo "$APMDZ_KEYS_SELECTED_ROW" | grep -P "$apmdz_write_mark_regex" >/dev/null; then
		return 0
	fi

	return 1
}


#######################################
#
# 	Функция проверки целестности файла со списком ключей АПМДЗ
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - целостность не нарушена
#	1 - целостность нарушена
#
#######################################

function is_apmdz_file_consistent() {
	local apmdz_keys_file_path="$1"

	if ! is_row_entity_valid "$apmdz_keys_file_path"; then
		echo "Обнаружена ошибка в структуре строки $ROW_CONSISTENT_ERROR файла $apmdz_keys_file_path"
		return 1
	fi

	if have_entity_duplicates "$apmdz_keys_file_path"; then
		echo "Обнаружена ошибка дублирующихся хостнеймов строки $ROW_CONSISTENT_ERROR файла $apmdz_keys_file_path"
		return 1
	fi

	return 0
}


#######################################
#
# 	Функция записи срока оконачания ключа АПМДЗ
#
#	Входные параметры:
#
#	Коды возвратов:
#
#   0 - запись даты успешно выполнена
#   1 - обнаружена ошибка в структуре в файле со списком ключей АПМДЗ
#   2 - пользователь отказался от перезаписи строки в файле со списком ключей АПМДЗ
#
#######################################

function write_end_date_apmdz_key() {	
	local apmdz_keys_file_path="${OUTPUT_DIRECTORY}/apmdz_keys_file.list"

	if [[ ! -f $apmdz_keys_file_path ]] ; then
		generate_apmdz_keys_file "$apmdz_keys_file_path"
	fi

	if ! is_apmdz_file_consistent "$apmdz_keys_file_path"; then
		return 1
	fi

	if ! is_apmdz_keys_entity_exists "$HOSTNAME" "$apmdz_keys_file_path"; then
		add_apmdz_keys_entity "$HOSTNAME" "$apmdz_keys_file_path"
	fi

	if in_apmdz_row_was_write "$HOSTNAME" "$apmdz_keys_file_path"; then
		echo "Обнаружена уже существующая запись для хоста $HOSTNAME в файле со списком ключей АПМДЗ $apmdz_keys_file_path"
		ask_about_exists_apmdz_key
		exit_code=$?
		if [ $exit_code -ne 0 ]; then
			return 2
		fi
	fi

	cat "$apmdz_keys_file_path" | \
	awk -F, -v OFS=, \
			-v date_end="$DATE_END_KEY_APMDZ" \
			-v hostname="$HOSTNAME" \
			-v serial="$SERIAL_NUMBER" \
			-v out_file="$apmdz_keys_file_path" '$1==hostname { $2=serial; $3=date_end } {print > out_file }'

	return 0
}