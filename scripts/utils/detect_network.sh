#!/bin/bash
# Утилиты для определения сетевых параметров

# Импортируем утилиты логирования, если они еще не импортированы
if ! command -v log_info &> /dev/null; then
    source "$(dirname "$0")/log_utils.sh"
fi

# Функция для определения публичного IP-адреса сервера
detect_public_ip() {
    local ip=""
    log_info "[detect_network] Определение публичного IP-адреса сервера..."
    
    # Список сервисов для определения внешнего IP
    local services=(
        "http://ifconfig.me/ip"
        "http://api.ipify.org"
        "http://ipinfo.io/ip"
        "http://icanhazip.com"
        "http://ident.me"
        "http://ipecho.net/plain"
    )
    
    # Пробуем разные сервисы, пока не получим IP
    for service in "${services[@]}"; do
        ip=$(curl -s --connect-timeout 5 "$service" 2>/dev/null)
        if [[ -n "$ip" && "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            log_info "Публичный IP-адрес: $ip"
            echo "$ip"
            return 0
        fi
    done
    
    log_error "[detect_network] Не удалось определить публичный IP-адрес"
    echo ""
    return 1
}

# Функция для определения основного сетевого интерфейса
detect_network_interface() {
    # Пытаемся определить интерфейс через ip route
    local interface
    interface=$(ip route | grep default | awk '{print $5}' | head -n1)
    
    # Если не удалось определить через ip route, пробуем через netstat
    if [ -z "$interface" ]; then
        interface=$(netstat -rn | grep '^0.0.0.0' | awk '{print $8}' | head -n1)
    fi
    
    # Если все еще не удалось определить, проверяем наличие eth0
    if [ -z "$interface" ] && [ -e "/sys/class/net/eth0" ]; then
        interface="eth0"
    fi
    
    # Выводим результат
    if [ -n "$interface" ]; then
        echo "$interface"
        return 0
    fi
    
    return 1
}

# Функция для определения IP-адреса шлюза по умолчанию
detect_default_gateway() {
    local gateway=""
    log_info "[detect_network] Определение IP-адреса шлюза по умолчанию..."
    
    # Попытка определить шлюз из маршрута по умолчанию
    gateway=$(ip route | grep default | awk '{print $3}' | head -n1)
    
    if [[ -n "$gateway" && "$gateway" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_info "[detect_network] IP-адрес шлюза по умолчанию: $gateway"
        echo "$gateway"
        return 0
    else
        log_error "[detect_network] Не удалось определить IP-адрес шлюза по умолчанию"
        echo ""
        return 1
    fi
}

# Экспорт функций
export -f detect_public_ip
export -f detect_network_interface
export -f detect_default_gateway 