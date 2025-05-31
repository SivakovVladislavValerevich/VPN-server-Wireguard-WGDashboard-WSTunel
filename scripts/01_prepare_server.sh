#!/bin/bash
# Скрипт для подготовки сервера: обновление системы и установка необходимых пакетов

# Загружаем утилиты
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPT_DIR/utils/log_utils.sh"
source "$SCRIPT_DIR/utils/system_utils.sh"
source "$SCRIPT_DIR/utils/backup_utils.sh"

# Функция для обновления системы
update_system() {
    log_install "[module_01] Обновление списков пакетов..."
    apt-get update -y || {
        log_error "[module_01] Не удалось обновить список пакетов"
        return 1
    }
    
    log_install "[module_01] Обновление системы..."
    apt-get full-upgrade -y || {
        log_error "[module_01] Не удалось обновить систему"
        return 1
    }
    
    log_install "[module_01] Обновление системы успешно завершено"
    return 0
}

# Функция для установки базовых пакетов
install_base_packages() {
    log_install "[module_01] Установка базовых пакетов..."
    
    local base_packages=(
        "sudo"
        "curl"
        "wget"
        "git"
        "net-tools"
        "dnsutils"
        "iptables"
        "iptables-persistent"
        "openssl"
        "ca-certificates"
        "gnupg"
        "lsb-release"
        "cron"
    )
    
    # Устанавливаем пакеты с автоматическим подтверждением
    apt-get install -y "${base_packages[@]}" || {
        log_error "[module_01] Не удалось установить базовые пакеты"
        return 1
    }
    
    log_install "[module_01] Базовые пакеты успешно установлены"
    return 0
}

# Функция для настройки системных директорий
setup_system_directories() {
    log_install "[module_01] Настройка системных директорий..."
    
    # Создаем директории для логов и бэкапов
    setup_backup_dirs
    
    # Создаем директорию для WireGuard, если ее еще нет
    if [ ! -d "/etc/wireguard" ]; then
        mkdir -p /etc/wireguard
        chmod 700 /etc/wireguard
        log_install "[module_01] Создана директория /etc/wireguard"
    fi
    
    log_install "[module_01] Системные директории успешно настроены"
    return 0
}

# Функция для настройки базовой защиты
setup_basic_security() {
    log_install "[module_01] Настройка базовой защиты системы..."
    
    # Ограничиваем доступ к системным файлам
    chmod 700 /root
    chmod 600 /etc/ssh/sshd_config
    
    # Проверяем и обновляем настройки SSH
    if [ -f "/etc/ssh/sshd_config" ]; then
        # Сначала делаем резервную копию
        backup_file "/etc/ssh/sshd_config" "template"
        
        # Отключаем root логин, если он не отключен
        if grep -q "^PermitRootLogin yes" "/etc/ssh/sshd_config"; then
            log_warning "[module_01] Обнаружен разрешенный вход root по SSH. Рекомендуется отключить."
            read -p "[module_01] Отключить вход root по SSH? (y/n): " -r answer
            if [[ "$answer" =~ ^[Yy]$ ]]; then
                sed -i 's/^PermitRootLogin yes/PermitRootLogin prohibit-password/' "/etc/ssh/sshd_config"
                log_install "[module_01] Вход root по SSH отключен"
                
                # Перезапускаем SSH для применения изменений
                systemctl restart sshd
            fi
        fi
    fi
    
    log_install "[module_01] Базовая защита системы настроена"
    return 0
}

# Главная функция
main() {
    log_install "[module_01] Начало подготовки сервера..."
    
    # Проверяем права суперпользователя
    if ! check_root; then
        log_error "[module_01] Этот скрипт требует прав суперпользователя"
        return 1
    fi
    
    # Последовательно выполняем все задачи
    update_system || return 1
    install_base_packages || return 1
    setup_system_directories || return 1
    setup_basic_security || return 1
    
    log_install "[module_01] Подготовка сервера успешно завершена"
    return 0
}

# Запускаем главную функцию
main 