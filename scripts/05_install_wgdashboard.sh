#!/bin/bash
# Скрипт для установки веб-интерфейса WGDashboard

# Загружаем утилиты
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPT_DIR/utils/log_utils.sh"
source "$SCRIPT_DIR/utils/system_utils.sh"
source "$SCRIPT_DIR/utils/backup_utils.sh"

# Загружаем конфигурацию
CONFIG_FILE="$(dirname "$(realpath "$SCRIPT_DIR")")/config.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    log_info "[module_05] Конфигурационный файл загружен: $CONFIG_FILE"
else
    log_error "[module_05] Файл конфигурации не найден: $CONFIG_FILE"
    exit 1
fi

# Функция для установки зависимостей
install_dependencies() {
    log_install "[module_05] Установка зависимостей WGDashboard..."
    
    # Устанавливаем пакеты, необходимые для WGDashboard
    apt-get update -y || {
        log_error "[module_05] Не удалось обновить список пакетов"
        return 1
    }
    
    apt-get install -y python3 python3-pip python3-venv git net-tools || {
        log_error "[module_05] Не удалось установить зависимости WGDashboard"
        return 1
    }
    
    log_install "[module_05] Зависимости WGDashboard успешно установлены"
    return 0
}

# Функция для клонирования репозитория WGDashboard
clone_wgdashboard_repo() {
    log_install "[module_05] Клонирование репозитория WGDashboard..."
    
    # Проверяем, существует ли уже директория WGDashboard
    if [ -d "$HOME/WGDashboard" ]; then
        log_warning "[module_05] Директория WGDashboard уже существует"
        
        read -p "[module_05] Удалить существующую директорию и клонировать заново? (y/n): " -r answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            rm -rf "$HOME/WGDashboard"
        else
            log_install "[module_05] Продолжение с существующей директорией WGDashboard"
            return 0
        fi
    fi
    
    # Клонируем репозиторий
    cd "$HOME" || {
        log_error "[module_05] Не удалось перейти в домашнюю директорию"
        return 1
    }
    
    git clone https://github.com/donaldzou/WGDashboard.git || {
        log_error "[module_05] Не удалось клонировать репозиторий WGDashboard"
        return 1
    }
    
    log_install "[module_05] Репозиторий WGDashboard успешно клонирован"
    return 0
}

# Функция для установки WGDashboard
install_wgdashboard() {
    log_install "[module_05] Установка WGDashboard..."
    
    # Переходим в директорию src
    cd "$HOME/WGDashboard/src" || {
        log_error "[module_05] Не удалось перейти в директорию WGDashboard/src"
        return 1
    }
    
    # Делаем скрипт исполняемым
    chmod +x ./wgd.sh || {
        log_error "[module_05] Не удалось сделать скрипт wgd.sh исполняемым"
        return 1
    }
    
    # Устанавливаем права на /etc/wireguard рекурсивно
    chmod -R 755 /etc/wireguard || {
        log_error "[module_05] Не удалось установить права на директорию /etc/wireguard"
        return 1
    }
    
    # Запускаем скрипт установки
    ./wgd.sh install || {
        log_error "[module_05] Не удалось выполнить установку WGDashboard"
        return 1
    }
    
    log_install "[module_05] WGDashboard успешно установлен"
    return 0
}

# Функция для создания службы systemd
create_systemd_service() {
    log_install "[module_05] Создание службы systemd для WGDashboard..."
    
    # Путь к файлу службы
    local service_file="/etc/systemd/system/wg-dashboard.service"
    
    # Абсолютный путь к директории WGDashboard
    local wgd_path="$HOME/WGDashboard/src"
    
    # Создаем файл службы
    cat > "$service_file" << EOF
[Unit]
After=syslog.target network-online.target
Wants=wg-quick.target
ConditionPathIsDirectory=/etc/wireguard

[Service]
Type=forking
PIDFile=${wgd_path}/gunicorn.pid
WorkingDirectory=${wgd_path}
ExecStart=${wgd_path}/wgd.sh start
ExecStop=${wgd_path}/wgd.sh stop
ExecReload=${wgd_path}/wgd.sh restart
TimeoutSec=120
PrivateTmp=yes
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # Устанавливаем права на файл службы
    chmod 664 "$service_file" || {
        log_error "[module_05] Не удалось установить права на файл службы"
        return 1
    }
    
    # Создаем резервную копию файла службы
    backup_file "$service_file" "template"
    
    log_install "[module_05] Служба systemd для WGDashboard успешно создана"
    return 0
}

# Функция для запуска службы WGDashboard
start_wgdashboard_service() {
    log_install "[module_05] Запуск службы WGDashboard..."
    
    # Перезагружаем демон systemd
    systemctl daemon-reload || {
        log_error "[module_05] Не удалось перезагрузить демон systemd"
        return 1
    }
    
    # Включаем службу для запуска при загрузке системы
    systemctl enable wg-dashboard.service || {
        log_error "[module_05] Не удалось включить службу WGDashboard для запуска при загрузке"
        return 1
    }
    
    # Запускаем службу
    systemctl start wg-dashboard.service || {
        log_error "[module_05] Не удалось запустить службу WGDashboard"
        return 1
    }
    
    # Проверяем статус службы
    if systemctl is-active --quiet wg-dashboard.service; then
        log_install "[module_05] Служба WGDashboard успешно запущена"
        return 0
    else
        log_error "[module_05] Служба WGDashboard не запущена"
        return 1
    fi
}

# Функция для вывода информации о доступе
display_access_info() {
    log_install "Информация о доступе к WGDashboard:"
    log_install "URL: http://${SERVER_PUBLIC_IP}:${WGDASHBOARD_PORT}"
    log_install "При первом входе вы будете перенаправлены на страницу создания учетной записи."
}

# Главная функция
main() {
    log_install "[module_05] Начало установки WGDashboard..."
    
    # Проверяем права суперпользователя
    if ! check_root; then
        log_error "[module_05] Этот скрипт требует прав суперпользователя"
        return 1
    fi
    
    # Устанавливаем зависимости
    install_dependencies || {
        log_error "[module_05] Не удалось установить зависимости WGDashboard"
        return 1
    }
    
    # Клонируем репозиторий
    clone_wgdashboard_repo || {
        log_error "[module_05] Не удалось клонировать репозиторий WGDashboard"
        return 1
    }
    
    # Устанавливаем WGDashboard
    install_wgdashboard || {
        log_error "[module_05] Не удалось установить WGDashboard"
        return 1
    }
    
    # Создаем службу systemd
    create_systemd_service || {
        log_error "[module_05] Не удалось создать службу systemd для WGDashboard"
        return 1
    }
    
    # Запускаем службу
    start_wgdashboard_service || {
        log_error "[module_05] Не удалось запустить службу WGDashboard"
        return 1
    }
    
    # Выводим информацию о доступе
    display_access_info
    
    log_install "[module_05] Установка WGDashboard успешно завершена"
    return 0
}

# Запускаем главную функцию
main 