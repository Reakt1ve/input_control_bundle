#! /bin/bash

. ./src.d/init.sh
. ./src.d/db.sh
. ./src.d/user_interaction.sh
. ./src.d/zps.sh
. ./src.d/packages.sh
. ./src.d/utils.sh
. ./src.d/network.sh
. ./src.d/system.sh
. ./src.d/disk.sh
. ./src.d/raid.sh
. ./src.d/parsers/arg_parser.sh
. ./src.d/parsers/name_parser.sh
. ./src.d/parsers/apmdz_keys_parser.sh


if ! is_root; then
	echo "Скрипт запущен не от прав root пользователя"
	exit 1
fi

### первоначальная инициализация скрипта
parse_script_args
exit_code=$?
if [ $exit_code -ne 0 ]; then
	print_help_screen
	exit 1
fi

start_script
exit_code=$?
if [ $exit_code -eq 1 ]; then
	echo -e "${red}Не были установлены важные для работы скрипта пакеты${normal}" | tee -a ${OUTPUT_FILE}
	exit 1
elif [ $exit_code -eq 2 ]; then
	echo -e "${red}Ошибка обработки sgk_name${normal}" | tee -a ${OUTPUT_FILE}

	stop_script
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		echo -e "${red}Некоторые пакеты скрипта не были успешно удалены${normal}" | tee -a ${OUTPUT_FILE}
	fi

	exit 1
elif [ $exit_code -eq 3 ]; then
	echo -e "${red}Ошибка обработки заданного hostname${normal}" | tee -a ${OUTPUT_FILE}

	stop_script
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		echo -e "${red}Некоторые пакеты скрипта не были успешно удалены${normal}" | tee -a ${OUTPUT_FILE}
	fi

	exit 1
elif [ $exit_code -eq 4 ]; then
	echo -e "${red}Пользователь отказался продолжать с неверным типом СВТ${normal}" | tee -a ${OUTPUT_FILE}

	stop_script
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		echo -e "${red}Некоторые пакеты скрипта не были успешно удалены${normal}" | tee -a ${OUTPUT_FILE}
	fi

	exit 1
fi

print_operator_info_screen

write_end_date_apmdz_key
exit_code=$?
if [ $exit_code -eq 1 ]; then
	echo -e "${red}Обнаружена ошибка в структуре файла со списком ключей АПМДЗ${normal}" | tee -a ${OUTPUT_FILE}

	stop_script
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		echo -e "${red}Некоторые пакеты скрипта не были успешно удалены${normal}" | tee -a ${OUTPUT_FILE}
	fi

	exit 1
elif [ $exit_code -eq 2 ]; then
	echo -e "${red}Произошла отмена записи ключа в файл со списком ключей АПМДЗ${normal}" | tee -a ${OUTPUT_FILE}
fi

if ! is_arch_leningrad; then
	echo -e "${red}Версия ОС не соответствует Ленинград 8.1${normal}" | tee -a ${OUTPUT_FILE}

	stop_script
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		echo -e "${red}Некоторые пакеты скрипта не были успешно удалены${normal}" | tee -a ${OUTPUT_FILE}
	fi

	exit 1
fi
echo "Версия ОС соответствует Ленинград 8.1" | tee -a ${OUTPUT_FILE}

echo "Тип машины (найденный, на основании косвенных признаков): $TYPE" | tee -a ${OUTPUT_FILE}

set_hostname
echo "имя машины: $HOSTNAME" | tee -a ${OUTPUT_FILE}

#вывод серийного номера машины
echo "Серийный номер: $SERIAL_NUMBER" | tee -a ${OUTPUT_FILE}

### Проверка требований дисковой подсистемы сервера
check_devices_requirements
exit_code=$?
if [ $exit_code -eq 1 ]; then
	echo -e "${red}Отсутсвует необходимое кол-во дисков в системе (=4). Проверьте корректность физического подключения${normal}" | tee -a ${OUTPUT_FILE}

	stop_script
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		echo -e "${red}Некоторые пакеты скрипта не были успешно удалены${normal}" | tee -a ${OUTPUT_FILE}
	fi

	exit 1
elif [ $exit_code -eq 2 ]; then
	echo -e "${red}Отсутсвует необходимое кол-во boot разделов (=3). Проверьте разметку дисков через lsblk${normal}" | tee -a ${OUTPUT_FILE} 

	stop_script
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		echo -e "${red}Некоторые пакеты скрипта не были успешно удалены${normal}" | tee -a ${OUTPUT_FILE}
	fi

	exit 1
elif [ $exit_code -eq 3 ]; then
	echo -e "${red}Нарушен порядок инициализации дисковых устройств. Проверьте корректность физического подключения${normal}" | tee -a ${OUTPUT_FILE}

	stop_script
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		echo -e "${red}Некоторые пакеты скрипта не были успешно удалены${normal}" | tee -a ${OUTPUT_FILE}
	fi

	exit 1
fi

get_installed_packages
exit_code=$?
if [ $exit_code -ne 0 ]; then
	echo -e "${red}Поврежден dpkg модуль{normal}" | tee -a ${OUTPUT_FILE} 

	stop_script
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		echo -e "${red}Некоторые пакеты скрипта не были успешно удалены${normal}" | tee -a ${OUTPUT_FILE}
	fi

	exit 1
fi

clear_astra_trash
echo "Вычистка ненужных файлов и папок" | tee -a ${OUTPUT_FILE}
clear_trash_astra_packages
echo "Вычистка ненужных пакетов" | tee -a ${OUTPUT_FILE}

init_repository_from_flash
exit_code=$?
if [ $exit_code -ne 0 ]; then
	echo -e "${red}Произошла отмена инициализации флешки-репозитория${normal}" | tee -a ${OUTPUT_FILE}

	stop_script
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		echo -e "${red}Некоторые пакеты скрипта не были успешно удалены${normal}" | tee -a ${OUTPUT_FILE}
	fi

	exit 1
fi

install_opo_packages
exit_code=$?
if [ $exit_code -ne 0 ]; then
	echo -e "${red}Некоторые пакеты не были успешно установлены${normal}" | tee -a ${OUTPUT_FILE}
	repository_from_flash_umount

	stop_script
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		echo -e "${red}Некоторые пакеты скрипта не были успешно удалены${normal}" | tee -a ${OUTPUT_FILE}
	fi

	exit 1
fi

if is_blackhole_needed; then
	set_blackhole_routes
fi

check_local_admin
exit_code=$?
if [ $exit_code -eq 0 ]; then
	echo "Пользователь admin был изменен на localadm" | tee -a ${OUTPUT_FILE}
elif [ $exit_code -eq 1 ]; then
	echo "Пользователь localadm присутствует в системе в качестве локального администратора" | tee -a ${OUTPUT_FILE}
elif [ $exit_code -eq 2 ]; then
	echo -e "${red}Пользователь admin или localadm не были найдены в системе, поэтому операция замены невозможна${normal}" | tee -a ${OUTPUT_FILE}
	repository_from_flash_umount

	stop_script
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		echo -e "${red}Некоторые пакеты скрипта не были успешно удалены${normal}" | tee -a ${OUTPUT_FILE}
	fi

	exit 1
fi

# Запустить контроль вентиляторов
if is_service_exists "pwmd"; then 
	pwmd -L 92
else
	echo "Приложение контроля вентиляторов отсутствует (pwmd)" | tee -a ${OUTPUT_FILE}
fi

echo "Производится настройка сети..." | tee -a ${OUTPUT_FILE}
check_configure_network
exit_code=$?
if [ $exit_code -ne 0 ]; then
	echo -e "${red}Произошла ошибка во время настройки сетевых параметров${normal}" | tee -a ${OUTPUT_FILE}
	repository_from_flash_umount

	stop_script
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		echo -e "${red}Некоторые пакеты скрипта не были успешно удалены${normal}" | tee -a ${OUTPUT_FILE}
	fi

	exit 1
fi

check_system_packages_install
exit_code=$?
if [ $exit_code -ne 0 ]; then
	echo -e "${red}Некоторые системные пакеты не установлены, что может повлечь ошибки системы${normal}" | tee -a ${OUTPUT_FILE}
	repository_from_flash_umount

	stop_script
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		echo -e "${red}Некоторые пакеты скрипта не были успешно удалены${normal}" | tee -a ${OUTPUT_FILE}
	fi

	exit 1
fi

check_system_packages_version

check_services_active
check_services_autorun

#проверка дисков
get_disk_subsystem_info
check_disks_vendor
exit_code=$?
if [ $exit_code -ne 0 ]; then
	echo -e "${red}Некоторые диски имееют неизвестного производителя${normal}" | tee -a ${OUTPUT_FILE}
	repository_from_flash_umount

	stop_script
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		echo -e "${red}Некоторые пакеты скрипта не были успешно удалены${normal}" | tee -a ${OUTPUT_FILE}
	fi

	exit 1
fi
echo "Все диски имееют вендора INTEL" | tee -a ${OUTPUT_FILE}

check_disks_smart
exit_code=$?
if [ $exit_code -ne 0 ]; then
	echo -e "${red}Некоторые диски повреждены или имеют ошибки${normal}" | tee -a ${OUTPUT_FILE}
	repository_from_flash_umount

	stop_script
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		echo -e "${red}Некоторые пакеты скрипта не были успешно удалены${normal}" | tee -a ${OUTPUT_FILE}
	fi

	exit 1
fi
echo "Все диски в рабочем состоянии" | tee -a ${OUTPUT_FILE}

check_RAID
exit_code=$?
if [ $exit_code -eq 0 ]; then
	echo "Все RAID-массивы настроены" | tee -a ${OUTPUT_FILE}
elif [ $exit_code -eq 1 ]; then
	echo "RAID массив на АРМ Т1 отсутствует" | tee -a ${OUTPUT_FILE}
else
	echo -e "${red}Некоторые RAID-массивы находятся не в консистентном состоянии${normal}" | tee -a ${OUTPUT_FILE}
	repository_from_flash_umount

	stop_script
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		echo -e "${red}Некоторые пакеты скрипта не были успешно удалены${normal}" | tee -a ${OUTPUT_FILE}
	fi

	exit 1
fi

boot_file_validation

#фикс бага с непереходом на новую строку после выполнения скрипта
echo "" >&2

echo "Копирование папки sgk_essential..." | tee -a ${OUTPUT_FILE}
copy_sgk_essential

enable_fullhd
exit_code=$?
if [ $exit_code -eq 0 ]; then
	echo "Режим монитора Full HD включен" | tee -a ${OUTPUT_FILE}
elif [ $exit_code -eq 1 ]; then
	echo "Режим монитора Full HD уже включен" | tee -a ${OUTPUT_FILE}
elif [ $exit_code -eq 3 ]; then
	echo -e "${red}Возникли ошибки при включении режима Full HD${normal}" | tee -a ${OUTPUT_FILE}
	repository_from_flash_umount

	stop_script
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		echo -e "${red}Некоторые пакеты скрипта не были успешно удалены${normal}" | tee -a ${OUTPUT_FILE}
	fi

	exit 1
fi

enable_zps
exit_code=$?
if [ $exit_code -eq 0 ]; then
	init_copy_boot
else
	echo -e "${red}Не удалось включить ЗПС${normal}"

	repository_from_flash_umount

	stop_script
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		echo -e "${red}Некоторые пакеты скрипта не были успешно удалены${normal}" | tee -a ${OUTPUT_FILE}
	fi

	exit 1
fi

render_ntp_conf
echo "Настроены маршруты до ntp серверов" | tee -a ${OUTPUT_FILE}

update_system
exit_code=$?
if [ $exit_code -eq 0 ]; then
	echo "Система обновлена" | tee -a ${OUTPUT_FILE}
	init_copy_boot
elif [ $exit_code -eq 1 ]; then
	echo "Обновление системы не требуется" | tee -a ${OUTPUT_FILE}
elif [ $exit_code -eq 2 ]; then
	echo -e "${red}Не удалось обновить систему${normal}" | tee -a ${OUTPUT_FILE}

	repository_from_flash_umount

	stop_script
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		echo -e "${red}Некоторые пакеты скрипта не были успешно удалены${normal}" | tee -a ${OUTPUT_FILE}
	fi

	exit 1
fi

repository_from_flash_umount

>/etc/apt/sources.list

add_repositories
exit_code=$?
if [ $exit_code -eq 1 ]; then
	echo -e "${red}Файл repository.json не найден в целевой папке. sources.list не настроен${normal}" | tee -a ${OUTPUT_FILE}
elif [ $exit_code -eq 2 ]; then
	echo -e "${red}Файл repository.json является пустым. sources.list не настроен${normal}" | tee -a ${OUTPUT_FILE}
elif [ $exit_code -eq 3 ]; then
	echo -e "${red}Файл repository.json имеет отличную от Unix кодировку. sources.list не настроен${normal}" | tee -a ${OUTPUT_FILE}
else
	echo "sources.list настроен" | tee -a ${OUTPUT_FILE}
fi

if [ $SYNC_BOOT_PARTITIONS -eq 0 ]; then
	echo "Boot разделы синхронизированы" | tee -a ${OUTPUT_FILE}
else
	echo -e "${red}Boot разделы не синхронизированы${normal}" | tee -a ${OUTPUT_FILE}
fi

if is_service_exists "pwmd"; then
	purge_pwmd
	echo "Удален пакет контроля вентиляторов" | tee -a ${OUTPUT_FILE}
fi

get_disks_serial
get_update_version

if is_bonding_server "$HOSTNAME"; then
	echo -e "${orange}Обнаружен bonding${normal}" | tee -a ${OUTPUT_FILE}
fi

stop_script
exit_code=$?
if [ $exit_code -ne 0 ]; then
	echo -e "${red}Некоторые пакеты скрипта не были успешно удалены${normal}" | tee -a ${OUTPUT_FILE}
fi