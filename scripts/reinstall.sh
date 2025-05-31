#!/bin/bash

# Скрипт для переустановки VPN-сервера WireGuard
# Выполняет удаление существующей установки и установку заново

# Определение директории скрипта для корректного подключения зависимостей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/utils"
CONFIG_FILE="$(cd "$SCRIPT_DIR/.." && pwd)/config.conf"

# Подключение утилит логирования
source "$UTILS_DIR/log_utils.sh"

# Отображение баннера
log_banner "Переустановка VPN-сервера WireGuard"

# Проверка запуска от имени root
if [[ $EUID -ne 0 ]]; then
   log_error "Этот скрипт должен быть запущен с правами суперпользователя (root)"
   log_info "Используйте: sudo $0"
   exit 1
fi

# Загрузка конфигурации
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    log_success "Конфигурационный файл загружен: $CONFIG_FILE"
else
    log_error "Конфигурационный файл не найден: $CONFIG_FILE"
    exit 1
fi

# Запрос подтверждения
log_warning "Внимание! Эта операция удалит существующую установку VPN-сервера и установит его заново."
log_warning "Все существующие настройки и клиенты будут потеряны, если не была создана резервная копия."

read -p "Хотите создать резервную копию перед продолжением? (y/n): " backup_confirm
if [[ "$backup_confirm" == "y" || "$backup_confirm" == "Y" ]]; then
    log_section "Создание резервной копии перед переустановкой"
    "$SCRIPT_DIR/backup.sh" create
    
    if [[ $? -ne 0 ]]; then
        log_error "Не удалось создать резервную копию"
        read -p "Продолжить без создания резервной копии? (y/n): " continue_without_backup
        if [[ "$continue_without_backup" != "y" && "$continue_without_backup" != "Y" ]]; then
            log_info "Операция переустановки отменена пользователем"
            exit 0
        fi
    else
        log_success "Резервная копия успешно создана"
    fi
fi

read -p "Вы уверены, что хотите переустановить VPN-сервер? (y/n): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    log_info "Операция переустановки отменена пользователем"
    exit 0
fi

# Удаление существующей установки
log_section "Удаление существующей установки"
"$SCRIPT_DIR/uninstall.sh"

if [[ $? -ne 0 ]]; then
    log_error "Произошла ошибка при удалении существующей установки"
    read -p "Продолжить установку? (y/n): " continue_after_error
    if [[ "$continue_after_error" != "y" && "$continue_after_error" != "Y" ]]; then
        log_info "Операция переустановки прервана пользователем"
        exit 1
    fi
fi

# Небольшая пауза перед установкой
log_info "Подготовка к установке..."
sleep 2

# Установка
log_section "Установка нового VPN-сервера"
"$SCRIPT_DIR/install.sh"

if [[ $? -ne 0 ]]; then
    log_error "Произошла ошибка во время установки"
    log_warning "VPN-сервер может быть установлен некорректно"
    exit 1
else
    log_success "Переустановка VPN-сервера успешно завершена"
fi

exit 0 