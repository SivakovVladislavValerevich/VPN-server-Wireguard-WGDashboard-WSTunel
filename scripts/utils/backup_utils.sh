#!/bin/bash
# Утилиты для создания и управления бэкапами

# Определяем корневую директорию проекта
ROOT_DIR="$(dirname "$(dirname "$(dirname "$(realpath "$0")")")")"

# Импортируем утилиты логирования, если они еще не импортированы
if ! command -v log_info &> /dev/null; then
    source "$(dirname "$0")/log_utils.sh"
fi

# Константы
BACKUP_DIR="$ROOT_DIR/backups"
CONFIGS_BACKUP_DIR="$BACKUP_DIR/configs"
TEMPLATES_DIR="$BACKUP_DIR/templates"

# Функция для создания директорий для бэкапов
setup_backup_dirs() {
    log_info "[backup_utils] Настройка директорий для бэкапов..."
    
    # Создаем директории, если они не существуют
    for dir in "$BACKUP_DIR" "$CONFIGS_BACKUP_DIR" "$TEMPLATES_DIR" "$BACKUP_DIR/logs"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            log_info "[backup_utils] Создана директория: $dir"
        fi
    done
}

# Функция для создания резервной копии файла перед его изменением
backup_file() {
    local file_path=$1
    local backup_type=${2:-"template"} # template или config
    
    if [ ! -f "$file_path" ]; then
        log_warning "[backup_utils] Файл не существует, невозможно создать бэкап: $file_path"
        return 1
    fi
    
    local filename=$(basename "$file_path")
    local timestamp=$(date '+%Y%m%d-%H%M%S')
    local backup_path
    
    case "$backup_type" in
        "template")
            # Для шаблонов - сохраняем оригинальную версию без временной метки
            backup_path="$TEMPLATES_DIR/$filename"
            # Если шаблон уже существует, не перезаписываем его
            if [ ! -f "$backup_path" ]; then
                cp -f "$file_path" "$backup_path"
                log_info "[backup_utils] Создан шаблон файла: $backup_path"
            fi
            ;;
        "config")
            # Для конфигураций - создаем версию с временной меткой
            local dir_structure=$(dirname "$file_path" | sed 's/^\///g' | tr '/' '_')
            if [ ! -d "$CONFIGS_BACKUP_DIR/$dir_structure" ]; then
                mkdir -p "$CONFIGS_BACKUP_DIR/$dir_structure"
            fi
            backup_path="$CONFIGS_BACKUP_DIR/$dir_structure/${filename}_${timestamp}"
            cp -f "$file_path" "$backup_path"
            log_info "[backup_utils] Создана резервная копия файла: $backup_path"
            ;;
        *)
            log_error "[backup_utils] Неизвестный тип бэкапа: $backup_type"
            return 1
            ;;
    esac
    
    return 0
}

# Функция для создания полного бэкапа всех конфигурационных файлов
create_full_config_backup() {
    log_info "[backup_utils] Создание полного бэкапа конфигурационных файлов..."
    
    local timestamp=$(date '+%Y%m%d-%H%M%S')
    local backup_name="full_backup_$timestamp"
    local target_dir="$CONFIGS_BACKUP_DIR/$backup_name"
    
    mkdir -p "$target_dir"
    
    # Список директорий/файлов для бэкапа
    local targets=(
        "/etc/wireguard"
        "/etc/systemd/system/wg-dashboard.service"
        "/etc/systemd/system/wstunnel.service"
        "/etc/iptables/rules.v4"
    )
    
    # Копирование файлов
    for target in "${targets[@]}"; do
        if [ -e "$target" ]; then
            if [ -d "$target" ]; then
                # Если это директория, копируем рекурсивно
                mkdir -p "$target_dir$(dirname "$target")"
                cp -r "$target" "$target_dir$(dirname "$target")/"
            else
                # Если это файл, создаем директорию и копируем
                mkdir -p "$target_dir$(dirname "$target")"
                cp "$target" "$target_dir$(dirname "$target")/"
            fi
            log_info "[backup_utils] Скопирован в бэкап: $target"
        else
            log_warning "[backup_utils] Цель для бэкапа не существует: $target"
        fi
    done
    
    log_info "[backup_utils] Полный бэкап успешно создан: $target_dir"
    return 0
}

# Функция для удаления старых бэкапов
cleanup_old_backups() {
    local days=$1
    
    log_info "[backup_utils] Удаление бэкапов старше $days дней..."
    
    # Находим и удаляем старые бэкапы
    find "$CONFIGS_BACKUP_DIR" -type d -name "full_backup_*" -mtime +$days -exec rm -rf {} \;
    log_info "[backup_utils] Старые бэкапы удалены"
}

# Функция для восстановления из бэкапа
restore_from_backup() {
    local backup_path=$1
    local target_path=$2
    
    if [ ! -e "$backup_path" ]; then
        log_error "[backup_utils] Бэкап не существует: $backup_path"
        return 1
    fi
    
    # Если цель существует, создаем резервную копию перед восстановлением
    if [ -e "$target_path" ]; then
        backup_file "$target_path" "config"
    fi
    
    # Восстановление из бэкапа
    if [ -d "$backup_path" ]; then
        # Если бэкап - директория, копируем рекурсивно
        cp -r "$backup_path"/* "$(dirname "$target_path")/"
    else
        # Если бэкап - файл, просто копируем
        cp -f "$backup_path" "$target_path"
    fi
    
    log_info "[backup_utils] Файл восстановлен из бэкапа: $target_path"
    return 0
}

# Экспорт функций
export -f setup_backup_dirs
export -f backup_file
export -f create_full_config_backup
export -f cleanup_old_backups
export -f restore_from_backup 