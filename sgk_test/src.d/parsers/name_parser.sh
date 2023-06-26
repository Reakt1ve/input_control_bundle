#! /bin/bash

SGK_NAME_PATH="./sgk_name"

OPERATOR_FULL_NAME=""
OPERATOR_POSITION=""
OPERATOR_DEPARTMENT=""


#######################################
#
# 	Функция, проверяющая существование файла sgk_name 
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - файл существует
#	1 - файл несуществует
#
#######################################

function is_sgk_name_exists() {
	if [ ! -f $SGK_NAME_PATH ]; then
		return 1
	fi

	return 0
}


#######################################
#
# 	Функция, возвращающая значение 'ФИО' из файла sgk_name
#
#	Входные параметры:
#
#	Возвращаемое значение:
#
#	переменная 'OPERATOR_FULL_NAME'
#
#	Коды возвратов:
#
#	0 - значение возвращено
#	1 - значение в файле sgk_name некорректно
#
#######################################

function get_full_name() {
	local full_name_regex="^([А-я]+)[\s]+([A-я]+)([\s]+[А-я]+)?$"
	local full_name="$(cat $SGK_NAME_PATH | grep "ФИО" | cut -d ':' -f2 | xargs)"

	if ! echo "$full_name" | grep -P "$full_name_regex" >/dev/null; then
		return 1
	fi

	OPERATOR_FULL_NAME="$full_name"

	return 0
}


#######################################
#
# 	Функция, возвращающая значение 'Должность' из файла sgk_name
#
#	Входные параметры:
#
#	Возвращаемое значение:
#
#	переменная 'OPERATOR_POSITION'
#
#	Коды возвратов:
#
#	0 - значение возвращено
#	1 - значение в файле sgk_name некорректно
#
#######################################

function get_position() {
	local position_regex="^[А-я\s]+$"
	local position="$(cat $SGK_NAME_PATH | grep "Должность" | cut -d ':' -f2 | xargs)"

	if ! echo "$position" | grep -P "$position_regex" >/dev/null; then
		return 1
	fi

	OPERATOR_POSITION="$position"

	return 0
}


#######################################
#
# 	Функция, возвращающая значение 'Отдел' из файла sgk_name
#
#	Входные параметры:
#
#	Возвращаемое значение:
#
#	переменная 'OPERATOR_DEPARTMENT'
#
#	Коды возвратов:
#
#	0 - значение возвращено
#	1 - значение в файле sgk_name некорректно
#
#######################################

function get_department() {
	local department_regex="^[А-я\s]+$"
	local department="$(cat $SGK_NAME_PATH | grep "Отдел" | cut -d ':' -f2 | xargs)"
	
	if ! echo "$department" | grep -P "$department_regex" >/dev/null; then
		return 1
	fi

	OPERATOR_DEPARTMENT="$department"

	return 0
}


#######################################
#
# 	Функция, обрабатывающая файл sgk_name
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - обработка файла sgk_name прошла успешно
#	1 - отсутствует файл sgk_name
#	2 - параметр в файле skg_name некорректен
#
#######################################

function parse_sgk_name() {
	if ! is_sgk_name_exists; then
		echo -e "${red}Отсутвует файл sgk_name в корне скрипта${normal}"
		return 1
	fi

	get_full_name
	local exit_code=$?
	if [ $exit_code -ne 0 ]; then
		echo -e "${red}Неверный параметр 'ФИО' в файле sgk_name${normal}"
		return 2
	fi

	get_position
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		echo -e "${red}Неверный параметр 'Должность' в файле sgk_name${normal}"
		return 2
	fi

	get_department
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		echo -e "${red}Неверный параметр 'Отдел' в файле sgk_name${normal}"
		return 2
	fi

	return 0
}