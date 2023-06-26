#! /bin/bash

HOSTNAME=""
SERIAL_NUMBER=""
DATE_END_KEY_APMDZ=""


#######################################
#
# 	Функция, которая агрегирует аргументы скрипта в более удобный вид
#
#	Входные параметры:
#
#	Возвращаемое значение:
#
#	Строка, содержащая параметры скрипта через пробел
#
#######################################

function get_opts() {
	local len_index=${#BASH_ARGV[@]}
	declare -a list_opts
	local let list_opts_idx=0

	local size_index=""
	if [[ "$len_index" > "0" ]]; then
		local size_index=$(expr $len_index - 1)
		for i in $(seq ${size_index} -1 0); do
			list_opts[$list_opts_idx]=${BASH_ARGV[$i]}
			(( list_opts_idx++ ))
		done

		printf '%s ' "${list_opts[@]}"
	else
		echo "empty"
	fi
}


#######################################
#
# 	Функция, проверяющая корректность входных параметров скрипта
#
#	Входные параметры:
#
#	Строка, содержащая параметры скрипта через пробел
#
#	Возвращаемое значение:
#
#	переменная 'HOSTNAME'
#	переменная 'SERIAL_NUMBER'
#	переменная 'DATE_END_KEY_APMDZ'	
#
#	Коды возвратов:
#
#	0 - параметры скрипта корректны
#	1 - параметры скрипта некорректны
#
#######################################

function script_args_validation() {
	local user_opts="$1"

	local hostname_regex="^[a-z0-9\-]+.(potu|pou).su$"
	local serial_number_regex="^[0-9]{4}И$"
	local date_end_key_apmdz_regex="^[0-9]{1,2}-[0-9]{1,2}-[0-9]{4}$"

	local hostname=$(echo "$user_opts" | cut -d ' ' -f1)
	local serial_number=$(echo "$user_opts" | cut -d ' ' -f2)
	local date_end_key_apmdz=$(echo "$user_opts" | cut -d ' ' -f3)

	if ! echo "$hostname" | grep -E "$hostname_regex" >/dev/null; then
		return 1
	fi

	if ! echo "$serial_number" | grep -E "$serial_number_regex" >/dev/null; then
		return 1
	fi

	if ! echo $date_end_key_apmdz | grep -E "$date_end_key_apmdz_regex" >/dev/null; then
		return 1
	fi		

	HOSTNAME="$hostname"
	SERIAL_NUMBER="$serial_number"
	DATE_END_KEY_APMDZ="$date_end_key_apmdz"

	return 0
}


#######################################
#
# 	Функция, обрабатывающая входные параметры скрипта
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - обработка параметров скрипта прошла успешно
#	1 - входные параметры скрипта отсутствуют
#	2 - один из параметров скрипта некорректен
#
#######################################

function parse_script_args() {
	local user_opts=$(get_opts)
	if echo "$user_opts" | grep "empty" >/dev/null; then
		return 1
	fi

	script_args_validation "$user_opts"
	local exit_code=$?
	if [ $exit_code -ne 0 ]; then
		return 2
	fi

	return 0
}
