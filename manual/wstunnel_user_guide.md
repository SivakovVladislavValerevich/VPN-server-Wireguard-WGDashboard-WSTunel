# Руководство по использованию WSTunnel для обхода блокировок

## Важно!
Все необходимые данные для подключения (IP-адрес сервера, порт и секретный ключ) находятся в файле:
```bash
nano /root/wstunnel_client_info.txt
```

## Содержание
1. [Общая информация](#общая-информация)
2. [Настройка на Android](#настройка-на-android)
3. [Настройка на Windows](#настройка-на-windows)
4. [Настройка на Linux](#настройка-на-linux)
5. [Устранение проблем](#устранение-проблем)

## Общая информация
WSTunnel используется для маскировки VPN-трафика под обычный веб-трафик, что помогает обойти блокировки. Трафик WireGuard оборачивается в WebSocket соединение, которое выглядит как обычный HTTPS-трафик.

## Настройка на Android

### Через Termux
1. Установите Termux из Google Play или F-Droid
2. Выполните команды:
```bash
apt update && apt upgrade -y
apt install wget -y
curl -fLo wstunnel.tar.gz https://github.com/erebe/wstunnel/releases/download/v10.1.9/wstunnel_10.1.9_android_arm64.tar.gz
tar -xzf wstunnel.tar.gz wstunnel
chmod 777 wstunnel
```

3. Создайте скрипт запуска (данные возьмите из `/root/wstunnel_client_info.txt`):
```bash
echo './wstunnel client --http-upgrade-path-prefix "ваш_секретный_ключ" -L "udp://20820:localhost:20820?timeout_sec=0" wss://ваш_ip:443' > tunnel
```

4. Запустите:
```bash
sh tunnel
```

5. В приложении WireGuard:
   - Измените Endpoint на `127.0.0.1:20820`
   - Включите VPN

### Через TermOne Plus
Процесс аналогичен Termux, но можно настроить автозапуск через Preferences → Shell → Initial command

## Настройка на Windows

1. Скачайте WSTunnel:
```powershell
mkdir ~\wstunnel
cd ~\wstunnel
curl.exe -fLo wstunnel.tar.gz https://github.com/erebe/wstunnel/releases/download/v10.1.9/wstunnel_10.1.9_windows_amd64.tar.gz
tar -xzf wstunnel.tar.gz wstunnel.exe
```

2. Добавьте путь в PATH:
   - Win+R → sysdm.cpl → Дополнительно → Переменные среды
   - В Path добавьте путь к папке wstunnel

3. Разрешите скрипты WireGuard:
```powershell
reg add HKLM\Software\WireGuard /v DangerousScriptExecution /t REG_DWORD /d 1 /f
```

4. В конфигурации WireGuard добавьте (данные из `/root/wstunnel_client_info.txt`):
```ini
[Interface]
PostUp = route add ваш_ip mask 255.255.255.255 192.168.1.1 && start "" wstunnel client --http-upgrade-path-prefix "ваш_секретный_ключ" -L "udp://20820:localhost:20820?timeout_sec=0" wss://ваш_ip:443
PostDown = route delete ваш_ip mask 255.255.255.255 192.168.1.1 && powershell -command "(Get-Process -Name wstunnel).Kill()"

[Peer]
Endpoint = 127.0.0.1:20820
```

## Настройка на Linux

1. Установите WSTunnel:
```bash
curl -fLo wstunnel.tar.gz https://github.com/erebe/wstunnel/releases/download/v10.1.9/wstunnel_10.1.9_linux_amd64.tar.gz
tar -xzf wstunnel.tar.gz wstunnel
sudo mv wstunnel /usr/local/bin/
chmod +x /usr/local/bin/wstunnel
```

2. Отредактируйте конфигурацию WireGuard (данные из `/root/wstunnel_client_info.txt`):
```bash
sudo nano /etc/wireguard/wg0.conf
```

Добавьте:
```ini
[Interface]
PostUp = ip route add ваш_ip/32 via 192.168.1.1
PostUp = wstunnel client --http-upgrade-path-prefix "ваш_секретный_ключ" -L "udp://20820:localhost:20820?timeout_sec=0" wss://ваш_ip:443 &> /dev/null &
PostDown = ip route del ваш_ip/32 via 192.168.1.1
PostDown = killall wstunnel

[Peer]
Endpoint = 127.0.0.1:20820
```

3. Перезапустите WireGuard:
```bash
sudo wg-quick down wg0
sudo wg-quick up wg0
```

## Устранение проблем

1. Проверка подключения:
```bash
curl -4 https://ip.hetzner.com
```
Должен показать IP вашего VPN-сервера.

2. Если не работает:
   - Проверьте правильность данных в конфигурации
   - Убедитесь, что WSTunnel запущен
   - Проверьте маршрутизацию
   - Попробуйте запустить WSTunnel с флагом --verbose для отладки 