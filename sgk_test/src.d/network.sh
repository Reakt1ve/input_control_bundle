#! /bin/bash


#######################################
#
# 	Функция проверки необходимости в настройке blackhole правил
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - требуется настройка правил
#	1 - не требуется настройка правил
#
#######################################

function is_blackhole_needed() {
	if db_is_IB_owner "$HOSTNAME"; then
		return 1
	fi

	db_get_blackhole_list "$HOSTNAME"
	local blackhole_list="$DB_BLACKHOLE_LIST"
	if [ -z $blackhole_list ]; then
		return 1
	fi

	return 0
}


#######################################
#
# 	Функция динамической отрисовки blackhole.service файла
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - генерация прошла успешно 
#	1 - отсутствует пакет jq
#
#######################################

function render_blackhole_service() {
	local blackhole_dir_path="$1"

	cp -a ./templates.d/blackhole.service /etc/systemd/system
	sed -i "s#\"путь до скрипта\"#$blackhole_dir_path#g" /etc/systemd/system/blackhole.service 
}


#######################################
#
# 	Функция генерации скрипта blackhole
#
#	Входные параметры:
#
#	Коды возвратов:
#
#######################################

function generate_blackhole_script() {
	local user_hostname="$1"
	local blackhole_dir_path="$2"
	local blackhole_script_path=$(echo "${blackhole_dir_path}/blackhole")

	db_get_blackhole_list "$user_hostname"

	echo -e "#! /bin/bash\n" >"$blackhole_script_path"
	OLD_IFS=$IFS
	IFS=$' '
	for blackhole in $DB_BLACKHOLE_LIST; do
		echo "ip route add blackhole ${blackhole}" >> "$blackhole_script_path"
	done
	IFS=$OLD_IFS
}


#######################################
#
# 	Функция установки blackhole правил
#
#	Входные параметры:
#
#	Коды возвратов:
#
#######################################

function set_blackhole_routes() {
	local blackhole_dir_path="/opt/blackhole"

	mkdir -p "$blackhole_dir_path"
	generate_blackhole_script "$HOSTNAME" "$blackhole_dir_path"

	chmod +x ${blackhole_dir_path}/blackhole

	render_blackhole_service "$blackhole_dir_path"

	systemctl daemon-reload
	systemctl start blackhole
	systemctl enable blackhole
}


#######################################
#
# 	Функция обработки сетевой подсистемы
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - настройка сетевой подсистема прошла успешно
#   1 - настройка через network-manager прошла неуспешно
#
#######################################

function check_configure_network() {
	db_get_server_type "$HOSTNAME"
	local type_in_db=$DB_SERVER_TYPE

	if echo "$type_in_db" | grep "ARM T1" >/dev/null; then
		get_interfaces_info_netmanager
		exit_code=$?
		if [ $exit_code -ne 0 ]; then
			return 1
		fi

		set_wired_conn_default

		return
	fi

	if is_bonding_server "$HOSTNAME"; then
		configure_bonding
	else
		get_interfaces_info_networking
	fi

	set_eth_manual
}

#######################################
#
# 	Функция проверки доступности сетевых интерфейсов
#
#	Входные параметры:
#
#	строка со списком сетевых интерфейсов через пробел
#
#	Возвращаемое значение:
#
#	строка со списком доступных сетевых интерфейсов через пробел
#
#######################################

function check_netdev_avalability() {
	local net_devices_list="$1"
	local exclude_netdev=""

	### Исключение уже добавленных интерфейсов
	exclude_netdev=$(cat /etc/network/interfaces | grep "inet" | cut -d ' ' -f2)
	if [[ ! -z $exclude_netdev ]]; then
		local netdev=""
		local exclude_pattern=""
		OLD_IFS=$IFS
		IFS=$'\n'
		for netdev in $exclude_netdev; do
			exclude_pattern+=" -e ${netdev} "
		done
		IFS=$OLD_IFS
		net_devices_list=$(eval "echo \"$net_devices_list\" | grep -v $exclude_pattern")
	fi

	echo "$net_devices_list"
}


#######################################
#
# 	Функция установки сетевых интерфейсов в режим manual через networking
#
#	Входные параметры:
#
#	Коды возвратов:
#
#######################################

function set_eth_manual() {
	local interfaces_list=$(ls /sys/class/net)
	local filtered_interfaces_list=$(check_netdev_avalability "$interfaces_list")

	local device=""
	OLD_IFS=$IFS
	IFS=$'\n'
	for device in $filtered_interfaces_list; do
		cat << EOF >> /etc/network/interfaces

auto ${device}
iface ${device} inet manual

EOF
	done
	IFS=$OLD_IFS
}


#######################################
#
# 	Функция проверки присутствия bonding 0 у хостнейма
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - хостнейм имеет bonding
#	1 - хостнейм не имеет bonding
#
#######################################

function is_bonding_server() {
	local user_hostname="$1"

	if db_is_hostname_bonding "$user_hostname"; then
		return 0
	fi 

	return 1
}


#######################################
#
# 	Функция динамической отрисовки interfaces.conf файла для bonding
#
#	Входные параметры:
#
#	Коды возвратов:
#
#######################################

function render_bonding_interfaces() {
	local user_hostname="$1"

	db_get_ip_address "$user_hostname"
	db_get_netmask "$user_hostname"
	db_get_gateway "$user_hostname"
	db_get_bonding_slaves "$user_hostname"

	local ip_address="$DB_IP_ADDRESS"
	local netmask="$DB_NETMASK"
	local gateway="$DB_GATEWAY"
	local first_slave=$(echo "$DB_BONDING_SLAVES" | cut -d ' ' -f1)
	local second_slave=$(echo "$DB_BONDING_SLAVES" | cut -d ' ' -f2)

	cat ./templates.d/interfaces.bonding > /etc/network/interfaces
	sed -i "s/\"ip-адрес\"/$ip_address/g" /etc/network/interfaces
	sed -i "s/\"маска сети\"/$netmask/g" /etc/network/interfaces
	sed -i "s/\"шлюз по умолчанию\"/$gateway/g" /etc/network/interfaces
	sed -i "s/\"первый интерфейс\"/$first_slave/g" /etc/network/interfaces
	sed -i "s/\"второй интерфейс\"/$second_slave/g" /etc/network/interfaces
}


#######################################
#
# 	Функция настройки bonding 0 через networking
#
#	Входные параметры:
#
#	Коды возвратов:
#	
#######################################

function configure_bonding() {
	purge_network_manager
	clear_network_interfaces

	render_bonding_interfaces "$HOSTNAME"

	set_dns
	service networking restart
}


#######################################
#
# 	Функция настройки параметров для сетевого интерфейса через networking
#
#	Входные параметры:
#
#	Коды возвратов:
#
#######################################

function set_interfaces_info_networking() {
	local interface="$1"
	local address="$2"
	local netmask="$3"
	local gateway="$4"

	cat << EOF >> /etc/network/interfaces

auto $interface
iface $interface inet static
	address $address
	netmask $netmask
	gateway $gateway
EOF
}


#######################################
#
# 	Функция получения параметров для сетевого интерфейса через networking
#
#	Входные параметры:
#
#	Коды возвратов:
#
#######################################

function get_interfaces_info_networking() {
	purge_network_manager
	clear_network_interfaces

	db_get_ip_address "$HOSTNAME"
	db_get_netmask "$HOSTNAME"
	db_get_gateway "$HOSTNAME"
	db_get_static_eth "$HOSTNAME"
	
	local ip_address="$DB_IP_ADDRESS"
	local netmask="$DB_NETMASK"
	local gateway="$DB_GATEWAY"
	local interface="$DB_ETH"

	set_interfaces_info_networking "$interface" "$ip_address" "$netmask" "$gateway"
	set_dns

	service networking restart
}


#######################################
#
# 	Функция очистки сетевых интерфейсов
#
#	Входные параметры:
#
#	Коды возвратов:
#
#######################################

function clear_network_interfaces() {
	service networking stop
	rm /etc/network/interfaces.d/* 2>/dev/null
	cat ./templates.d/interfaces > /etc/network/interfaces
	ip addr flush label eth*
	service networking start

	### Удаление проводных соединений network-manager если он присутствует в ОС
	if is_service_exists "nmcli"; then
		local exist_connection=$(nmcli con show | awk -F '  ' '$1 != "NAME" {print $1}')
		OLD_IFS=$IFS
		IFS=$'\n'
		for uid in $exist_connection; do
			nmcli con delete "$uid" >/dev/null 2>&1
		done
		IFS=$OLD_IFS
	fi
}


#######################################
#
# 	Функция установки сетевых интерфейсов в режим manual через network-manager
#
#	Входные параметры:
#
#	Коды возвратов:
#
#######################################

function set_wired_conn_default() {
	local net_devices=$(ls /sys/class/net | grep -v lo)
	local conn_number=""
	for net_device in $net_devices; do
		if nmcli --fields DEVICE c s | grep "$net_device" >/dev/null; then
			continue
		fi

		conn_number=$(echo $net_device | cut -d 'h' -f2)
		nmcli con add con-name "Проводное соединение ${conn_number}" ifname $net_device type ethernet >/dev/null
		nmcli con down "Проводное соединение ${conn_number}" >/dev/null
	done
}


#######################################
#
# 	Функция настройки сетевых интерфейсов через network-manager
#
#	Входные параметры:
#
#	Коды возвратов:
#
#######################################

function set_interfaces_info_netmanager() {
	local ip_address="$1"
	local interface="$2"
	local conn_name="$3"
	local gateway="$4"
	local netmask="$5"

	local cidr=$(netmask2cidr "$netmask")
	nmcli con add con-name "$conn_name" ifname "$interface" autoconnect yes type ethernet ip4 "${ip_address}/${cidr}" gw4 "$gateway" >/dev/null
	nmcli con up "$conn_name" >/dev/null
}


#######################################
#
# 	Функция получения параметров сетевых интерфейсов через network-manager
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - настройка сети через network-manager прошла успешно
#	1 - невозможно установить network-manager
#
#######################################

function get_interfaces_info_netmanager() {
	clear_network_interfaces

	if is_service_exists "nmcli"; then
		### Проверка работоспособности Network Manager
		if service NetworkManager status | grep masked >&2; then
			systemctl unmask NetworkManager
			service NetworkManager start
		elif service NetworkManager status | grep inactive >&2; then
			service NetworkManager start
		fi
	else    
		install_package_repo "network-manager*"
		local exit_code=$?   
		if [ $exit_code -ne 0 ]; then
			echo -e "${orange}Пакет network-manager не был успешно установлен${normal}" | tee -a ${OUTPUT_FILE}
			return 1           
		fi
	fi


	db_get_ip_address "$HOSTNAME"
	db_get_netmask "$HOSTNAME"
	db_get_gateway "$HOSTNAME"
	db_get_static_eth "$HOSTNAME"

	#применение настроек плана
	local ip_address="$DB_IP_ADDRESS"
	local netmask="$DB_NETMASK"
	local gateway="$DB_GATEWAY"
	local interface="$DB_ETH"

	set_interfaces_info_netmanager "$ip_address" "$interface" "Проводное соединение 1" "$gateway" "$netmask"
	set_dns "Проводное соединение 1"

	service NetworkManager restart

	return 0
}


#######################################
#
# 	Функция динамической отрисовки resolv.conf файла
#
#	Входные параметры:
#
#	Коды возвратов:
#
#######################################

function render_resolv() {
	local user_hostname="$1"

	echo > /etc/resolv.conf

	db_get_dns_servers "$HOSTNAME"
	OLD_IFS=$IFS
	IFS=$' '
	for dns_server in $DB_DNS_SERVERS; do
		echo "nameserver $dns_server" >> /etc/resolv.conf
	done
	IFS=$OLD_IFS
}


#######################################
#
# 	Функция установки dns параметров в network-manager
#
#	Входные параметры:
#
#	Коды возвратов:
#
#######################################

function configure_network_manager_dns() {
	db_get_dns_servers "$HOSTNAME"
	nmcli con mod "$wired_conn_name" ipv4.dns "$DB_DNS_SERVERS" 
}


#######################################
#
# 	Функция установки dns параметров
#
#	Входные параметры:
#
#	Коды возвратов:
#
#######################################

function set_dns() {
	local wired_conn_name="$1"

	if [ -z "$wired_conn_name" ]; then
		render_resolv "$HOSTNAME"
		
	else
		configure_network_manager_dns
	fi
}
