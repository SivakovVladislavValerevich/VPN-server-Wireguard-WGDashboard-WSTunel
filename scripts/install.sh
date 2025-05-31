#!/bin/bash

# Основной скрипт установки VPN-сервера на базе WireGuard

# Определение директории скрипта для корректного подключения зависимостей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/utils"
CONFIG_FILE="$(cd "$SCRIPT_DIR/.." && pwd)/config.conf"

# Подключение утилит
source "$UTILS_DIR/log_utils.sh"
source "$UTILS_DIR/system_utils.sh"

# Инициализация логирования
setup_logging "install"

# Отображение баннера
log_banner "Установка VPN-сервера WireGuard с WGDashboard и WSTunnel"

# Проверка запуска от имени root
if [[ $EUID -ne 0 ]]; then
   log_error "Этот скрипт должен быть запущен с правами суперпользователя (root)"
   log_info "Используйте: sudo $0"
   exit 1
fi

# Загрузка конфигурации
if [[ -f "$CONFIG_FILE" ]]; then
    # Преобразуем CRLF в LF для корректной интерпретации
    tr -d '\r' < "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    source "$CONFIG_FILE"
    log_success "Конфигурационный файл загружен: $CONFIG_FILE"
    
    # Определяем публичный IP-адрес, если он не задан
    if [ -z "$SERVER_PUBLIC_IP" ]; then
        SERVER_PUBLIC_IP=$(get_public_ip)
        if [ -n "$SERVER_PUBLIC_IP" ]; then
            update_config_value "SERVER_PUBLIC_IP" "$SERVER_PUBLIC_IP" "$CONFIG_FILE"
            log_info "Определен публичный IP-адрес сервера: $SERVER_PUBLIC_IP"
        else
            log_warning "Не удалось автоматически определить публичный IP-адрес сервера"
            log_warning "Вы можете указать его вручную в файле конфигурации: $CONFIG_FILE"
        fi
    fi
else
    log_error "Конфигурационный файл не найден: $CONFIG_FILE"
    exit 1
fi

# Запрос подтверждения настроек, если включено
if [[ "$PROMPT_USER_FOR_SETTINGS" == "true" ]]; then
    echo ""
    log_section "Текущие настройки"
    echo "WireGuard порт: $WG_PORT"
    echo "WGDashboard порт: $WGDASHBOARD_PORT"
    if [[ "$INSTALL_WSTUNNEL_ENABLED" == "true" ]]; then
        echo "WSTunnel порт: $WSTUNNEL_PORT"
    fi
    echo "Внутренняя сеть: $WG_NETWORK_PRIVATE"
    echo "Изменять имена сетевых интерфейсов: $CHANGE_NETWORK_NAMES_ENABLED"
    echo "Устанавливать WGDashboard: $INSTALL_WGDASHBOARD_ENABLED"
    echo "Устанавливать WSTunnel: $INSTALL_WSTUNNEL_ENABLED"
    echo ""

    read -p "Продолжить установку с указанными настройками? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "Установка отменена пользователем"
        exit 0
    fi
fi

# Проверка наличия всех скриптов установки
log_info "Проверка наличия всех необходимых скриптов..."
INSTALLATION_SCRIPTS=(
    "00_check_prerequisites.sh"
    "01_prepare_server.sh"
)

# Если включено изменение имен интерфейсов, добавляем скрипт в начало установки
if [[ "$CHANGE_NETWORK_NAMES_ENABLED" == "true" ]]; then
    INSTALLATION_SCRIPTS+=("02_change_network_names.sh")
fi

# Добавляем остальные обязательные скрипты
INSTALLATION_SCRIPTS+=(
    "03_configure_firewall.sh"
    "04_install_wireguard.sh"
)

# Добавление других опциональных скриптов
if [[ "$INSTALL_WGDASHBOARD_ENABLED" == "true" ]]; then
    INSTALLATION_SCRIPTS+=("05_install_wgdashboard.sh")
fi

if [[ "$INSTALL_WSTUNNEL_ENABLED" == "true" ]]; then
    INSTALLATION_SCRIPTS+=("06_install_wstunnel.sh")
fi

# Проверка наличия всех скриптов
for script in "${INSTALLATION_SCRIPTS[@]}"; do
    if [[ ! -f "$SCRIPT_DIR/$script" ]]; then
        log_error "Скрипт не найден: $script"
        exit 1
    fi
done

log_success "Все необходимые скрипты найдены"

# Начало процесса установки
log_section "Начинаем процесс установки..."

# Выполнение скриптов установки
for script in "${INSTALLATION_SCRIPTS[@]}"; do
    log_section "Запуск скрипта: $script"
    
    # Выполняем скрипт
    chmod +x "$SCRIPT_DIR/$script"
    "$SCRIPT_DIR/$script"
    script_result=$?
    
    # Проверяем результат выполнения
    if [ $script_result -eq 1 ]; then
        log_error "Ошибка при выполнении скрипта $script"
        log_error "Установка прервана из-за ошибки"
        exit 1
    elif [ $script_result -eq 2 ] && [[ "$script" == "02_change_network_names.sh" ]]; then
        # Код 2 означает, что требуется перезагрузка после изменения имен интерфейсов
        log_warning "Система будет перезагружена для применения изменений имен сетевых интерфейсов"
        log_info "После перезагрузки, пожалуйста, запустите установку повторно"
        log_info "Команда для продолжения установки после перезагрузки:"
        log_info "cd $(pwd) && sudo ./scripts/install.sh"
        
        # Создаем файл-флаг для определения, что это повторный запуск после перезагрузки
        touch "/tmp/vpn_install_reboot"
        
        # Запрашиваем подтверждение на перезагрузку
        read -p "Нажмите Enter для перезагрузки..."
        reboot
        exit 0
    fi
    
    log_success "Скрипт $script выполнен успешно"
done

# Проверяем, был ли это запуск после перезагрузки
if [[ -f "/tmp/vpn_install_reboot" ]]; then
    rm -f "/tmp/vpn_install_reboot"
    log_info "Установка продолжена после перезагрузки"
fi

# Вывод информации о результатах установки
log_section "Установка успешно завершена!"

# Информация о WireGuard
log_info "WireGuard установлен и настроен:"
log_info "├── Порт: $WG_PORT"
log_info "├── Внутренняя сеть: $WG_NETWORK_PRIVATE"
log_info "└── IP-адрес сервера в VPN: $WG_SERVER_IP_PRIVATE"

# Информация о WGDashboard
if [[ "$INSTALL_WGDASHBOARD_ENABLED" == "true" ]]; then
    log_info ""
    log_info "WGDashboard доступен по адресу:"
    log_info "├── URL: http://$SERVER_PUBLIC_IP:$WGDASHBOARD_PORT"
    log_info "└── Порт: $WGDASHBOARD_PORT"
fi

# Информация о WSTunnel
if [[ "$INSTALL_WSTUNNEL_ENABLED" == "true" ]]; then
    log_info ""
    log_info "WSTunnel настроен:"
    log_info "├── Порт: $WSTUNNEL_PORT"
    
    if [[ -n "$WSTUNNEL_SECRET" ]]; then
        log_info "└── Секретный ключ: $WSTUNNEL_SECRET"
    else
        if [[ -f "/etc/wireguard/wstunnel_secret" ]]; then
            WSTUNNEL_SECRET=$(cat /etc/wireguard/wstunnel_secret)
            log_info "└── Секретный ключ: $WSTUNNEL_SECRET"
        else
            log_warning "└── Не удалось найти файл с секретным ключом"
        fi
    fi
fi

# Инструкции по использованию
log_section "Что дальше?"
log_info "1. Для добавления клиентов используйте веб-интерфейс WGDashboard"
log_info "2. Руководство по пользованию WSTunel: nano manual/wstunnel_user_guide.md"
log_info "3. Команда для создания резервной копии конфигурации: scripts/backup.sh"
log_info "4. Команда для удаления VPN-инфраструктуры с сервера: scripts/uninstall.sh"

exit 0 