#!/bin/bash
# Скрипт для настройки файрвола (iptables)

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
    log_info "[module_03] Конфигурационный файл загружен: $CONFIG_FILE"
else
    log_error "[module_03] Файл конфигурации не найден: $CONFIG_FILE"
    exit 1
fi

# Функция для проверки и установки iptables-persistent
install_iptables_persistent() {
    log_install "[module_03] Проверка и установка iptables-persistent..."
    
    if ! is_package_installed "iptables-persistent"; then
        log_install "[module_03] Установка iptables-persistent..."
        
        # Предварительно настраиваем debconf для автоматического ответа на вопросы
        echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
        echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections
        
        apt-get update -y
        apt-get install -y iptables-persistent netfilter-persistent || {
            log_error "[module_03] Не удалось установить iptables-persistent"
            return 1
        }
    else
        log_install "iptables-persistent уже установлен"
    fi
    
    return 0
}

# Функция для настройки IP-форвардинга
setup_ip_forwarding() {
    log_install "[module_03] Настройка IP-форвардинга..."
    
    # Проверяем, включен ли IP-форвардинг
    local current_status=$(cat /proc/sys/net/ipv4/ip_forward)
    
    if [ "$current_status" -eq 1 ]; then
        log_install "[module_03] IP-форвардинг уже включен"
    else
        # Включаем IP-форвардинг временно
        echo 1 > /proc/sys/net/ipv4/ip_forward
        
        # Включаем IP-форвардинг постоянно
        if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
            echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
        fi
        
        # Применяем настройки sysctl без вывода на экран
        sysctl -p /etc/sysctl.conf > /dev/null 2>&1 || {
            log_error "[module_03] Не удалось применить настройки sysctl"
            return 1
        }
        
        log_install "[module_03] IP-форвардинг успешно включен"
    fi
    
    return 0
}

# Функция для очистки правил iptables
clear_iptables_rules() {
    log_install "[module_03] Очистка текущих правил iptables..."
    
    # Очистка всех цепочек и правил
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    iptables -t mangle -F
    iptables -t mangle -X
    
    log_install "[module_03] Правила iptables успешно очищены"
    return 0
}

# Функция для настройки базовых правил iptables
setup_basic_iptables_rules() {
    log_install "[module_03] Настройка базовых правил iptables..."
    
    # Устанавливаем политики по умолчанию
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    
    # Разрешаем локальный интерфейс
    iptables -A INPUT -i lo -j ACCEPT
    
    # Разрешаем установленные и связанные соединения
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
    
    # Разрешаем SSH (по умолчанию порт 22)
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    
    # Разрешаем ICMP (пинги), если включено в конфигурации
    if [ "$FIREWALL_ALLOW_PING" = "true" ]; then
        iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
        log_install "[module_03] Разрешены ICMP-запросы (пинги)"
    else
        log_install "[module_03] ICMP-запросы (пинги) запрещены"
    fi
    
    log_install "[module_03] Базовые правила iptables успешно настроены"
    return 0
}

# Функция для настройки правил для WireGuard
setup_wireguard_iptables_rules() {
    log_install "[module_03] Настройка правил iptables для WireGuard..."
    
    # Определяем сетевой интерфейс
    local interface=${SERVER_NETWORK_INTERFACE:-$(detect_network_interface)}
    if [ -z "$interface" ]; then
        log_error "[module_03] Не удалось определить основной сетевой интерфейс"
        return 1
    fi
    
    log_install "[module_03] Использование сетевого интерфейса: $interface"
    
    # Разрешаем UDP-трафик на порт WireGuard
    iptables -A INPUT -p udp --dport "${WG_PORT}" -j ACCEPT
    
    # Настраиваем NAT для трафика WireGuard
    iptables -t nat -A POSTROUTING -o "$interface" -j MASQUERADE
    
    # Разрешаем перенаправление трафика с интерфейса wg0
    iptables -A FORWARD -i wg0 -j ACCEPT
    
    log_install "[module_03] Правила iptables для WireGuard успешно настроены"
    return 0
}

# Функция для настройки правил для WGDashboard
setup_wgdashboard_iptables_rules() {
    if [ "$INSTALL_WGDASHBOARD_ENABLED" = "true" ]; then
        log_install "[module_03] Настройка правил iptables для WGDashboard..."
        
        # Разрешаем TCP-трафик на порт WGDashboard
        iptables -A INPUT -p tcp --dport "${WGDASHBOARD_PORT}" -j ACCEPT
        
        log_install "[module_03] Правила iptables для WGDashboard успешно настроены"
    else
        log_install "[module_03] Установка WGDashboard не выбрана, правила файрвола не добавляются"
    fi
    
    return 0
}

# Функция для настройки правил для Wstunnel
setup_wstunnel_iptables_rules() {
    if [ "$INSTALL_WSTUNNEL_ENABLED" = "true" ]; then
        log_install "[module_03] Настройка правил iptables для Wstunnel..."
        
        # Разрешаем TCP-трафик на порт Wstunnel
        iptables -A INPUT -p tcp --dport "${WSTUNNEL_PORT}" -j ACCEPT
        
        # Разрешаем UDP-трафик на порт Wstunnel (если используется)
        iptables -A INPUT -p udp --dport "${WSTUNNEL_PORT}" -j ACCEPT
        
        log_install "[module_03] Правила iptables для Wstunnel успешно настроены"
    else
        log_install "[module_03] Установка Wstunnel не выбрана, правила файрвола не добавляются"
    fi
    
    return 0
}

# Функция для настройки защиты от DDoS
setup_ddos_protection() {
    if [ "$FIREWALL_ENABLE_DOS_PROTECTION" = "true" ]; then
        log_install "[module_03] Настройка базовой защиты от DDoS-атак..."
        
        # Защита от сканирования портов
        iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
        iptables -A INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
        iptables -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
        iptables -A INPUT -p tcp --tcp-flags FIN,RST FIN,RST -j DROP
        iptables -A INPUT -p tcp --tcp-flags ACK,FIN FIN -j DROP
        iptables -A INPUT -p tcp --tcp-flags ACK,URG URG -j DROP
        
        # Ограничение на новые соединения
        iptables -A INPUT -p tcp -m conntrack --ctstate NEW -m limit --limit 60/s --limit-burst 100 -j ACCEPT
        iptables -A INPUT -p tcp -m conntrack --ctstate NEW -j DROP
        
        # Дополнительная защита для Wstunnel (если включен)
        if [ "$INSTALL_WSTUNNEL_ENABLED" = "true" ]; then
            iptables -A INPUT -p tcp --dport "$WSTUNNEL_PORT" -m conntrack --ctstate NEW -m limit --limit 10/s --limit-burst 20 -j ACCEPT
            iptables -A INPUT -p udp --dport "$WSTUNNEL_PORT" -m conntrack --ctstate NEW -m limit --limit 10/s --limit-burst 20 -j ACCEPT
        fi
        
        log_install "[module_03] Базовая защита от DDoS-атак успешно настроена"
    else
        log_install "[module_03] Защита от DDoS-атак отключена в конфигурации"
    fi
    
    return 0
}

# Функция для сохранения правил iptables
save_iptables_rules() {
    log_install "[module_03] Сохранение правил iptables..."
    
    if command_exists "netfilter-persistent"; then
        netfilter-persistent save || {
            log_error "[module_03] Не удалось сохранить правила iptables с помощью netfilter-persistent"
            return 1
        }
    else
        # Резервный метод сохранения
        iptables-save > /etc/iptables/rules.v4 || {
            log_error "[module_03] Не удалось сохранить правила iptables"
            return 1
        }
    fi
    
    # Создаем резервную копию правил
    backup_file "/etc/iptables/rules.v4" "config"
    
    log_install "[module_03] Правила iptables успешно сохранены"
    return 0
}

# Главная функция
main() {
    log_install "[module_03] Начало настройки файрвола..."
    
    # Проверяем права суперпользователя
    if ! check_root; then
        log_error "[module_03] Этот скрипт требует прав суперпользователя"
        return 1
    fi
    
    # Устанавливаем iptables-persistent
    install_iptables_persistent || {
        log_error "[module_03] Не удалось установить iptables-persistent"
        return 1
    }
    
    # Настраиваем IP-форвардинг
    setup_ip_forwarding || {
        log_error "[module_03] Не удалось настроить IP-форвардинг"
        return 1
    }
    
    # Очищаем текущие правила iptables
    clear_iptables_rules || {
        log_error "[module_03] Не удалось очистить правила iptables"
        return 1
    }
    
    # Настраиваем базовые правила iptables
    setup_basic_iptables_rules || {
        log_error "[module_03] Не удалось настроить базовые правила iptables"
        return 1
    }
    
    # Настраиваем правила для WireGuard
    setup_wireguard_iptables_rules || {
        log_error "[module_03] Не удалось настроить правила iptables для WireGuard"
        return 1
    }
    
    # Настраиваем правила для WGDashboard
    setup_wgdashboard_iptables_rules || {
        log_error "[module_03] Не удалось настроить правила iptables для WGDashboard"
        return 1
    }
    
    # Настраиваем правила для Wstunnel
    setup_wstunnel_iptables_rules || {
        log_error "[module_03] Не удалось настроить правила iptables для Wstunnel"
        return 1
    }
    
    # Настраиваем защиту от DDoS
    setup_ddos_protection || {
        log_error "[module_03] Не удалось настроить защиту от DDoS"
        return 1
    }
    
    # Сохраняем правила iptables
    save_iptables_rules || {
        log_error "[module_03] Не удалось сохранить правила iptables"
        return 1
    }
    
    log_install "[module_03] Настройка файрвола успешно завершена"
    return 0
}

# Запускаем главную функцию
main 