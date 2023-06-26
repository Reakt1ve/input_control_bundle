#! /bin/bash


#######################################
#
# 	Функция проверки запуска скрипта от имени root пользователя
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - скрипт запущен от имени root пользователя
#	1 - скрипт незапущен от имени root пользователя
#
#######################################

function is_root() {
	if [[ $(whoami) != "root" ]]; then
		return 1
	fi

	return 0
}


#######################################
#
# 	Функция копирования скрипта sgk_essential в папку /usr/doc
#
#	Входные параметры:
#
#	Коды возвратов:
#
#######################################

function copy_sgk_essential() {
	local etalon_sgk_essential_path="../sgk_essential"
	local etalon_rel_network_conf="network.d/network.csv"
	local etalon_full_network_conf="${etalon_sgk_essential_path}/${etalon_rel_network_conf}"

	if [[ ! -d "$etalon_sgk_essential_path" ]]; then
		echo -e "${red}На носителе не найдена папка sgk_essential, не удалось произвести копирование${normal}" | tee -a ${OUTPUT_FILE}
		return 1
	fi

	mkdir -p ./tmp
	cp -a "$etalon_sgk_essential_path" ./tmp

	if [[ ! -f "$etalon_full_network_conf" ]]; then
		echo -e "${red}На носителе не найдена файл network.csv, не удалось произвести копирование${normal}" | tee -a ${OUTPUT_FILE}
		return 2
	fi

	echo "hostname,netmask,ip,gateway," > ./tmp/sgk_essential/network.d/network.csv
	cat "$etalon_full_network_conf" | grep "$HOSTNAME" >> ./tmp/sgk_essential/network.d/network.csv

	cp -a ./tmp/sgk_essential /usr/doc
	rm -r ./tmp

	echo "С носителя папка sgk_essential была скопирована в /usr/doc" | tee -a ${OUTPUT_FILE}

	return 0
}


#######################################
#
# 	Функция проверки существования пользователя в системе
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - пользователь существует
#	1 - пользователь несуществует
#
#######################################

function is_user_exists() {
	local user="$1"

	if cat /etc/passwd | grep "^${user}:" >/dev/null; then
		return 0
	fi

	return 1
}


#######################################
#
# 	Функция замены локального администратора admin на localadm
#
#	Входные параметры:
#
#	Коды возвратов:
#
#######################################

function replace_admin() {
	service xrdp stop
	sed -i 's/^admin:/localadm:/g' /etc/passwd*
	sed -i 's!:/home/admin:!:/home/localadm:!g' /etc/passwd*
	sed -i 's!^admin:!localadm:!g' /etc/group*
	sed -i 's!:admin,!:localadm,!g' /etc/group*
	sed -i 's!:admin$!:localadm!g' /etc/group*
	sed -i 's!^admin:!localadm:!g' /etc/shadow*
	sed -i 's!,admin$!,localadm!g' /etc/group*
	sed -i 's!,admin,!,localadm,!g' /etc/group*
	mv /home/admin /home/localadm
	pdpl-user -z localadm >/dev/null
	pdpl-user -i 63 localadm >/dev/null
	service xrdp start
}


#######################################
#
# 	Функция обработки локального администратора
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - обработка прошла успешно
#	1 - пользователь localadm уже присутствует в системе в качестве локального администратора
#	2 - пользователь admin и localadm отсутствуют системе. Обработка прошла неуспешно 
#
#######################################


function check_local_admin() {
	if is_user_exists "localadm"; then
		return 1
	fi

	if ! is_user_exists "admin"; then
		return 2
	fi

	replace_admin

	return 0
}


#######################################
#
# 	Функция очистки оставшихся данных после тестирования ИНЭУМ
#
#	Входные параметры:
#
#	Коды возвратов:
#
#######################################

function clear_astra_trash() {
	rm -rf /export
	rm -rf /etc/network/*.tar
	rm -rf /etc/systemd/system/network-manager.service
}


#######################################
#
# 	Функция установки хостнейма системы
#
#	Входные параметры:
#
#	Коды возвратов:
#
#######################################

function set_hostname() {
	db_get_ip_address "$HOSTNAME"

	cat << EOF > /etc/hosts
127.0.0.1 localhost 

::1		localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

	hostnamectl set-hostname "$HOSTNAME"
	local insert_text=$(echo "$DB_IP_ADDRESS   ${HOSTNAME}")
	sed -i "/127.0.0.1/a ${insert_text}" /etc/hosts
}


#######################################
#
# 	Функция проверки активного режима Full HD
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - режим активирован
#	1 - режим неактивирован
#
#######################################

function is_enabled_fullhd() {
	if [ -f /etc/X11/xorg.conf.d/10-monitors.conf ]; then
		return 0
	fi

	return 1
}


#######################################
#
# 	Функция активации режима Full HD
#
#	Входные параметры:
#
#	Коды возвратов:
#
#######################################

function enable_fullhd() {
	db_get_server_type "$HOSTNAME"
	local type_in_db=$DB_SERVER_TYPE

	if echo "$type_in_db" | grep "ARM T1" >/dev/null; then
		return 2
	fi


	if is_enabled_fullhd; then
		return 1
	fi

	if [ -f "file.d/10-monitors.conf" ]; then
		cp -a "file.d/10-monitors.conf" /etc/X11/xorg.conf.d/
		echo "С носителя файл 10-monitors.conf был скопирован в /etc/X11/xorg.conf.d/" | tee -a ${OUTPUT_FILE}
	else
		echo -e "${orange}На носителе не найден файл 10-monitors.conf, не удалось произвести копирование${normal}" | tee -a ${OUTPUT_FILE}
		return 3
	fi

	return 0
}


#######################################
#
# 	Функция обновления ядра системы
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - обновление прошло успешно
#	1 - обновление не требуется
#	2 - во время обновления возникли ошибки
#
#######################################

function update_system() {
	check_kernel_version
	exit_code=$?
	if [ $exit_code -eq 0 ]; then
		return 1
	fi

	apt-get install astra-update -y >&2
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		return 2
	fi

	astra-update -A -r -T
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		return 2
	fi

	return 0
}


#######################################
#
# 	Функция динамической отрисовки ntp.conf файла
#
#	Входные параметры:
#
#	Коды возвратов:
#	
#######################################

function render_ntp_conf() {
	db_get_ntp_servers "$HOSTNAME"
	cat ./templates.d/ntp.conf > /etc/ntp.conf

	OLD_IFS=$IFS
	IFS=$' '
	for ntp_server in $DB_NTP_SERVERS; do
		echo "server $ntp_server" >> /etc/ntp.conf
	done
	IFS=$OLD_IFS
}


#######################################
#
# 	Функция проверки архитектуры СВТ
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - архитектура соответствует Эльбрус 
#	1 - архитектура имеет иное происхождение
#
#######################################

function is_arch_leningrad() {
	if ! cat /etc/astra_version | grep "8.1 (leningrad)" >&2; then
		return 1
	fi

	return 0
}


#######################################
#
# 	Функция вывода серийных номеров дисков
#
#	Входные параметры:
#
#	Коды возвратов:
#
#######################################

function get_disks_serial() {
	echo "Номер диска sda $(udevadm info /dev/sda | grep -i id_serial_short | cut -d '=' -f 2)" | tee -a ${OUTPUT_FILE}
	echo "Номер диска sdb $(udevadm info /dev/sdb | grep -i id_serial_short | cut -d '=' -f 2)" | tee -a ${OUTPUT_FILE}
	echo "Номер диска sdc $(udevadm info /dev/sdc | grep -i id_serial_short | cut -d '=' -f 2)" | tee -a ${OUTPUT_FILE}
	echo "Номер диска sdd $(udevadm info /dev/sdd | grep -i id_serial_short | cut -d '=' -f 2)" | tee -a ${OUTPUT_FILE}
}


#######################################
#
# 	Функция вывода текущего обновления ОС
#
#	Входные параметры:
#
#	Коды возвратов:
#
#######################################

function get_update_version() {
	echo "Текущая версия обновления: $(cat /etc/astra_update_version | grep Bulletin)" | tee -a ${OUTPUT_FILE}
}


#######################################
#
# 	Функция проверки соответствия версии ядра требуемому
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - версия ядра соответствует требуемому
#	1 - версия ядра несоответствует требуемому
#
#######################################

function check_kernel_version() {
	local verver=$(uname -a | awk '{$2=""; print $0}')
	if [ "$verver" = "Linux  4.9.0-5-generic-8c #5 SMP PREEMPT Fri Sep 10 18:34:49 MSK 2021 e2k GNU/Linux" ]; then
		echo "Версия ядра совпадает" | tee -a ${OUTPUT_FILE}
		return 0
	fi

	echo -e "${red}Версия ядра НЕ совпадает. Необходимо: Linux  4.9.0-5-generic-8c #5 SMP PREEMPT Fri Sep 10 18:34:49 MSK 2021 e2k GNU/Linux. А у вас ${verver}${normal}" | tee -a ${OUTPUT_FILE}

	return 1
}


#######################################
#
# 	Функция проверки требуемых сервисов в автозагрузке
#
#	Входные параметры:
#
#	Коды возвратов:
#
#######################################

function check_services_autorun() {
	local check_services_list="\
ssh,\
xrdp,\
haveged\
"

	OLD_IFS=$IFS
	IFS=$','
	for service in $check_services_list; do
		if systemctl list-unit-files | grep enabled | grep ${service}.ser >&2; then
			echo "$service имеется в автозапуске" | tee -a ${OUTPUT_FILE}
		else
			systemctl enable $service
			echo -e "${orange}$service добавлен в автозапуск${normal}" | tee -a ${OUTPUT_FILE}
		fi
	done
	IFS=$OLD_IFS
}


#######################################
#
# 	Функция проверки работы требуемых сервисов в фоновом режиме
#
#	Входные параметры:
#
#	Коды возвратов:
#
#######################################

function check_services_active() {
	local check_services_list="\
ssh,\
xrdp,\
haveged\
"

	OLD_IFS=$IFS
	IFS=$','
	for service in $check_services_list; do
		if systemctl | grep ${service}.ser | grep activ >&2; then
			echo "$service сервер был запущен" | tee -a ${OUTPUT_FILE}
		else
			systemctl start ssh
			echo -e "${orange}$service сервер запущен скриптом${normal}" | tee -a ${OUTPUT_FILE}
		fi
	done
	IFS=$OLD_IFS
}


#######################################
#
# 	Функция валидации boot.conf файла
#
#	Входные параметры:
#
#	Коды возвратов:
#
#######################################

function boot_file_validation() {
	if ! cat /boot/boot.conf | grep "sclkr=no$" > /dev/null; then
		echo -e "$(cat /boot/boot.conf | sed 's/ sclkr=no//g' | sed '/cmdline/s/$/ sclkr=no/g')" > /boot/boot.conf
	fi
}


#######################################
#
# 	Функция проверки существования сервиса pwmd
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - сервис существует
#	1 - сервис несуществует
#
#######################################

function is_service_exists() {
	user_service="$1"

	which "$user_service" >/dev/null
	exit_code=$?
	if [ $exit_code -eq 0 ]; then 
		return 0
	fi

	return 1
}
