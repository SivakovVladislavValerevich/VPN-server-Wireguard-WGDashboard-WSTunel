#!/bin/bash
# Скрипт для изменения имен сетевых интерфейсов с современного формата на классический

# Загружаем утилиты
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPT_DIR/utils/log_utils.sh"
source "$SCRIPT_DIR/utils/system_utils.sh"
source "$SCRIPT_DIR/utils/backup_utils.sh"
source "$SCRIPT_DIR/utils/detect_network.sh"

# Функция для определения текущих сетевых интерфейсов
detect_current_interfaces() {
    log_install "[module_02] Определение текущих сетевых интерфейсов..."
    
    # Получаем список активных интерфейсов, исключая loopback
    local interfaces=$(ip -o link show | awk -F': ' '$2 != "lo" {print $2}')
    
    log_install "[module_02] Найдены следующие интерфейсы: $interfaces"
    echo "$interfaces"
}

# Функция для проверки, нужно ли менять имя интерфейса
need_to_rename_interfaces() {
    local interfaces=$1
    
    # Проверяем, все ли интерфейсы имеют современный формат имени
    if echo "$interfaces" | grep -q -E "^(ens|enp|eno|enx|wlp|wls)"; then
        log_install "[module_02] Обнаружены интерфейсы с современными именами"
        return 0  # true, нужно менять имена
    else
        log_install "[module_02] Интерфейсы уже имеют классические имена"
        return 1  # false, не нужно менять имена
    fi
}

# Функция для обновления конфигурации GRUB
update_grub_config() {
    log_install "[module_02] Обновление конфигурации GRUB для изменения имен сетевых интерфейсов..."
    
    # Путь к файлу конфигурации GRUB
    local grub_config="/etc/default/grub"
    
    # Создаем резервную копию файла
    backup_file "$grub_config" "template"
    
    # Проверяем наличие параметров в GRUB_CMDLINE_LINUX
    if grep -q "GRUB_CMDLINE_LINUX=" "$grub_config"; then
        # Проверяем, содержит ли уже параметры для переименования интерфейсов
        if ! grep -q "net.ifnames=0" "$grub_config" || ! grep -q "biosdevname=0" "$grub_config"; then
            # Добавляем параметры к существующим
            log_install "[module_02] Добавление параметров net.ifnames=0 biosdevname=0 в конфигурацию GRUB"
            sed -i 's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 net.ifnames=0 biosdevname=0"/g' "$grub_config"
        else
            log_install "[module_02] Параметры для переименования интерфейсов уже присутствуют в GRUB"
        fi
    else
        log_error "[module_02] Параметр GRUB_CMDLINE_LINUX не найден в $grub_config"
        return 1
    fi
    
    # Обновляем GRUB
    log_install "[module_02] Обновление GRUB..."
    update-grub || {
        log_error "[module_02] Не удалось обновить GRUB"
        return 1
    }
    
    log_install "[module_02] Конфигурация GRUB успешно обновлена"
    return 0
}

# Функция для обновления конфигурации сети
update_network_config() {
    local current_interface=$1
    
    log_install "[module_02] Обновление конфигурации сети для интерфейса $current_interface..."
    
    # Определяем тип системы
    if [ -d "/etc/netplan" ]; then
        # Ubuntu с Netplan
        log_install "[module_02] Обнаружена система с Netplan"
        update_netplan_config "$current_interface"
    elif [ -f "/etc/network/interfaces" ]; then
        # Debian с ifupdown
        log_install "[module_02] Обнаружена система с ifupdown"
        update_ifupdown_config "$current_interface"
    else
        log_warning "[module_02] Не удалось определить тип сетевой конфигурации"
        log_warning "[module_02] Вам может потребоваться вручную обновить конфигурацию сети после перезагрузки"
        return 1
    fi
    
    log_install "[module_02] Конфигурация сети успешно обновлена"
    return 0
}

# Функция для обновления конфигурации Netplan
update_netplan_config() {
    local current_interface=$1
    
    # Ищем файлы конфигурации Netplan
    local netplan_files=$(find /etc/netplan -name "*.yaml")
    
    for file in $netplan_files; do
        log_install "[module_02] Обновление файла Netplan: $file"
        
        # Создаем резервную копию файла
        backup_file "$file" "template"
        
        # Заменяем имя интерфейса в файле
        sed -i "s/$current_interface/eth0/g" "$file"
    done
    
    # Применяем изменения Netplan
    log_install "[module_02] Применение изменений Netplan..."
    netplan generate || {
        log_error "[module_02] Не удалось сгенерировать конфигурацию Netplan"
        return 1
    }
    
    return 0
}

# Функция для обновления конфигурации ifupdown
update_ifupdown_config() {
    local current_interface=$1
    local interfaces_file="/etc/network/interfaces"
    
    log_install "[module_02] Обновление файла $interfaces_file"
    
    # Создаем резервную копию файла
    backup_file "$interfaces_file" "template"
    
    # Заменяем имя интерфейса в файле
    sed -i "s/$current_interface/eth0/g" "$interfaces_file"
    
    return 0
}

# Главная функция
main() {
    log_install "[module_02] Начало процесса изменения имен сетевых интерфейсов..."
    
    # Проверяем права суперпользователя
    if ! check_root; then
        log_error "[module_02] Этот скрипт требует прав суперпользователя"
        return 1
    fi
    
    # Определяем текущий основной интерфейс
    local current_interface=$(detect_network_interface)
    if [ -z "$current_interface" ]; then
        log_error "[module_02] Не удалось определить основной сетевой интерфейс"
        return 1
    fi
    
    # Проверяем, нужно ли менять имя интерфейса
    if ! echo "$current_interface" | grep -q -E "^(ens|enp|eno|enx|wlp|wls)"; then
        log_install "[module_02] Интерфейс $current_interface уже имеет классическое имя. Изменения не требуются."
        return 0
    fi
    
    log_install "[module_02] Текущий основной интерфейс: $current_interface будет переименован в eth0"
    
    # Запрашиваем подтверждение пользователя
    log_warning "[module_02] ВНИМАНИЕ: После изменения имен интерфейсов потребуется перезагрузка системы!"
    log_warning "[module_02] Убедитесь, что вы имеете доступ к физической консоли или IPMI на случай проблем с сетью."
    read -p "[module_02] Продолжить с изменением имен сетевых интерфейсов? (y/n): " -r answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        log_install "[module_02] Процесс изменения имен интерфейсов отменен пользователем"
        return 0
    fi
    
    # Обновляем конфигурацию GRUB
    update_grub_config || {
        log_error "[module_02] Не удалось обновить конфигурацию GRUB"
        return 1
    }
    
    # Обновляем конфигурацию сети
    update_network_config "$current_interface" || {
        log_warning "[module_02] Не удалось полностью обновить конфигурацию сети"
        log_warning "[module_02] Вам может потребоваться вручную настроить сеть после перезагрузки"
    }
    
    # Обновляем конфигурацию в config.conf
    if [ -f "../config.conf" ]; then
        # Сохраняем информацию о текущем интерфейсе
        update_config_value "SERVER_NETWORK_INTERFACE" "eth0" "../config.conf"
    fi
    
    log_install "[module_02] Процесс изменения имен сетевых интерфейсов завершен"
    
    # Возвращаем специальный код для индикации необходимости перезагрузки
    return 2
}

# Запускаем главную функцию
main 
exit $? 