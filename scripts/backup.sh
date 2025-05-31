#!/bin/bash

# Скрипт для управления резервными копиями VPN-сервера WireGuard
# Поддерживает создание, восстановление и просмотр резервных копий

# Определение директории скрипта для корректного подключения зависимостей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/utils"
CONFIG_FILE="$(cd "$SCRIPT_DIR/.." && pwd)/config.conf"

# Подключение утилит
source "$UTILS_DIR/log_utils.sh"
source "$UTILS_DIR/backup_utils.sh"

# Определение директории для хранения резервных копий
DEFAULT_BACKUP_DIR="/var/backups/wireguard"
BACKUP_DIR="$DEFAULT_BACKUP_DIR"

# Функция вывода справки
show_help() {
    echo ""
    echo "Использование: $0 [опция]"
    echo ""
    echo "Опции:"
    echo "  create         Создать новую резервную копию"
    echo "  list           Вывести список всех резервных копий"
    echo "  restore <ID>   Восстановить указанную резервную копию"
    echo "  delete <ID>    Удалить указанную резервную копию"
    echo "  cleanup        Автоматическая очистка старых резервных копий согласно конфигурации"
    echo "  --help, -h     Показать данную справку"
    echo ""
    echo "Примеры использования:"
    echo "  $0 create      # Создать новую резервную копию"
    echo "  $0 list        # Показать список доступных резервных копий"
    echo "  $0 restore 3   # Восстановить резервную копию с ID 3"
    echo "  $0 delete 2    # Удалить резервную копию с ID 2"
    echo ""
}

# Проверка запуска от имени root
if [[ $EUID -ne 0 ]]; then
   log_error "[backup] Этот скрипт должен быть запущен с правами суперпользователя (root)"
   log_info "[backup] Используйте: sudo $0"
   exit 1
fi

# Загрузка конфигурации
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    log_success "[backup] Конфигурационный файл загружен: $CONFIG_FILE"
    
    # Если в конфигурации задана пользовательская директория для бэкапов
    if [[ -n "$BACKUP_CUSTOM_DIR" ]]; then
        BACKUP_DIR="$BACKUP_CUSTOM_DIR"
        log_info "[backup] Используется пользовательская директория для бэкапов: $BACKUP_DIR"
    fi
else
    log_warning "[backup] Конфигурационный файл не найден: $CONFIG_FILE"
    log_warning "[backup] Будут использованы значения по умолчанию"
fi

# Создаем директорию для бэкапов, если она не существует
if [[ ! -d "$BACKUP_DIR" ]]; then
    mkdir -p "$BACKUP_DIR"
    log_info "[backup] Создана директория для резервных копий: $BACKUP_DIR"
fi

# Обработка аргументов командной строки
case "$1" in
    create)
        log_banner "[backup] Создание новой резервной копии"
        backup_create "$BACKUP_DIR"
        ;;
        
    list)
        log_banner "[backup] Список доступных резервных копий"
        backup_list "$BACKUP_DIR"
        ;;
        
    restore)
        if [[ -z "$2" ]]; then
            log_error "[backup] Не указан ID резервной копии для восстановления"
            show_help
            exit 1
        fi
        
        log_banner "[backup] Восстановление резервной копии"
        backup_restore "$BACKUP_DIR" "$2"
        ;;
        
    delete)
        if [[ -z "$2" ]]; then
            log_error "[backup] Не указан ID резервной копии для удаления"
            show_help
            exit 1
        fi
        
        log_banner "[backup] Удаление резервной копии"
        backup_delete "$BACKUP_DIR" "$2"
        ;;
        
    cleanup)
        log_banner "[backup] Очистка старых резервных копий"
        if [[ "$CONFIG_BACKUP_ENABLED" == "true" && -n "$CONFIG_BACKUP_RETENTION_DAYS" ]]; then
            backup_cleanup "$BACKUP_DIR" "$CONFIG_BACKUP_RETENTION_DAYS"
        else
            log_warning "[backup] Очистка резервных копий отключена в конфигурации или не указано количество дней хранения"
            log_info "[backup] Для активации автоматической очистки настройте параметры CONFIG_BACKUP_ENABLED и CONFIG_BACKUP_RETENTION_DAYS в config.conf"
            exit 1
        fi
        ;;
        
    --help|-h)
        show_help
        exit 0
        ;;
        
    *)
        if [[ -z "$1" ]]; then
            log_error "[backup] Не указана опция"
        else
            log_error "[backup] Неизвестная опция: $1"
        fi
        show_help
        exit 1
        ;;
esac

exit 0 