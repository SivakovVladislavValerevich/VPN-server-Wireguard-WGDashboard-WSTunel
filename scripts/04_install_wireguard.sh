#!/bin/bash
# Скрипт для установки и настройки WireGuard

# Загружаем утилиты
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPT_DIR/utils/log_utils.sh"
source "$SCRIPT_DIR/utils/system_utils.sh"
source "$SCRIPT_DIR/utils/backup_utils.sh"
source "$SCRIPT_DIR/utils/detect_network.sh"

# Загружаем конфигурацию
CONFIG_FILE="$(dirname "$(realpath "$SCRIPT_DIR")")/config.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    log_info "[module_04] Конфигурационный файл загружен: $CONFIG_FILE"
else
    log_error "[module_04] Файл конфигурации не найден: $CONFIG_FILE"
    exit 1
fi

# Функция для включения IP форвардинга
enable_ip_forwarding() {
    log_install "[module_04] Включение IP форвардинга..."
    
    # Проверяем текущее состояние IP форвардинга
    if [ "$(cat /proc/sys/net/ipv4/ip_forward)" = "1" ]; then
        log_install "[module_04] IP форвардинг уже включен"
        return 0
    fi

    # Включаем IP форвардинг постоянно
    if ! grep -q "net.ipv4.ip_forward\s*=\s*1" /etc/sysctl.conf; then
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf || {
            log_error "[module_04] Не удалось добавить настройку IP форвардинга в /etc/sysctl.conf"
            return 1
        }
    fi
    
    # Применяем настройки sysctl
    sysctl -p /etc/sysctl.conf || {
        log_error "[module_04] Не удалось применить настройки sysctl"
        return 1
    }
    
    log_install "[module_04] IP форвардинг успешно включен"
    return 0
}

# Функция для установки WireGuard
install_wireguard() {
    log_install "[module_04] Установка WireGuard..."
    
    # Устанавливаем пакеты WireGuard
    apt-get update -y || {
        log_error "[module_04] Не удалось обновить список пакетов"
        return 1
    }
    
    apt-get install -y wireguard wireguard-tools || {
        log_error "[module_04] Не удалось установить WireGuard"
        return 1
    }
    
    log_install "[module_04] WireGuard успешно установлен"
    return 0
}

# Функция для генерации ключей WireGuard
generate_wireguard_keys() {
    log_install "[module_04] Генерация ключей WireGuard..."
    
    # Создаем директорию для WireGuard, если ее еще нет
    if [ ! -d "/etc/wireguard" ]; then
        mkdir -p /etc/wireguard
        chmod 700 /etc/wireguard
    fi
    
    # Устанавливаем правильные права доступа перед генерацией ключей
    umask 077
    
    # Генерируем приватный ключ и сразу создаем публичный (как в руководстве)
    wg genkey | tee /etc/wireguard/privatekey | wg pubkey | tee /etc/wireguard/publickey || {
        log_error "[module_04] Не удалось сгенерировать ключи"
        return 1
    }
    
    # Устанавливаем права доступа 600 на приватный ключ
    chmod 600 /etc/wireguard/privatekey
    
    log_install "[module_04] Ключи WireGuard успешно сгенерированы"
    return 0
}

# Функция для изменения порта по умолчанию в wg-quick
change_wg_quick_port() {
    log_install "[module_04] Изменение порта по умолчанию в wg-quick..."
    
    local wg_quick_path="/usr/bin/wg-quick"
    
    # Проверяем существование файла
    if [ ! -f "$wg_quick_path" ]; then
        log_error "[module_04] Файл wg-quick не найден: $wg_quick_path"
        return 1
    fi
    
    # Создаем резервную копию файла
    backup_file "$wg_quick_path" "template"
    
    # Ищем блок конфигурации с портом по умолчанию
    if grep -q "HAVE_SET_FIREWALL=0" "$wg_quick_path" && grep -q "table=51820" "$wg_quick_path"; then
        # Заменяем порт по умолчанию на указанный в конфигурации
        sed -i "s/table=51820/table=${WG_PORT}/g" "$wg_quick_path"
        log_install "[module_04] Порт по умолчанию в wg-quick изменен на ${WG_PORT}"
    else
        log_warning "[module_04] Не удалось найти блок конфигурации с портом по умолчанию в wg-quick"
        log_warning "[module_04] Проверьте файл вручную: ${wg_quick_path}"
        return 1
    fi
    
    return 0
}

# Функция для создания конфигурационного файла WireGuard
create_wireguard_config() {
    log_install "[module_04] Создание конфигурационного файла WireGuard..."
    
    # Определяем сетевой интерфейс без вывода логов
    local interface
    interface=$(detect_network_interface 2>/dev/null)
    interface=${SERVER_NETWORK_INTERFACE:-$interface}
    
    if [ -z "$interface" ]; then
        log_error "[module_04] Не удалось определить основной сетевой интерфейс"
        return 1
    fi
    
    # Получаем приватный ключ
    local private_key
    private_key=$(cat /etc/wireguard/privatekey 2>/dev/null)
    if [ -z "$private_key" ]; then
        log_error "[module_04] Не удалось прочитать приватный ключ"
        return 1
    fi
    
    # Создаем директорию для конфигурации, если ее еще нет
    if [ ! -d "/etc/wireguard" ]; then
        mkdir -p /etc/wireguard
        chmod 700 /etc/wireguard
    fi
    
    # Создаем или перезаписываем конфигурационный файл с правильными правами доступа
    umask 077
    {
        echo "[Interface]"
        echo "PrivateKey = ${private_key}"
        echo "Address = ${WG_SERVER_IP_PRIVATE}/24"
        echo "ListenPort = ${WG_PORT}"
        echo ""
        echo "PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ${interface} -j MASQUERADE"
        echo "PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ${interface} -j MASQUERADE"
    } > /etc/wireguard/wg0.conf

    # Устанавливаем правильные права доступа на конфигурационный файл
    chmod 600 /etc/wireguard/wg0.conf
    
    # Создаем резервную копию конфигурационного файла
    backup_file "/etc/wireguard/wg0.conf" "template"
    
    log_install "[module_04] Конфигурационный файл WireGuard успешно создан"
    return 0
}

# Функция для запуска службы WireGuard
start_wireguard_service() {
    log_install "[module_04] Запуск службы WireGuard..."
    
    # Проверяем наличие конфигурационного файла
    if [ ! -f "/etc/wireguard/wg0.conf" ]; then
        log_error "[module_04] Конфигурационный файл не найден: /etc/wireguard/wg0.conf"
        return 1
    fi
    
    # Проверяем синтаксис конфигурационного файла
    if ! wg-quick strip wg0 > /dev/null 2>&1; then
        log_error "[module_04] Ошибка в конфигурационном файле wg0.conf"
        return 1
    fi
    
    # Проверяем права доступа на конфигурационный файл
    if [ "$(stat -c %a /etc/wireguard/wg0.conf)" != "600" ]; then
        chmod 600 /etc/wireguard/wg0.conf
    fi
    
    # Останавливаем службу, если она уже запущена
    if systemctl is-active --quiet wg-quick@wg0.service; then
        systemctl stop wg-quick@wg0.service
        sleep 2
    fi
    
    # Удаляем интерфейс, если он существует
    if ip link show wg0 >/dev/null 2>&1; then
        ip link delete wg0
    fi
    
    # Перезагружаем конфигурацию systemd
    systemctl daemon-reload
    
    # Включаем службу для запуска при загрузке системы
    systemctl enable wg-quick@wg0.service || {
        log_error "[module_04] Не удалось включить службу WireGuard для запуска при загрузке"
        return 1
    }
    
    # Запускаем службу
    if ! systemctl start wg-quick@wg0.service; then
        log_error "[module_04] Не удалось запустить службу WireGuard"
        log_error "$(systemctl status wg-quick@wg0.service)"
        return 1
    fi
    
    # Ждем несколько секунд, чтобы служба успела запуститься
    sleep 3
    
    # Проверяем статус службы и интерфейса
    if systemctl is-active --quiet wg-quick@wg0.service; then
        if ip link show wg0 >/dev/null 2>&1; then
            if wg show wg0 >/dev/null 2>&1; then
                log_install "[module_04] Служба WireGuard успешно запущена"
                return 0
            else
                log_error "[module_04] Интерфейс WireGuard не настроен"
                return 1
            fi
        else
            log_error "[module_04] Интерфейс WireGuard не создан"
            return 1
        fi
    else
        log_error "[module_04] Служба WireGuard не запущена"
        return 1
    fi
}

# Функция для проверки статуса WireGuard
check_wireguard_status() {
    log_install "[module_04] Проверка статуса WireGuard..."
    
    # Проверяем статус интерфейса WireGuard
    if ! wg show all &>/dev/null; then
        log_error "[module_04] WireGuard не настроен или не запущен"
        return 1
    fi
    
    # Проверяем наличие интерфейса wg0
    if ! ip link show wg0 &>/dev/null; then
        log_error "[module_04] Интерфейс WireGuard wg0 не существует"
        return 1
    fi
    
    # Проверяем статус службы
    if ! systemctl is-active --quiet wg-quick@wg0.service; then
        log_error "[module_04] Служба WireGuard не запущена"
        return 1
    fi
    
    log_install "[module_04] WireGuard успешно настроен и запущен"
    log_install "============= ИНФОРМАЦИЯ О WIREGUARD =============\n$(wg show all)"
    
    return 0
}

# Главная функция
main() {
    log_install "[module_04] Начало установки и настройки WireGuard..."
    
    # Проверяем права суперпользователя
    if ! check_root; then
        log_error "[module_04] Этот скрипт требует прав суперпользователя"
        return 1
    fi
    
    # Включаем IP форвардинг
    enable_ip_forwarding || {
        log_error "[module_04] Не удалось включить IP форвардинг"
        return 1
    }
    
    # Устанавливаем WireGuard
    install_wireguard || {
        log_error "[module_04] Не удалось установить WireGuard"
        return 1
    }
    
    # Генерируем ключи WireGuard
    generate_wireguard_keys || {
        log_error "[module_04] Не удалось сгенерировать ключи WireGuard"
        return 1
    }
    
    # Изменяем порт по умолчанию в wg-quick
    change_wg_quick_port || {
        log_warning "[module_04] Не удалось изменить порт по умолчанию в wg-quick"
        log_warning "[module_04] Продолжаем установку с портом, указанным в конфигурационном файле"
    }
    
    # Создаем конфигурационный файл WireGuard
    create_wireguard_config || {
        log_error "[module_04] Не удалось создать конфигурационный файл WireGuard"
        return 1
    }
    
    # Запускаем службу WireGuard
    start_wireguard_service || {
        log_error "[module_04] Не удалось запустить службу WireGuard"
        return 1
    }
    
    # Проверяем статус WireGuard
    check_wireguard_status || {
        log_warning "[module_04] WireGuard может быть не полностью настроен"
    }
    
    log_install "[module_04] Установка и настройка WireGuard успешно завершена"
    return 0
}

# Запускаем главную функцию
main 