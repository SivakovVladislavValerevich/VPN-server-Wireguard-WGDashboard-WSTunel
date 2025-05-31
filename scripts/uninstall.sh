#!/bin/bash

# Скрипт для удаления VPN-сервера WireGuard и связанных компонентов

# Определение директории скрипта для корректного подключения зависимостей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/utils"
CONFIG_FILE="$(cd "$SCRIPT_DIR/.." && pwd)/config.conf"

# Подключение утилит
source "$UTILS_DIR/log_utils.sh"
source "$UTILS_DIR/system_utils.sh"

# Отображение баннера
log_banner "Удаление VPN-сервера WireGuard"

# Проверка запуска от имени root
if [[ $EUID -ne 0 ]]; then
   log_error "Этот скрипт должен быть запущен с правами суперпользователя (root)"
   log_info "Используйте: sudo $0"
   exit 1
fi

# Загрузка конфигурации, если она существует
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    log_success "Конфигурационный файл загружен: $CONFIG_FILE"
else
    log_warning "Конфигурационный файл не найден: $CONFIG_FILE"
    log_warning "Будут использованы значения по умолчанию"
    
    # Значения по умолчанию, если конфиг не найден
    WG_PORT=20820
    WGDASHBOARD_PORT=10086
    WSTUNNEL_PORT=443
fi

# Запрос подтверждения
log_warning "Внимание! Эта операция удалит все компоненты VPN-сервера, включая:"
log_warning "- WireGuard и его конфигурации"
log_warning "- WGDashboard и все данные клиентов"
log_warning "- WSTunnel (если установлен)"
log_warning "Эта операция необратима!"

read -p "Вы уверены, что хотите удалить VPN-сервер? (y/n): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    log_info "Операция удаления отменена пользователем"
    exit 0
fi

# Создание резервной копии перед удалением
log_section "Создание резервной копии настроек перед удалением"
BACKUP_DIR="/tmp/wireguard_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

if [[ -d "/etc/wireguard" ]]; then
    log_info "Создание резервной копии конфигураций WireGuard..."
    cp -r /etc/wireguard "$BACKUP_DIR/" 2>/dev/null || log_warning "Не удалось создать резервную копию /etc/wireguard"
    log_success "Резервная копия WireGuard создана в $BACKUP_DIR/wireguard"
fi

log_info "Резервная копия перед удалением сохранена в $BACKUP_DIR"

# Удаление WSTunnel, если он установлен
log_section "Удаление WSTunnel"
if system_service_exists "wstunnel"; then
    log_info "Останавливаем службу WSTunnel..."
    systemctl stop wstunnel
    systemctl disable wstunnel
    
    log_info "Удаляем файлы конфигурации WSTunnel..."
    rm -f /etc/systemd/system/wstunnel.service
    rm -f /usr/local/bin/wstunnel
    rm -f /etc/wireguard/wstunnel-secret.txt
    
    log_success "WSTunnel успешно удален"
else
    log_info "WSTunnel не установлен, пропускаем"
fi

# Удаление WGDashboard
log_section "Удаление WGDashboard"
if system_service_exists "wgdashboard"; then
    log_info "Останавливаем службы WGDashboard..."
    systemctl stop wgdashboard
    systemctl disable wgdashboard
    
    if system_service_exists "wgdashboard-daemon"; then
        systemctl stop wgdashboard-daemon
        systemctl disable wgdashboard-daemon
    fi
    
    log_info "Удаляем файлы конфигурации WGDashboard..."
    rm -f /etc/systemd/system/wgdashboard.service
    rm -f /etc/systemd/system/wgdashboard-daemon.service
    
    log_info "Удаляем директорию WGDashboard..."
    rm -rf /opt/wgdashboard
    
    log_success "WGDashboard успешно удален"
else
    log_info "WGDashboard не установлен, пропускаем"
fi

# Удаление WireGuard
log_section "Удаление WireGuard"

# Останавливаем все интерфейсы WireGuard
log_info "Останавливаем все интерфейсы WireGuard..."
wg_interfaces=$(ip link show type wireguard 2>/dev/null | grep -o 'wg[0-9]*')
if [[ -n "$wg_interfaces" ]]; then
    for iface in $wg_interfaces; do
        log_info "Отключаем интерфейс $iface..."
        wg-quick down "$iface" 2>/dev/null || true
    done
fi

# Удаляем пакет WireGuard в зависимости от дистрибутива
if command -v apt-get &> /dev/null; then
    log_info "Удаляем пакеты WireGuard с помощью apt..."
    apt-get purge -y wireguard wireguard-tools wireguard-dkms 2>/dev/null || true
    apt-get autoremove -y 2>/dev/null || true
elif command -v yum &> /dev/null; then
    log_info "Удаляем пакеты WireGuard с помощью yum..."
    yum remove -y wireguard-tools 2>/dev/null || true
    yum autoremove -y 2>/dev/null || true
fi

# Удаляем конфигурационные файлы WireGuard
log_info "Удаляем конфигурационные файлы WireGuard..."
rm -rf /etc/wireguard/*

log_success "WireGuard успешно удален"

# Восстановление правил файрвола
log_section "Восстановление правил файрвола"

log_info "Удаляем правила файрвола для WireGuard..."
if command -v ufw &> /dev/null && ufw status | grep -q "active"; then
    ufw delete allow "$WG_PORT/udp" 2>/dev/null || true
    ufw delete allow "$WGDASHBOARD_PORT/tcp" 2>/dev/null || true
    ufw delete allow "$WSTUNNEL_PORT/tcp" 2>/dev/null || true
elif command -v firewall-cmd &> /dev/null && firewall-cmd --state | grep -q "running"; then
    firewall-cmd --permanent --remove-port="$WG_PORT/udp" 2>/dev/null || true
    firewall-cmd --permanent --remove-port="$WGDASHBOARD_PORT/tcp" 2>/dev/null || true
    firewall-cmd --permanent --remove-port="$WSTUNNEL_PORT/tcp" 2>/dev/null || true
    firewall-cmd --reload 2>/dev/null || true
fi

# Отключение перенаправления IP
log_info "Отключаем перенаправление IP..."
echo 0 > /proc/sys/net/ipv4/ip_forward 2>/dev/null || true
sed -i '/net.ipv4.ip_forward=1/d' /etc/sysctl.conf 2>/dev/null || true
sysctl -p 2>/dev/null || true

log_success "Правила файрвола и системные настройки восстановлены"

# Перезагружаем systemd для применения всех изменений
systemctl daemon-reload

# Финальное сообщение
log_section "Удаление завершено"
log_success "VPN-сервер WireGuard полностью удален из системы"
log_info "Резервная копия конфигураций сохранена в $BACKUP_DIR"
log_info "Если вы хотите удалить резервную копию, выполните: rm -rf $BACKUP_DIR"

exit 0 