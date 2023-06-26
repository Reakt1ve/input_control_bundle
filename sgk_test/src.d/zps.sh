#! /bin/bash

DIGSIG_DIRECTORY="/etc/digsig/keys"


#######################################
#
# 	Функция импортирования электронных ключей-подписей для ЗПС
#
#	Входные параметры:
#
#	Коды возвратов:
#
#######################################

function import_security_keys() {
	cp -a security_keys/css/*.gpg "${DIGSIG_DIRECTORY}"

	cp -a security_keys/rubin/*.gpg "${DIGSIG_DIRECTORY}"

	mkdir -p "${DIGSIG_DIRECTORY}/legacy/"

	cp -a security_keys/root/*.gpg "${DIGSIG_DIRECTORY}/legacy/"

	mkdir -p "${DIGSIG_DIRECTORY}/legacy/kaspersky/"
	cp -a security_keys/kaspersky/*.gpg "${DIGSIG_DIRECTORY}/legacy/kaspersky/"

	mkdir -p "${DIGSIG_DIRECTORY}/legacy/drweb/"
	cp -a security_keys/drweb/*.gpg "${DIGSIG_DIRECTORY}/legacy/drweb/"

	mkdir -p "${DIGSIG_DIRECTORY}/legacy/cryptopro/"
	cp -a security_keys/cryptopro/*.gpg "${DIGSIG_DIRECTORY}/legacy/cryptopro/"
}


#######################################
#
# 	Функция удаления сторонних ключей-подписей для ЗПС
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - произошло удаление сторонних ключей
#	1 - стороние ключи не были обнаружены
#
#######################################

function clear_digsig_keys() {
	local keys_fs_objects_paths=" \
/etc/digsig/keys/ssec_pub_key.gpg \
/etc/digsig/keys/nii-rubin_pub.gpg \
/etc/digsig/keys/legacy \
/etc/digsig/keys/legacy/kaspersky \
/etc/digsig/keys/legacy/kaspersky/kaspersky_astra_pub_key.gpg \
/etc/digsig/keys/legacy/drweb \
/etc/digsig/keys/legacy/drweb/digsig.gost.gpg \
/etc/digsig/keys/legacy/cryptopro \
/etc/digsig/keys/legacy/cryptopro/cryptopro_pub_key.gpg \
/etc/digsig/keys/legacy/key_for_signing_2010.gpg \
/etc/digsig/keys/legacy/key_for_signing_2015.gpg \
/etc/digsig/keys/legacy/primary_key_2010.gpg \
/etc/digsig/keys/legacy/primary_key_2015.gpg \
"

	local let error_founded=0

	local current_keys_dir_files=$(find ${DIGSIG_DIRECTORY}/ -type f | tr '\n' ' ')
	local current_keys_dir=$(find ${DIGSIG_DIRECTORY}/ -mindepth 1 -type d | tr '\n' ' ')
	local current_keys_content=$(echo "${current_keys_dir_files}${current_keys_dir}")

	if [ -z "$current_keys_content" ]; then
		return 1
	fi

	OLD_IFS=$IFS
	IFS=$' '
	local let is_iter_objects_ended=1
	for current_key_content in $current_keys_content; do
		for key_fs_object_path in $keys_fs_objects_paths; do
			if echo "$current_key_content" | grep "^$key_fs_object_path$" > /dev/null; then
				is_iter_objects_ended=0
				break
			fi
		done
		
		if [ $is_iter_objects_ended -eq 1 ]; then
			rm -rf "${current_key_content}" > /dev/null
			let error_founded=1
		fi
		is_iter_objects_ended=1
	done
	IFS=$OLD_IFS

	if [ $error_founded -eq 1 ]; then
		return 0
	fi

	return 1
}


#######################################
#
# 	Функция проверки импортирования требуемых ключей-подписей
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - все требумые ключи импортированы
#	1 - отсутствует требуемый ключ
#
#######################################

function is_security_keys_imported() {
	if ! [ -f "${DIGSIG_DIRECTORY}/ssec_pub_key.gpg" ]; then
		return 1
	elif ! [ -f "${DIGSIG_DIRECTORY}/nii-rubin_pub.gpg" ]; then
		return 1
	elif ! [ -f "${DIGSIG_DIRECTORY}/legacy/kaspersky/kaspersky_astra_pub_key.gpg" ]; then
		return 1
	elif ! [ -f "${DIGSIG_DIRECTORY}/legacy/drweb/digsig.gost.gpg" ]; then
		return 1
	elif ! [ -f "${DIGSIG_DIRECTORY}/legacy/cryptopro/cryptopro_pub_key.gpg" ]; then
		return 1
	elif ! [ -f "${DIGSIG_DIRECTORY}/legacy/key_for_signing_2010.gpg" ]; then
		return 1
	elif ! [ -f "${DIGSIG_DIRECTORY}/legacy/key_for_signing_2015.gpg" ]; then
		return 1
	elif ! [ -f "${DIGSIG_DIRECTORY}/legacy/primary_key_2010.gpg" ]; then
		return 1
	elif ! [ -f "${DIGSIG_DIRECTORY}/legacy/primary_key_2015.gpg" ]; then
		return 1
	fi

	return 0
}


#######################################
#
# 	Функция проверки активного ЗПС
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - ЗПС включен
#	1 - ЗПС выключен
#
#######################################

function is_enabled_zps() {
	if astra-digsig-control is-enabled | grep "ВЫКЛЮЧЕНО" >/dev/null; then
		return 1
	fi

	return 0
}


#######################################
#
# 	Функция активации ЗПС
#
#	Входные параметры:
#
#	Коды возвратов:
#
#	0 - ЗПС успешно активирован
#	1 - во время активации ЗПС произошли ошибки
#
#######################################

function enable_zps() {
	local changed=1

	if is_enabled_zps; then
		echo "ЗПС уже включен" | tee -a ${OUTPUT_FILE}
	elif [ -f "file.d/digsig_initramfs.conf" ]; then
		echo "Производится включение ЗПС"
		cat file.d/digsig_initramfs.conf > /etc/digsig/digsig_initramfs.conf
		changed=0
	else
		echo -e "${red}На носителе не найден файл digsig_initramfs.conf, не удалось произвести копирование${normal}" | tee -a ${OUTPUT_FILE}
		return 1
	fi

	echo "Идёт проверка ключей ЗПС..."

	if clear_digsig_keys; then
		echo "Несанционированые ключи безопасности были удалены" | tee -a ${OUTPUT_FILE}
		changed=0
	fi

	if ! is_security_keys_imported; then
		import_security_keys
		exit_code=$?
		if [ $exit_code -ne 0 ]; then
			echo -e "${red}Ошибка во время установки ключей безопасности для ЗПС${normal}" | tee -a ${OUTPUT_FILE}
			return 1
		fi

		echo "Ключи безопасности установлены" | tee -a ${OUTPUT_FILE}
		changed=0
	else
		echo "Ключи безопасности уже импортированы" | tee -a ${OUTPUT_FILE}
	fi

	if [ $changed -ne 0 ];then
		echo "Изменения не производились" | tee -a ${OUTPUT_FILE}
		return 0
	fi

	echo "Запись изменений в ядро..." | tee -a ${OUTPUT_FILE}

	update-initramfs -u -k all -t
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		echo -e "${red}Ошибка при включении расширенных атрибутов ЗПС. Выполните команду 'update-initramfs -t -u -k all'${normal}" | tee -a ${OUTPUT_FILE}
		return 1
	fi

	echo "ЗПС с ключами включен" | tee -a ${OUTPUT_FILE}

	return 0
}