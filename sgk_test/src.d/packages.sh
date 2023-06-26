#! /bin/bash


#######################################
#
# 	Функция добавления требуемых репозиториев
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - добавление репозиторией прошло успешно
#	1 - файл repository.json не найден 
#	2 - файл repository.json пуст
#	3 - файл repository.json имеет неверную кодировку
#
#######################################

function add_repositories() {
	local json_file="./db/repository.json"

	if [[ ! -f "$json_file" ]]; then
		return 1
	fi

	if [[ ! -s "$json_file" ]]; then
		return 2
	fi

	local file_encoding=$(file "$json_file")
	if echo "$file_enconding" | grep "line terminators"; then
		return 3
	fi

	local path=""
	local os=""
	local pools=""

	db_get_repo_ip "$HOSTNAME"
	db_get_repo_main "$HOSTNAME"

	local repo_ip=$(echo "$DB_REPO_IP_ADDRESS")

	local added_repo_sources_list=""

	OLD_IFS=$IFS
	IFS=';'
	for main_repo_row in $DB_REPO_MAIN_LIST; do
		path=$(echo "$main_repo_row" | cut -d '|' -f1)
		os=$(echo "$main_repo_row" | cut -d '|' -f2)
		pools=$(echo "$main_repo_row" | cut -d '|' -f3)
		added_repo_sources_list+="deb http://${repo_ip}${path} ${os} ${pools}\n"
	done
	IFS=$OLD_IFS

	### Добавить записи об основных репозиториях
	echo -e "$added_repo_sources_list" >> /etc/apt/sources.list

	return 0
}


#######################################
#
# 	Функция удаления пакета pwmd
#
#	Входные параметры:
#
#	Коды возвратов:
#
#######################################

function purge_pwmd() {
	rm -r /usr/bin/pwmd
	rm -r /usr/sbin/pwmd
	rm -r /etc/init.d/pwmd.sh
}


#######################################
#
# 	Функция удаления пакета network-manager
#
#	Входные параметры:
#
#	Коды возвратов:
#
#######################################

function purge_network_manager() {
	systemctl unmask network-manager >/dev/null 2>&1
	apt-get purge -y network-manager* 2>&1 >/dev/null
	rm -rf /etc/NetworkManager
}

#######################################
#
# 	Функция обработки флешки-репозиторий
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - обработка прошла успешно
#	1 - во время обработки появились ошибки
#
#######################################

function init_repository_from_flash() {
	echo "Локальный репозиторий неверный. Идет инициализация флешки-репозитория..."

	while true; do
		repository_from_flash_mount
		exit_code=$?
		if [ $exit_code -eq 0 ]; then
			break
		elif [ $exit_code -eq 1 ]; then
			echo "На флешке-репозиторий отсутствуют iso файлы. Добавьте файлы и вставьте флешку-репозиторий в usb разъем"
		elif [ $exit_code -eq 2 ]; then
			echo "Файл iso не содержит дистрибутив. Добавьте корректный iso файл"
		fi

		ask_about_flash_repository
		exit_code=$?
		if [ $exit_code -ne 0 ]; then
			return 1
		fi
	done

	return 0
}


#######################################
#
# 	Функция автоматического монтирования флешки-репозитория
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - монтирование прошло успешно
#	1 - на флешке-репозиторий отсутствуют iso файлы
#	2 - файл iso не содержит дистрибутив
#
#######################################

FLASH_MOUNTED_REPO_PATHS=""
function repository_from_flash_mount() {
	local flash_drivers_formats="HPFS/NTFS/exFAT|Microsoft\ basic\ data|FAT32"
	declare -A madatory_iso_files=( \
		[mounted-main-leningrad]="false" \
		[update-3-main-leningrad]="false" \
	)
	local madatory_ext="iso"
	local root_mount="/tmp"
	local flash_mount="/mnt"

	local flash_device_files=$(ls "$flash_mount" | xargs)

	local base=""
	local ext=""

	OLD_IFS=$IFS
	IFS=$' '
	for file in $flash_device_files; do
		base=$(echo "$file" | rev | cut -d "." -f2 | rev)
		ext=$(echo "$file" | rev | cut -d "." -f1 | rev)
		if ! echo "$ext" | grep "^${madatory_ext}$" >/dev/null; then
			continue
		fi

		for check_file in ${!madatory_iso_files[@]}; do
			if echo "$base" | grep "^$check_file$" >/dev/null; then
				madatory_iso_files[$check_file]="true"
			fi
		done
	done
	IFS=$OLD_IFS

	local let is_checked_counter=0
	for is_checked in ${madatory_iso_files[@]}; do
		if echo "$is_checked" | grep "true" >/dev/null; then
			((is_checked_counter++))
		fi
	done

	sed -i 's/^deb/#deb/g' /etc/apt/sources.list
	if [ $is_checked_counter -eq 2 ]; then
		for madatory_file in ${!madatory_iso_files[@]}; do
			local full_mount_point="${root_mount}/${madatory_file}"
			mkdir -p $full_mount_point
			2>/dev/null mount "${flash_mount}/${madatory_file}.${madatory_ext}" ${full_mount_point} 2>/dev/null
			echo "deb file:${full_mount_point} leningrad main non-free contrib" >> /etc/apt/sources.list
			FLASH_MOUNTED_REPO_PATHS+="deb file:${full_mount_point} leningrad main non-free contrib;"
		done

		apt-get update >/dev/null 2>/dev/null
		exit_code=$?
		if [ $exit_code -ne 0 ]; then
			for madatory_file in ${!madatory_iso_files[@]}; do
				local full_mount_point="${root_mount}/${madatory_file}"
				umount $full_mount_point
				rm -r $full_mount_point
				sed -i -e "\!file:${full_mount_point}!d" /etc/apt/sources.list
			done
			sed -i 's/^#deb/deb/g' /etc/apt/sources.list

			return 2
		fi

		return 0
	fi

	return 1
}


#######################################
#
# 	Функция автоматического размонтирования флешки-репозитория
#
#	Входные параметры:
#
#	Коды возвратов:
#
#######################################

function repository_from_flash_umount() {
	OLD_IFS=$IFS
	IFS=$';'
	for full_path_umount in $FLASH_MOUNTED_REPO_PATHS; do
		umount $(echo "$full_path_umount" | cut -d ':' -f2 | cut -d ' ' -f1)
		rm -r $(echo "$full_path_umount" | cut -d ':' -f2 | cut -d ' ' -f1)
		sed -i -e "\!${full_path_umount}!d" /etc/apt/sources.list
	done
	IFS=$OLD_IFS

	sed -i 's/^#deb/deb/g' /etc/apt/sources.list

	echo "Флешка-репозиторий размонтирована"
}


#######################################
#
# 	Функция установки пакетов через репозиторий
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - установка прошла успешно
#	1 - установка прошла неуспешно
#
#######################################

function install_package_repo() {
	local package_name="$1"

	apt install ${package_name} -o Dpkg::Options::="--force-confnew" --force-yes -y &> /dev/null
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		return 1
	fi

	return 0
}


#######################################
#
# 	Функция установки пакетов через deb пакет
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - установка прошла успешно
#	1 - установка прошла неуспешно
#
#######################################

function install_package_deb() {
	local package_dirname="$1"
	local package_workdir="packages.d/${package_dirname}"

	apt install ./${package_workdir}/* -o Dpkg::Options::="--force-confnew" --force-yes -y &> /dev/null
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		return 1
	fi

	return 0
}


#######################################
#
# 	Функция очистки лишних пакетов из системы
#
#	Входные параметры:
#
#	Коды возвратов:
#
#######################################

function clear_trash_astra_packages() {
	if echo "${PAK}" | grep ^ifenslave >/dev/null && ! is_bonding_server "$HOSTNAME"; then
		apt-get purge -y ifenslave 2>&1 >/dev/null
	fi
}


#######################################
#
# 	Функция установки требуемых ОПО пакетов
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - установка ОПО пакета прошло успешно
#	1 - установка ОПО пакета прошла неуспешно
#
#######################################

function install_opo_packages() {
	local CERT_PACKAGES_LIST="\
astra-digsig-oldkeys,\
ntpdate,\
sysstat,\
xrdp,\
xorgxrdp,\
tigervnc-common,\
tigervnc-standalone-server,\
haveged,\
binutils,\
smartmontools,\
ssh,\
ethtool,\
ntp\
"

	local STANDALONE_PACKAGES_LIST="\
"

	local let error_founded=0

	### Установка по-ситуации
	if is_bonding_server "$HOSTNAME"; then
		install_package_repo "ifenslave"
		local exit_code=$?
		if [ $exit_code -ne 0 ]; then
			echo -e "${orange}Пакет ifenslave не был успешно установлен${normal}" | tee -a ${OUTPUT_FILE}
			((error_founded++))
		else
			echo "Пакет ifenslave успешно установлен" | tee -a ${OUTPUT_FILE}
		fi
	fi

	OLD_IFS=$IFS
	IFS=$','
	for cert_package_name in $CERT_PACKAGES_LIST; do
		install_package_repo "$cert_package_name"
		local exit_code=$?
		if [ $exit_code -ne 0 ]; then
			echo -e "${orange}Пакет ${cert_package_name} не был успешно установлен${normal}" | tee -a ${OUTPUT_FILE}
			((error_founded++))
		else
			echo "Пакет ${cert_package_name} успешно установлен" | tee -a ${OUTPUT_FILE}
		fi
	done

	for stand_package_name in $STANDALONE_PACKAGES_LIST; do
		install_package_deb "$stand_package_name"
		local exit_code=$?
		if [ $exit_code -ne 0 ]; then
			echo -e "${orange}Пакет ${stand_package_name} не был успешно установлен${normal}" | tee -a ${OUTPUT_FILE}
			((error_founded++))
		else
			echo "Пакет ${stand_package_name} успешно установлен" | tee -a ${OUTPUT_FILE}
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
# 	Функция получение списка установленных пакетов
#
#	Входные параметры:
#
#	Возвращаемое значение:
#
#	переменная PAK
#
#	Коды возвратов:
#
#	0 - получение пакетов прошло успешно
#	1 - получение пакетов прошло неуспешно
#
#######################################

PAK=""
function get_installed_packages() {
	PAK=$(dpkg -l | grep ^ii | awk '{print $2}')
	local exit_code=$?

	if [ $exit_code -ne 0 ]; then
		return 1
	fi

	return 0
}


#######################################
#
# 	Функция проверки требуемых системных пакетов
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - все системные пакеты присутствуют в системе
#	1 - некоторые системные пакеты отсутсвуют в системе
#
#######################################

function check_system_packages_install() {
	local check_install_packages="\
python2.7,\
python3\
"

	local let error_founded=0
	local let package_installed=0
	local package_version=""
	local exit_code=""

	OLD_IFS=$IFS
	IFS=$','
	for package in $check_install_packages; do
		OLD_OLD_IFS=$IFS
		IFS=$','
		for installed_package in $PAK; do
			if echo "$package" | grep "^$installed_package" >&2; then
				echo "${package} установлен в системе" | tee -a ${OUTPUT_FILE}
				package_installed=1
				break
			fi
		done
		IFS=$OLD_OLD_IFS

		if [ $package_installed -eq 0 ] ; then
			echo -e "${orange}Пакет ${package} отсутствует в системе${normal}" | tee -a ${OUTPUT_FILE}
			((error_founded++))
		fi

		package_installed=0
	done
	IFS=$OLD_IFS

	if [ $error_founded -ne 0 ]; then
		return 1
	fi

	return 0
}


#######################################
#
# 	Функция проверки требуемых системных пакетов
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - все системные пакеты присутствуют в системе
#	1 - некоторые системные пакеты отсутсвуют в системе
#
#######################################

function check_system_packages_version() {
	local check_install_packages="\
python2.7,\
python3\
"

	local package_version=""

	OLD_IFS=$IFS
	IFS=$','
	for package in $check_install_packages; do
		package_version=$($package --version 2>&1) 
		exit_code=$?
		if [ $exit_code -ne 0 ]; then
			echo -e "${orange}Невозможно определить версию пакета${normal}" | tee -a ${OUTPUT_FILE}
		else
			echo -e "Версия ${package} - ${package_version}" | tee -a ${OUTPUT_FILE}
		fi
	done
}
