#!/bin/bash
# Скрипт для установки Wstunnel (обфускация трафика WireGuard)

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
    log_info "[module_06] Конфигурационный файл загружен: $CONFIG_FILE"
else
    log_error "[module_06] Файл конфигурации не найден: $CONFIG_FILE"
    exit 1
fi

# Функция для установки зависимостей
install_dependencies() {
    log_install "[module_06] Установка зависимостей Wstunnel..."
    
    # Устанавливаем curl для скачивания файлов
    apt-get update -y || {
        log_error "[module_06] Не удалось обновить список пакетов"
        return 1
    }
    
    apt-get install -y curl || {
        log_error "[module_06] Не удалось установить curl"
        return 1
    }
    
    log_install "[module_06] Зависимости Wstunnel успешно установлены"
    return 0
}

# Функция для определения последней версии Wstunnel
get_latest_wstunnel_version() {
    log_install "[module_06] Определение последней версии Wstunnel..."
    
    # Используем фиксированную версию из руководства
    local version="10.1.9"
    log_install "[module_06] Используем версию Wstunnel: $version"
    echo "$version"
    return 0
}

# Функция для скачивания и установки Wstunnel
download_and_install_wstunnel() {
    log_install "[module_06] Скачивание и установка Wstunnel..."
    
    # Определяем версию
    local version="10.1.9"
    
    # Определяем архитектуру CPU
    local arch="amd64"
    if [ "$(uname -m)" = "aarch64" ] || [ "$(uname -m)" = "arm64" ]; then
        arch="arm64"
    fi
    
    # Временная директория для скачивания
    local temp_dir=$(mktemp -d)
    cd "$temp_dir" || {
        log_error "[module_06] Не удалось перейти во временную директорию"
        return 1
    }
    
    # Формируем URL для скачивания
    local download_url="https://github.com/erebe/wstunnel/releases/download/v${version}/wstunnel_${version}_linux_${arch}.tar.gz"
    log_install "[module_06] Скачивание Wstunnel с $download_url"
    
    # Скачиваем архив
    if ! curl -fLo "wstunnel.tar.gz" "$download_url"; then
        log_error "[module_06] Не удалось скачать Wstunnel"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Проверяем, что файл скачался
    if [ ! -f "wstunnel.tar.gz" ]; then
        log_error "[module_06] Файл wstunnel.tar.gz не найден после скачивания"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Извлекаем бинарный файл из архива
    if ! tar -xzf wstunnel.tar.gz wstunnel; then
        log_error "[module_06] Не удалось извлечь Wstunnel из архива"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Проверяем, что файл извлечён
    if [ ! -f "wstunnel" ]; then
        log_error "[module_06] Файл wstunnel не найден после распаковки"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Делаем файл исполняемым
    chmod +x wstunnel || {
        log_error "[module_06] Не удалось сделать Wstunnel исполняемым"
        rm -rf "$temp_dir"
        return 1
    }
    
    # Перемещаем бинарный файл в системную директорию
    if ! mv wstunnel /usr/local/bin/; then
        log_error "[module_06] Не удалось переместить Wstunnel в /usr/local/bin/"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Очищаем временную директорию
    rm -rf "$temp_dir"
    
    # Проверяем установку
    if command -v wstunnel >/dev/null 2>&1; then
        local installed_version
        installed_version=$(wstunnel --version 2>&1 | head -n1 | awk '{print $2}')
        log_install "[module_06] Wstunnel успешно установлен. Версия: $installed_version"
        return 0
    else
        log_error "[module_06] Не удалось установить Wstunnel"
        return 1
    fi
}

# Функция для настройки привилегий для Wstunnel
setup_wstunnel_privileges() {
    log_install "[module_06] Настройка привилегий для Wstunnel..."
    
    # Устанавливаем capability для использования привилегированных портов
    # Это позволяет запускать Wstunnel на порту 443 без прав root
    if command_exists setcap; then
        setcap cap_net_bind_service=+ep /usr/local/bin/wstunnel || {
            log_error "[module_06] Не удалось установить capabilities для Wstunnel"
            log_warning "[module_06] Wstunnel может не иметь возможности использовать привилегированные порты без прав root"
            return 1
        }
    else
        log_warning "[module_06] Команда setcap не найдена, установка capabilities пропущена"
        log_warning "[module_06] Wstunnel может не иметь возможности использовать привилегированные порты без прав root"
        return 1
    fi
    
    log_install "[module_06] Привилегии для Wstunnel успешно настроены"
    return 0
}

# Функция для создания пользователя без доступа к входу в систему
create_wstunnel_user() {
    log_install "[module_06] Создание пользователя для Wstunnel..."
    
    # Проверяем, существует ли уже пользователь
    if id "wstunnel" &>/dev/null; then
        log_install "[module_06] Пользователь wstunnel уже существует"
        return 0
    fi
    
    # Создаем системного пользователя без возможности входа
    useradd --system --shell /usr/sbin/nologin wstunnel || {
        log_error "[module_06] Не удалось создать пользователя wstunnel"
        return 1
    }
    
    log_install "[module_06] Пользователь wstunnel успешно создан"
    return 0
}

# Функция для генерации секретного ключа
generate_wstunnel_secret() {
    log_install "[module_06] Генерация секретного ключа для Wstunnel..."
    
    # Проверяем и создаем директорию /etc/wireguard, если она не существует
    if [ ! -d "/etc/wireguard" ]; then
        if ! mkdir -p /etc/wireguard; then
            log_error "[module_06] Не удалось создать директорию /etc/wireguard"
            return 1
        fi
        chmod 700 /etc/wireguard
    fi
    
    # Генерируем случайный ключ с помощью openssl, как указано в руководстве
    local secret
    secret=$(openssl rand -base64 42)
    if [ -z "$secret" ]; then
        log_error "[module_06] Не удалось сгенерировать секретный ключ"
        return 1
    fi
    
    # Сохраняем секретный ключ в файл
    if ! echo "$secret" > /etc/wireguard/wstunnel_secret; then
        log_error "[module_06] Не удалось сохранить секретный ключ в файл"
        return 1
    fi
    
    # Устанавливаем правильные права доступа на файл с секретным ключом
    if ! chmod 600 /etc/wireguard/wstunnel_secret; then
        log_error "[module_06] Не удалось установить права на файл с секретным ключом"
        return 1
    fi
    
    # Создаем резервную копию файла с секретным ключом
    backup_file "/etc/wireguard/wstunnel_secret" "template"
    
    # Сохраняем секретный ключ в конфигурацию
    update_config_value "WSTUNNEL_SECRET" "$secret" "$CONFIG_FILE"
    
    log_install "[module_06] Секретный ключ для Wstunnel успешно сгенерирован"
    return 0
}

# Функция для создания службы systemd
create_systemd_service() {
    log_install "[module_06] Создание службы systemd для Wstunnel..."
    
    # Путь к файлу службы
    local service_file="/etc/systemd/system/wstunnel.service"
    
    # Получаем секретный ключ
    if [ ! -f "/etc/wireguard/wstunnel_secret" ]; then
        log_error "[module_06] Файл с секретным ключом не найден"
        return 1
    fi
    
    local secret
    secret=$(cat /etc/wireguard/wstunnel_secret)
    if [ -z "$secret" ]; then
        log_error "[module_06] Секретный ключ пуст"
        return 1
    fi
    
    # Создаем файл службы в соответствии с руководством
    cat > "$service_file" << EOF
[Unit]
Description=Wstunnel for WireGuard
After=network-online.target
Wants=network-online.target

[Service]
User=wstunnel
Type=exec
ExecStart=/usr/local/bin/wstunnel server --restrict-http-upgrade-path-prefix "${secret}" --restrict-to localhost:${WG_PORT} wss://0.0.0.0:${WSTUNNEL_PORT}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    # Устанавливаем права на файл службы
    chmod 664 "$service_file" || {
        log_error "[module_06] Не удалось установить права на файл службы"
        return 1
    }
    
    # Создаем резервную копию файла службы
    backup_file "$service_file" "template"
    
    log_install "[module_06] Служба systemd для Wstunnel успешно создана"
    return 0
}

# Функция для запуска службы Wstunnel
start_wstunnel_service() {
    log_install "[module_06] Запуск службы Wstunnel..."
    
    # Перезагружаем демон systemd
    systemctl daemon-reload || {
        log_error "[module_06] Не удалось перезагрузить демон systemd"
        return 1
    }
    
    # Включаем службу для запуска при загрузке системы
    systemctl enable wstunnel.service || {
        log_error "[module_06] Не удалось включить службу Wstunnel для запуска при загрузке"
        return 1
    }
    
    # Запускаем службу
    systemctl start wstunnel.service || {
        log_error "[module_06] Не удалось запустить службу Wstunnel"
        return 1
    }
    
    # Проверяем статус службы
    if systemctl is-active --quiet wstunnel.service; then
        log_install "[module_06] Служба Wstunnel успешно запущена"
        return 0
    else
        log_error "[module_06] Служба Wstunnel не запущена"
        return 1
    fi
}

# Функция для сохранения информации для клиентов
save_client_info() {
    log_install "[module_06] Сохранение информации для клиентов Wstunnel..."
    
    # Путь к файлу с информацией для клиентов
    local info_file="$HOME/wstunnel_client_info.txt"
    
    # Получаем секретный ключ
    local secret=$(cat /etc/wireguard/wstunnel_secret)
    
    # Создаем файл с информацией для клиентов
    cat > "$info_file" << EOF
============= ИНФОРМАЦИЯ ДЛЯ КЛИЕНТОВ WSTUNNEL =============

Сервер: ${SERVER_PUBLIC_IP}
Порт: ${WSTUNNEL_PORT}
Секретный ключ: ${secret}

Команда для запуска клиента Wstunnel:
wstunnel client --http-upgrade-path-prefix "${secret}" -L "udp://20820:localhost:20820?timeout_sec=0" wss://${SERVER_PUBLIC_IP}:${WSTUNNEL_PORT}

Подробная информация по настройке клиентов в руководстве пользователя.
EOF

    log_install "[module_06] Информация для клиентов Wstunnel сохранена в файл: $info_file"
    return 0
}

# Функция для вывода информации о доступе
display_access_info() {
    log_install "Информация о доступе к Wstunnel:"
    log_install "------------------------------------"
    log_install "Сервер: ${SERVER_PUBLIC_IP}"
    log_install "Порт: ${WSTUNNEL_PORT}"
    log_install "Секретный ключ для клиентов сохранен в файл: $HOME/wstunnel_client_info.txt"
    log_install "------------------------------------"
}

# Главная функция
main() {
    log_install "[module_06] Начало установки Wstunnel..."
    
    # Проверяем права суперпользователя
    if ! check_root; then
        log_error "[module_06] Этот скрипт требует прав суперпользователя"
        return 1
    fi
    
    # Инициализируем директории для логов и бэкапов
    setup_logging "install"
    setup_backup_dirs
    
    # Устанавливаем зависимости
    install_dependencies || {
        log_error "[module_06] Не удалось установить зависимости Wstunnel"
        return 1
    }
    
    # Скачиваем и устанавливаем Wstunnel
    download_and_install_wstunnel || {
        log_error "[module_06] Не удалось скачать и установить Wstunnel"
        return 1
    }
    
    # Настраиваем привилегии для Wstunnel
    setup_wstunnel_privileges || {
        log_warning "[module_06] Не удалось настроить привилегии для Wstunnel, продолжаем установку"
    }
    
    # Создаем пользователя для Wstunnel
    create_wstunnel_user || {
        log_error "[module_06] Не удалось создать пользователя для Wstunnel"
        return 1
    }
    
    # Генерируем секретный ключ
    generate_wstunnel_secret || {
        log_error "[module_06] Не удалось сгенерировать секретный ключ для Wstunnel"
        return 1
    }
    
    # Создаем службу systemd
    create_systemd_service || {
        log_error "[module_06] Не удалось создать службу systemd для Wstunnel"
        return 1
    }
    
    # Запускаем службу
    start_wstunnel_service || {
        log_error "[module_06] Не удалось запустить службу Wstunnel"
        return 1
    }
    
    # Сохраняем информацию для клиентов
    save_client_info || {
        log_warning "[module_06] Не удалось сохранить информацию для клиентов Wstunnel"
    }
    
    # Выводим информацию о доступе
    display_access_info
    
    log_install "[module_06] Установка Wstunnel успешно завершена"
    return 0
}

# Запускаем главную функцию
main 