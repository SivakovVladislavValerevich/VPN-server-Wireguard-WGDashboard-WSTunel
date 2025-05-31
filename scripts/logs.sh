#!/bin/bash

# Скрипт для управления логами VPN-сервера WireGuard
# Поддерживает просмотр, очистку и ротацию логов

# Определение директории скрипта для корректного подключения зависимостей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/utils"
CONFIG_FILE="$(cd "$SCRIPT_DIR/.." && pwd)/config.conf"

# Подключение утилит
source "$UTILS_DIR/log_utils.sh"

# Определение директории для хранения логов
DEFAULT_LOG_DIR="/var/log/wireguard"
LOG_DIR="$DEFAULT_LOG_DIR"

# Функция вывода справки
show_help() {
    echo ""
    echo "Использование: $0 [опция] [параметры]"
    echo ""
    echo "Опции:"
    echo "  view [service]     Просмотр логов (опционально: wireguard, wgdashboard, wstunnel, system или all)"
    echo "  tail [service]     Вывод последних 50 строк логов с обновлением в реальном времени"
    echo "  clean [service]    Очистка логов указанного сервиса"
    echo "  rotate             Принудительная ротация всех логов"
    echo "  --help, -h         Показать данную справку"
    echo ""
    echo "Примеры использования:"
    echo "  $0 view wireguard  # Показать логи WireGuard"
    echo "  $0 tail wstunnel   # Показать последние 50 строк логов WSTunnel с обновлением"
    echo "  $0 view all        # Показать все логи"
    echo "  $0 clean all       # Очистить все логи"
    echo ""
}

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
    
    # Если в конфигурации задана пользовательская директория для логов
    if [[ -n "$LOG_CUSTOM_DIR" ]]; then
        LOG_DIR="$LOG_CUSTOM_DIR"
        log_info "Используется пользовательская директория для логов: $LOG_DIR"
    fi
else
    log_warning "Конфигурационный файл не найден: $CONFIG_FILE"
    log_warning "Будут использованы значения по умолчанию"
fi

# Создаем директорию для логов, если она не существует
if [[ ! -d "$LOG_DIR" ]]; then
    mkdir -p "$LOG_DIR"
    log_info "Создана директория для логов: $LOG_DIR"
fi

# Определение файлов логов для различных сервисов
WIREGUARD_LOG="$LOG_DIR/wireguard.log"
WGDASHBOARD_LOG="$LOG_DIR/wgdashboard.log"
WSTUNNEL_LOG="$LOG_DIR/wstunnel.log"
SYSTEM_LOG="$LOG_DIR/system.log"
INSTALL_LOG="$LOG_DIR/install.log"

# Функция для проверки существования логов
check_logs_exist() {
    local service="$1"
    local log_file
    
    case "$service" in
        wireguard)
            log_file="$WIREGUARD_LOG"
            ;;
        wgdashboard)
            log_file="$WGDASHBOARD_LOG"
            ;;
        wstunnel)
            log_file="$WSTUNNEL_LOG"
            ;;
        system)
            log_file="$SYSTEM_LOG"
            ;;
        install)
            log_file="$INSTALL_LOG"
            ;;
        *)
            log_error "Неизвестный сервис: $service"
            return 1
            ;;
    esac
    
    if [[ ! -f "$log_file" ]]; then
        log_warning "Файл логов для сервиса $service не существует: $log_file"
        return 1
    fi
    
    return 0
}

# Функция для просмотра логов
view_logs() {
    local service="$1"
    
    case "$service" in
        wireguard)
            if check_logs_exist "wireguard"; then
                log_section "Просмотр логов WireGuard"
                cat "$WIREGUARD_LOG" | less
            fi
            ;;
        wgdashboard)
            if check_logs_exist "wgdashboard"; then
                log_section "Просмотр логов WGDashboard"
                cat "$WGDASHBOARD_LOG" | less
            fi
            ;;
        wstunnel)
            if check_logs_exist "wstunnel"; then
                log_section "Просмотр логов WSTunnel"
                cat "$WSTUNNEL_LOG" | less
            fi
            ;;
        system)
            if check_logs_exist "system"; then
                log_section "Просмотр системных логов"
                cat "$SYSTEM_LOG" | less
            fi
            ;;
        install)
            if check_logs_exist "install"; then
                log_section "Просмотр логов установки"
                cat "$INSTALL_LOG" | less
            fi
            ;;
        all)
            log_section "Просмотр всех логов"
            for service in "wireguard" "wgdashboard" "wstunnel" "system" "install"; do
                if check_logs_exist "$service"; then
                    echo -e "\n=== Логи $service ===\n"
                    cat "$LOG_DIR/${service}.log"
                    echo -e "\n"
                fi
            done | less
            ;;
        *)
            log_error "Неизвестный сервис: $service"
            return 1
            ;;
    esac
    
    return 0
}

# Функция для просмотра логов в режиме реального времени
tail_logs() {
    local service="$1"
    
    case "$service" in
        wireguard)
            if check_logs_exist "wireguard"; then
                log_section "Просмотр последних логов WireGuard (Ctrl+C для выхода)"
                tail -n 50 -f "$WIREGUARD_LOG"
            fi
            ;;
        wgdashboard)
            if check_logs_exist "wgdashboard"; then
                log_section "Просмотр последних логов WGDashboard (Ctrl+C для выхода)"
                tail -n 50 -f "$WGDASHBOARD_LOG"
            fi
            ;;
        wstunnel)
            if check_logs_exist "wstunnel"; then
                log_section "Просмотр последних логов WSTunnel (Ctrl+C для выхода)"
                tail -n 50 -f "$WSTUNNEL_LOG"
            fi
            ;;
        system)
            if check_logs_exist "system"; then
                log_section "Просмотр последних системных логов (Ctrl+C для выхода)"
                tail -n 50 -f "$SYSTEM_LOG"
            fi
            ;;
        all)
            log_section "Просмотр последних строк всех логов (Ctrl+C для выхода)"
            # Находим все существующие файлы логов и выводим их в tail
            log_files=()
            for service in "wireguard" "wgdashboard" "wstunnel" "system" "install"; do
                if [[ -f "$LOG_DIR/${service}.log" ]]; then
                    log_files+=("$LOG_DIR/${service}.log")
                fi
            done
            
            if [[ ${#log_files[@]} -gt 0 ]]; then
                tail -n 50 -f "${log_files[@]}"
            else
                log_warning "Не найдено ни одного файла логов"
                return 1
            fi
            ;;
        *)
            log_error "Неизвестный сервис: $service"
            return 1
            ;;
    esac
    
    return 0
}

# Функция для очистки логов
clean_logs() {
    local service="$1"
    
    case "$service" in
        wireguard)
            log_info "Очистка логов WireGuard..."
            echo "" > "$WIREGUARD_LOG"
            log_success "Логи WireGuard очищены"
            ;;
        wgdashboard)
            log_info "Очистка логов WGDashboard..."
            echo "" > "$WGDASHBOARD_LOG"
            log_success "Логи WGDashboard очищены"
            ;;
        wstunnel)
            log_info "Очистка логов WSTunnel..."
            echo "" > "$WSTUNNEL_LOG"
            log_success "Логи WSTunnel очищены"
            ;;
        system)
            log_info "Очистка системных логов..."
            echo "" > "$SYSTEM_LOG"
            log_success "Системные логи очищены"
            ;;
        install)
            log_info "Очистка логов установки..."
            echo "" > "$INSTALL_LOG"
            log_success "Логи установки очищены"
            ;;
        all)
            log_info "Очистка всех логов..."
            for service in "wireguard" "wgdashboard" "wstunnel" "system" "install"; do
                echo "" > "$LOG_DIR/${service}.log" 2>/dev/null || true
            done
            log_success "Все логи очищены"
            ;;
        *)
            log_error "Неизвестный сервис: $service"
            return 1
            ;;
    esac
    
    return 0
}

# Функция для ротации логов
rotate_logs() {
    log_info "Выполняем ротацию всех логов..."
    
    for service in "wireguard" "wgdashboard" "wstunnel" "system" "install"; do
        if [[ -f "$LOG_DIR/${service}.log" ]]; then
            timestamp=$(date +%Y%m%d-%H%M%S)
            cp "$LOG_DIR/${service}.log" "$LOG_DIR/${service}-${timestamp}.log"
            echo "" > "$LOG_DIR/${service}.log"
            log_info "Ротация логов $service выполнена: ${service}-${timestamp}.log"
        fi
    done
    
    # Удаление старых логов, если включено в конфигурации
    if [[ "$LOG_OPERATIONS_BACKUP_ENABLED" == "true" && -n "$LOG_OPERATIONS_BACKUP_RETENTION_DAYS" ]]; then
        log_info "Удаление старых логов (старше $LOG_OPERATIONS_BACKUP_RETENTION_DAYS дней)..."
        
        find "$LOG_DIR" -name "*.log" -type f -mtime +$LOG_OPERATIONS_BACKUP_RETENTION_DAYS -delete
        
        log_success "Старые логи удалены"
    fi
    
    log_success "Ротация логов завершена"
    
    return 0
}

# Обработка аргументов командной строки
case "$1" in
    view)
        service="${2:-all}"
        view_logs "$service"
        ;;
        
    tail)
        service="${2:-all}"
        tail_logs "$service"
        ;;
        
    clean)
        service="${2:-all}"
        
        read -p "Вы уверены, что хотите очистить логи для $service? (y/n): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            clean_logs "$service"
        else
            log_info "Операция очистки логов отменена пользователем"
        fi
        ;;
        
    rotate)
        rotate_logs
        ;;
        
    --help|-h)
        show_help
        exit 0
        ;;
        
    *)
        if [[ -z "$1" ]]; then
            log_error "Не указана опция"
        else
            log_error "Неизвестная опция: $1"
        fi
        show_help
        exit 1
        ;;
esac

exit 0 