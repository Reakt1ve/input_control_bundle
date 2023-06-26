#! /bin/bash


#######################################
#
# 	Функция инициализации скрипта
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - инциализация прошла успешно
#	1 - не удалось установить важные для скрипта пакеты
#	2 - возникла ошибка во время обработки файла sgk_name
#	3 - заданный хостнейм в параметрах скрипта не был найден в базе данных
#	4 - пользователь отказался продолжать с неверным типом СВТ 
#
#######################################

function start_script() {
	#перенаправление потоков
	#exec 1> >(tee  ${3})
	exec 2>/dev/null

	set_fonts_color

	echo "Установка важных для скрипта пакетов..." | tee -a ${OUTPUT_FILE}
	install_script_eseential_packages
	local exit_code=$?
	if [ $exit_code -ne 0 ]; then
		return 1
	fi

	parse_sgk_name
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		return 2
	fi

	if ! is_hostname_exists; then
		return 3
	fi

	if ! is_server_type_valid; then
		ask_about_invalid_server_type
		exit_code=$?
		if [ $exit_code -ne 0 ]; then
			return 4
		fi
	fi

	create_log_file
	create_output_directory
	create_doc_directory

	return 0
}


#######################################
#
# 	Функция установки цвета шрифтов
#
#	Входные параметры:
#
#	Коды возвратов:
#
#######################################

function set_fonts_color() {
	red='\033[0;31m'
	normal='\033[0m'
	orange='\033[33m'
}


#######################################
#
# 	Функция создания папки с лог файлами outputs
#
#	Входные параметры:
#
#	Коды возвратов:
#
#######################################

OUTPUT_DIRECTORY="./outputs"

function create_output_directory() {
	if [[ ! -d "$OUTPUT_DIRECTORY" ]]; then
		mkdir "$OUTPUT_DIRECTORY"
	fi
}


#######################################
#
# 	Функция создания папки для сторонних файлов
#
#	Входные параметры:
#
#	Коды возвратов:
#
#######################################

function create_doc_directory() {
	if [[ ! -d "/usr/doc" ]]; then
		mkdir -p /usr/doc
	fi
}


#######################################
#
# 	Функция проверки существования переданного хостнейма в параметрах скрипта
#
#	Входные параметры:
#
#	строка с хостнеймом
#
#	Коды возвратов:
#
#	0 - хостнейм существует в базе данных
#	1 - хостнейм не существует в базе данных
#
#######################################

function is_hostname_exists() {
	local user_hostname="$1"
	
	if ! db_is_hostname_exists "$user_hostname"; then
		echo -e "${red}Не найден заданный хостнейм в базе${normal}" | tee -a ${OUTPUT_FILE}
		return 1
	fi

	return 0
}


#######################################
#
# 	Функция проверки типа СВТ
#
#	Входные параметры:
#
#	строка с хостнеймом
#
#	Коды возвратов:
#
#	0 - обнаруженный тип сходится с типом в базе данных
#	1 - обнаруженный тип не сходится с типом в базе данных
#
#######################################

function is_server_type_valid() {
	db_get_server_type "$HOSTNAME"
	local type_in_db=$DB_SERVER_TYPE

	check_server_type

	if ! echo "$TYPE" | grep "$type_in_db" >/dev/null; then
		return 1
	fi

	return 0
}


#######################################
#
# 	Функция создания лог файла
#
#	Входные параметры:
#
#	Возвращаемое значение:
#
#	переменная OUTPUT_FILE
#
#	Коды возвратов:
#
#######################################

OUTPUT_FILE=""
LOG_DIRECTORY="${OUTPUT_DIRECTORY}/logs"

function create_log_file() {
	if [[ ! -d "$LOG_DIRECTORY" ]]; then
		mkdir "$LOG_DIRECTORY"
	fi

	OUTPUT_FILE="${LOG_DIRECTORY}/${HOSTNAME}_${SERIAL_NUMBER}"
	>${OUTPUT_FILE}
}


#######################################
#
# 	Функция определения типа СВТ по косвенным признакам, собранных в системе
#
#	Входные параметры:
#
#	Возвращаемое значение:
#
#	переменная TYPE
#
#	Коды возвратов:
#
#######################################

TYPE=""

function check_server_type() {
	if cat /proc/partitions | grep sdn >&2; then
		TYPE="SHD T1"
		return 0
	fi

	TYPE="server "
	
	local sockets=$(lscpu | grep Сокетов | awk '{print $2}')
	if [ "$sockets" == "2" ]; then
		TYPE="${TYPE}T2"
	elif [ "$sockets" == "4" ]; then
		TYPE="${TYPE}T1"
	elif [ "$sockets" == "1" ]; then
		TYPE="ARM T1"
	else
		TYPE="неизвестно"
		return 1
	fi

	return 0
}


#######################################
#
# 	Функция установки важных пакетов скрипта
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - установка прошло успешно
#	1 - не удалось удалить пакеты скрипта
#
#######################################

function install_script_eseential_packages() {
	local script_essential_packages_dir="\
jq\
"
	local let error_founded=0

	OLD_IFS=$IFS
	IFS=$','
	for essential_package in $script_essential_packages_dir; do
		install_package_deb "$essential_package"
		local exit_code=$?
		if [ $exit_code -ne 0 ]; then
			echo -e "${orange}Пакет ${essential_package} не был успешно установлен${normal}" | tee -a ${OUTPUT_FILE}
			((error_founded++))
		else
			echo "Пакет ${essential_package} успешно установлен" | tee -a ${OUTPUT_FILE}
		fi
	done
	IFS=$OLD_IFS

	if [ $error_founded -ne 0 ]; then
		return 1
	fi

	return 0
}


#######################################
#
# 	Функция завершения скрипта
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - завершение прошло успешно
#	1 - не удалось удалить пакеты скрипта
#
#######################################

function stop_script() {
	echo "Удаление оставшихся пакетов скрипта..." | tee -a ${OUTPUT_FILE}
	purge_script_essential_packages
	local exit_code=$?
	if [ $exit_code -ne 0 ]; then
		return 1
	fi

	return 0
}


#######################################
#
# 	Функция удаления важных пакетов скрипта
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - удаление прошло успешно
#	1 - не удалось удалить пакеты скрипта
#
#######################################

function purge_script_essential_packages() {
	local script_essential_purge_list="\
jq,\
libjq1,\
libonig4\
"
	local let error_founded=0
	
	OLD_IFS=$IFS
	IFS=$','
	for essential_package in $script_essential_purge_list; do
		apt-get purge -y "$essential_package" 2>&1 >/dev/null
		local exit_code=$?
		if [ $exit_code -ne 0 ]; then
			echo -e "${orange}Пакет ${essential_package} не был успешно удален${normal}" | tee -a ${OUTPUT_FILE}
			((error_founded++))
		fi
	done
	IFS=$OLD_IFS

	if [ $error_founded -ne 0 ]; then
		return 1
	fi

	return 0
}