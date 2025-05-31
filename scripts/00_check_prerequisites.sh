#!/bin/bash
# Скрипт для проверки предварительных требований

# Загружаем утилиты
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPT_DIR/utils/log_utils.sh"
source "$SCRIPT_DIR/utils/system_utils.sh"

# Функция проверки наличия основных инструментов
check_basic_tools() {
    log_install "[module_00] Проверка наличия основных инструментов..."
    
    local required_tools=("curl" "wget" "dig" "awk" "grep" "sed" "ip" "netstat")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command_exists "$tool"; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -eq 0 ]; then
        log_install "[module_00] Все основные инструменты установлены"
        return 0
    else
        log_warning "[module_00] Отсутствуют следующие инструменты: ${missing_tools[*]}"
        
        read -p "[module_00] Хотите установить недостающие инструменты? (y/n): " -r answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            log_install "[module_00] Установка недостающих инструментов..."
            
            # Обновляем список пакетов
            apt-get update -y
            
            # Установка недостающих инструментов
            apt-get install -y curl wget dnsutils net-tools
            
            log_install "[module_00] Недостающие инструменты установлены"
            return 0
        else
            log_error "[module_00] Требуемые инструменты отсутствуют. Продолжение невозможно."
            return 1
        fi
    fi
}

# Функция проверки прав суперпользователя
check_superuser_rights() {
    log_install "[module_00] Проверка прав суперпользователя..."
    
    if ! check_root; then
        log_error "[module_00] Этот скрипт должен быть запущен с правами суперпользователя"
        log_error "[module_00] Пожалуйста, запустите скрипт с использованием sudo или от имени root"
        return 1
    fi
    
    log_install "[module_00] Проверка прав суперпользователя пройдена"
    return 0
}

# Функция проверки совместимости ОС
check_os_compatibility() {
    log_install "[module_00] Проверка совместимости операционной системы..."
    
    if ! detect_os; then
        log_warning "[module_00] Операционная система не поддерживается или не была протестирована"
        log_warning "[module_00] Продолжение на свой страх и риск"
        
        read -p "[module_00] Продолжить установку? (y/n): " -r answer
        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            log_error "[module_00] Установка прервана пользователем"
            return 1
        fi
    fi
    
    log_install "[module_00] Проверка совместимости ОС пройдена"
    return 0
}

# Функция проверки интернет-соединения
check_internet_connection() {
    log_install "[module_00] Проверка интернет-соединения..."
    
    # Проверка через ping на различные сервера
    local servers=("8.8.8.8" "1.1.1.1" "google.com")
    local connected=false
    
    for server in "${servers[@]}"; do
        if ping -c 1 "$server" &>/dev/null; then
            connected=true
            log_install "[module_00] Соединение с интернетом установлено (успешный пинг до $server)"
            break
        fi
    done
    
    if [ "$connected" = false ]; then
        log_error "[module_00] Интернет-соединение не доступно. Продолжение невозможно."
        return 1
    fi
    
    return 0
}

# Функция проверки свободных портов
check_ports_availability() {
    log_install "[module_00] Проверка доступности портов..."
    
    # Загружаем конфигурацию для получения портов
    CONFIG_FILE="$(dirname "$(realpath "$SCRIPT_DIR")")/config.conf"
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        log_info "[module_00] Конфигурационный файл загружен: $CONFIG_FILE"
    else
        log_warning "[module_00] Файл конфигурации не найден. Используются порты по умолчанию."
        WG_PORT=20820
        WGDASHBOARD_PORT=10086
        WSTUNNEL_PORT=443
    fi
    
    log_install "[module_00] Проверяемые порты: WireGuard ($WG_PORT), WGDashboard ($WGDASHBOARD_PORT), Wstunnel ($WSTUNNEL_PORT)"
    
    local occupied_ports=()
    
    # Проверка доступности команды netstat
    if ! command_exists "netstat"; then
        log_warning "[module_00] Команда netstat не найдена. Установите пакет net-tools."
        return 0
    fi
    
    # Проверка UDP порта для WireGuard
    if netstat -anlu | grep -q ":$WG_PORT "; then
        occupied_ports+=("UDP:$WG_PORT (WireGuard)")
    fi
    
    # Проверка TCP порта для WGDashboard
    if netstat -anlt | grep -q ":$WGDASHBOARD_PORT "; then
        occupied_ports+=("TCP:$WGDASHBOARD_PORT (WGDashboard)")
    fi
    
    # Проверка TCP порта для Wstunnel
    if netstat -anlt | grep -q ":$WSTUNNEL_PORT "; then
        occupied_ports+=("TCP:$WSTUNNEL_PORT (Wstunnel)")
    fi
    
    if [ ${#occupied_ports[@]} -eq 0 ]; then
        log_install "[module_00] Все необходимые порты свободны"
        return 0
    else
        log_warning "[module_00] Следующие порты уже заняты: ${occupied_ports[*]}"
        
        read -p "[module_00] Хотите продолжить и попытаться освободить занятые порты? (y/n): " -r answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            log_warning "[module_00] Продолжение установки. Попытка освободить порты будет выполнена позже."
            return 0
        else
            log_error "[module_00] Установка прервана из-за занятых портов"
            return 1
        fi
    fi
}

# Главная функция
main() {
    log_install "[module_00] Запуск проверки предварительных требований..."
    
    # Выполняем все проверки последовательно
    check_superuser_rights || return 1
    check_os_compatibility || return 1
    check_basic_tools || return 1
    check_internet_connection || return 1
    check_ports_availability || return 1
    
    log_install "[module_00] Все предварительные проверки успешно пройдены"
    return 0
}

# Запускаем главную функцию
main 