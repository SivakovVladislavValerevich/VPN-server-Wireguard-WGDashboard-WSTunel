#!/bin/bash
# Утилиты для системных операций

# Импортируем утилиты логирования, если они еще не импортированы
if ! command -v log_info &> /dev/null; then
    source "$(dirname "$0")/log_utils.sh"
fi

# Функция для определения публичного IP-адреса
get_public_ip() {
    local ip
    # Пробуем разные сервисы для определения IP
    if ip=$(curl -s -4 ifconfig.me) && [ -n "$ip" ]; then
        echo "$ip"
        return 0
    elif ip=$(curl -s -4 icanhazip.com) && [ -n "$ip" ]; then
        echo "$ip"
        return 0
    elif ip=$(curl -s -4 ipecho.net/plain) && [ -n "$ip" ]; then
        echo "$ip"
        return 0
    else
        return 1
    fi
}

# Экспортируем функцию get_public_ip сразу после её определения
export -f get_public_ip

# Функция для проверки наличия пакета
is_package_installed() {
    local package=$1
    
    if command -v dpkg &> /dev/null; then
        # Debian/Ubuntu
        if dpkg -l | grep -q "^ii  $package "; then
            return 0
        fi
    elif command -v rpm &> /dev/null; then
        # CentOS/RHEL/Fedora
        if rpm -q "$package" &> /dev/null; then
            return 0
        fi
    else
        log_error "[system_utils] Не удалось определить менеджер пакетов"
        return 2
    fi
    
    return 1
}

# Функция для проверки активности службы
is_service_active() {
    local service=$1
    
    if systemctl is-active --quiet "$service"; then
        return 0
    else
        return 1
    fi
}

# Функция для обновления значения в конфигурационном файле
update_config_value() {
    local key=$1
    local value=$2
    local config_file=${3:-"config.conf"}
    
    # Проверяем существование файла
    if [ ! -f "$config_file" ]; then
        log_error "[system_utils] Конфигурационный файл не существует: $config_file"
        return 1
    fi
    
    # Проверяем, существует ли ключ
    if grep -q "^$key=" "$config_file"; then
        # Если ключ существует, обновляем значение
        sed -i "s|^$key=.*|$key=\"$value\"|" "$config_file"
    else
        # Если ключа нет, добавляем его в конец файла
        echo "$key=\"$value\"" >> "$config_file"
    fi
    
    log_info "[system_utils] Обновлено значение $key в $config_file"
    return 0
}

# Функция для создания cron-задания
setup_cron_job() {
    local schedule=$1  # Например, "0 0 * * *" для запуска в полночь каждый день
    local command=$2
    local comment=$3
    
    # Убеждаемся, что cron установлен
    if ! is_package_installed "cron"; then
        log_warning "[system_utils] Пакет cron не установлен. Установка..."
        apt-get update && apt-get install -y cron
        systemctl enable cron && systemctl start cron
    fi
    
    # Создаем временный файл для crontab
    local temp_file=$(mktemp)
    
    # Проверяем, существует ли уже такое задание
    if crontab -l 2>/dev/null | grep -q "$command"; then
        log_warning "[system_utils] Cron-задание уже существует. Обновление..."
        # Удаляем старое задание
        crontab -l 2>/dev/null | grep -v "$command" > "$temp_file"
    else
        # Копируем текущий crontab
        crontab -l 2>/dev/null > "$temp_file"
    fi
    
    # Добавляем новое задание
    echo "# $comment" >> "$temp_file"
    echo "$schedule $command" >> "$temp_file"
    
    # Устанавливаем обновленный crontab
    crontab "$temp_file"
    rm "$temp_file"
    
    log_info "[system_utils] Cron-задание успешно настроено: $schedule $command"
    return 0
}

# Функция для проверки корректности IP-адреса
is_valid_ip() {
    local ip=$1
    
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        # Проверяем каждый октет
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if [ "$octet" -lt 0 ] || [ "$octet" -gt 255 ]; then
                return 1
            fi
        done
        return 0
    fi
    
    return 1
}

# Функция для проверки наличия команды
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Функция для проверки наличия прав суперпользователя
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "[system_utils] Этот скрипт требует прав суперпользователя (root)"
        log_error "[system_utils] Пожалуйста, запустите скрипт с использованием sudo или от имени root"
        return 1
    fi
    return 0
}

# Функция для определения ОС
detect_os() {
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        OS=$NAME
        VERSION=$VERSION_ID
        
        log_info "[system_utils] Обнаружена ОС: $OS $VERSION"
        
        # Проверка поддерживаемых ОС
        case $ID in
            debian|ubuntu)
                return 0
                ;;
            *)
                log_warning "[system_utils] ОС $OS не была протестирована с этим скриптом. Продолжение на свой страх и риск."
                return 1
                ;;
        esac
    else
        log_error "[system_utils] Не удалось определить ОС"
        return 2
    fi
}

# Функция для генерации случайного пароля
generate_random_password() {
    local length=${1:-16}
    cat /dev/urandom | tr -dc 'a-zA-Z0-9!@#$%^&*()_+?><~' | head -c "$length"
}

# Функция для перезапуска службы
restart_service() {
    local service=$1
    
    log_info "[system_utils] Перезапуск службы $service..."
    
    if systemctl restart "$service"; then
        log_info "[system_utils] Служба $service успешно перезапущена"
        return 0
    else
        log_error "[system_utils] Не удалось перезапустить службу $service"
        return 1
    fi
}

# Экспорт функций
export -f is_package_installed
export -f is_service_active
export -f update_config_value
export -f setup_cron_job
export -f is_valid_ip
export -f command_exists
export -f check_root
export -f detect_os
export -f generate_random_password
export -f restart_service 