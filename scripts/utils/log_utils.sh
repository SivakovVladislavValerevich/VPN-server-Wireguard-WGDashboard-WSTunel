#!/bin/bash
# Утилиты для логирования

# Определяем корневую директорию проекта
ROOT_DIR="$(dirname "$(dirname "$(dirname "$(realpath "$0")")")")"

# Директория для логов
LOGS_DIR="$ROOT_DIR/logs"
INSTALL_LOG="$LOGS_DIR/install_log.txt"
UNINSTALL_LOG="$LOGS_DIR/uninstall_log.txt"
REINSTALL_LOG="$LOGS_DIR/reinstall_log.txt"
OPERATIONS_LOG="$LOGS_DIR/operations_log.txt"

# Функция для инициализации логирования
setup_logging() {
    local log_type=$1

    # Создать директорию для логов, если не существует
    if [ ! -d "$LOGS_DIR" ]; then
        mkdir -p "$LOGS_DIR"
    fi

    # Инициализация лог-файлов в зависимости от типа
    case "$log_type" in
        "install")
            # Создать или очистить лог установки
            > "$INSTALL_LOG"
            ;;
        "uninstall")
            # Создать или очистить лог удаления
            > "$UNINSTALL_LOG"
            ;;
        "reinstall")
            # Создать или очистить лог переустановки
            > "$REINSTALL_LOG"
            ;;
    esac

    # Создать файл операционного лога, если не существует
    if [ ! -f "$OPERATIONS_LOG" ]; then
        touch "$OPERATIONS_LOG"
    fi
}

# Функция для добавления временной метки к сообщению
_add_timestamp() {
    local message=$1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message"
}

# Функция для логирования информационных сообщений
log_info() {
    # Создаем директорию для логов, если она не существует
    if [ ! -d "$LOGS_DIR" ]; then
        mkdir -p "$LOGS_DIR"
    fi
    
    local message=$(_add_timestamp "INFO: $1")
    echo -e "\e[32m$message\e[0m"  # Зеленый цвет для INFO
    echo "$message" >> "$OPERATIONS_LOG"
}

# Функция для логирования предупреждений
log_warning() {
    # Создаем директорию для логов, если она не существует
    if [ ! -d "$LOGS_DIR" ]; then
        mkdir -p "$LOGS_DIR"
    fi
    
    local message=$(_add_timestamp "WARNING: $1")
    echo -e "\e[33m$message\e[0m"  # Желтый цвет для WARNING
    echo "$message" >> "$OPERATIONS_LOG"
}

# Функция для логирования ошибок
log_error() {
    # Создаем директорию для логов, если она не существует
    if [ ! -d "$LOGS_DIR" ]; then
        mkdir -p "$LOGS_DIR"
    fi
    
    local message=$(_add_timestamp "ERROR: $1")
    echo -e "\e[31m$message\e[0m"  # Красный цвет для ERROR
    echo "$message" >> "$OPERATIONS_LOG"
}

# Функция для логирования отладочной информации
log_debug() {
    # Создаем директорию для логов, если она не существует
    if [ ! -d "$LOGS_DIR" ]; then
        mkdir -p "$LOGS_DIR"
    fi
    
    if [ "${DEBUG_MODE:-false}" = "true" ]; then
        local message=$(_add_timestamp "DEBUG: $1")
        echo -e "\e[36m$message\e[0m"  # Голубой цвет для DEBUG
        echo "$message" >> "$OPERATIONS_LOG"
    fi
}

# Функция для логирования установки
log_install() {
    # Создаем директорию для логов, если она не существует
    if [ ! -d "$LOGS_DIR" ]; then
        mkdir -p "$LOGS_DIR"
    fi
    
    local message=$(_add_timestamp "INSTALL: $1")
    echo -e "\e[32m$message\e[0m"  # Зеленый цвет для INSTALL
    echo "$message" >> "$INSTALL_LOG"
    echo "$message" >> "$OPERATIONS_LOG"
}

# Функция для логирования удаления
log_uninstall() {
    # Создаем директорию для логов, если она не существует
    if [ ! -d "$LOGS_DIR" ]; then
        mkdir -p "$LOGS_DIR"
    fi
    
    local message=$(_add_timestamp "UNINSTALL: $1")
    echo -e "\e[31m$message\e[0m"  # Красный цвет для UNINSTALL
    echo "$message" >> "$UNINSTALL_LOG"
    echo "$message" >> "$OPERATIONS_LOG"
}

# Функция для логирования переустановки
log_reinstall() {
    # Создаем директорию для логов, если она не существует
    if [ ! -d "$LOGS_DIR" ]; then
        mkdir -p "$LOGS_DIR"
    fi
    
    local message=$(_add_timestamp "REINSTALL: $1")
    echo -e "\e[33m$message\e[0m"  # Желтый цвет для REINSTALL
    echo "$message" >> "$REINSTALL_LOG"
    echo "$message" >> "$OPERATIONS_LOG"
}

# Функция для вывода баннера
log_banner() {
    # Создаем директорию для логов, если она не существует
    if [ ! -d "$LOGS_DIR" ]; then
        mkdir -p "$LOGS_DIR"
    fi
    
    local message="$1"
    echo -e "\e[1;34m====================================\e[0m"
    echo -e "\e[1;34m $message\e[0m"
    echo -e "\e[1;34m====================================\e[0m"
    
    # Добавляем в лог файлы
    echo "===================================" >> "$OPERATIONS_LOG"
    echo " $message" >> "$OPERATIONS_LOG"
    echo "===================================" >> "$OPERATIONS_LOG"
}

# Функция для вывода раздела
log_section() {
    # Создаем директорию для логов, если она не существует
    if [ ! -d "$LOGS_DIR" ]; then
        mkdir -p "$LOGS_DIR"
    fi
    
    local message="$1"
    echo -e "\e[1;36m-----------------------------------\e[0m"
    echo -e "\e[1;36m $message\e[0m"
    echo -e "\e[1;36m-----------------------------------\e[0m"
    
    # Добавляем в лог файлы
    echo "-----------------------------------" >> "$OPERATIONS_LOG"
    echo " $message" >> "$OPERATIONS_LOG"
    echo "-----------------------------------" >> "$OPERATIONS_LOG"
}

# Функция для вывода успешного сообщения
log_success() {
    # Создаем директорию для логов, если она не существует
    if [ ! -d "$LOGS_DIR" ]; then
        mkdir -p "$LOGS_DIR"
    fi
    
    local message=$(_add_timestamp "SUCCESS: $1")
    echo -e "\e[1;32m$message\e[0m"  # Яркий зеленый цвет для SUCCESS
    echo "$message" >> "$OPERATIONS_LOG"
}

# Функция для ротации лога операций
rotate_operations_log() {
    local days=${1:-7}  # По умолчанию 7 дней
    local timestamp=$(date '+%Y%m%d-%H%M%S')
    local backup_dir="backups/logs"
    
    # Создать директорию для бэкапов, если не существует
    if [ ! -d "$backup_dir" ]; then
        mkdir -p "$backup_dir"
    fi
    
    # Архивировать текущий лог
    if [ -f "$OPERATIONS_LOG" ] && [ -s "$OPERATIONS_LOG" ]; then
        gzip -c "$OPERATIONS_LOG" > "$backup_dir/operations_log_$timestamp.gz"
        > "$OPERATIONS_LOG"  # Очистить текущий лог
        log_info "[log_utils] Операционный лог архивирован и очищен"
    fi
    
    # Удалить старые архивы
    find "$backup_dir" -name "operations_log_*.gz" -mtime +$days -delete
}

# Создаем директорию для логов сразу при загрузке утилит
mkdir -p "$LOGS_DIR"

# Экспорт функций для использования в других скриптах
export -f setup_logging
export -f log_info
export -f log_warning
export -f log_error
export -f log_debug
export -f log_install
export -f log_uninstall
export -f log_reinstall
export -f rotate_operations_log
export -f log_banner
export -f log_section
export -f log_success 