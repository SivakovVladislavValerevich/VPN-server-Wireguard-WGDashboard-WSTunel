# VPN-сервер на базе WireGuard с WGDashboard и WSTunnel

Автоматизированные скрипты для быстрого развертывания защищенного VPN-сервера на базе WireGuard с веб-интерфейсом WGDashboard и возможностью обфускации трафика через WSTunnel.

## Возможности

- **Быстрая установка**: полностью автоматизированная установка всех компонентов
- **Веб-интерфейс**: управление клиентами через удобный веб-интерфейс WGDashboard
- **Обфускация трафика**: возможность обхода блокировок с помощью WSTunnel (опционально)
- **Гибкая настройка**: полностью настраиваемая конфигурация
- **Безопасность**: современная криптография WireGuard, автоматическая настройка файрвола
- **Резервное копирование**: управление резервными копиями конфигурации
- **Детальное логирование**: мониторинг всех аспектов работы системы

## Предварительные требования

Для установки требуется:

- Linux-сервер (Ubuntu 20.04+, Debian 10+, CentOS 8+)
- Права суперпользователя (root)
- Доступ к интернету на сервере для скачивания пакетов

## Обновление системы

Перед установкой любых компонентов рекомендуется обновить систему до последних версий:

```bash
apt-get update -y && apt-get full-upgrade -y && apt install sudo git curl -y && reboot
```

## Быстрое начало работы

1. Клонировать репозиторий:

Для клонирования данного репозитория после открытия репозитория используйте следующую команду:
```bash
git clone https://github.com/SivakovVladislavValerevich/VPN-server-Wireguard-WGDashboard-WSTunel.git
cd VPN-server-Wireguard-WGDashboard-WSTunel
```


2. (Опционально) Настроить конфигурацию установки:

```bash
nano config.conf
```

3. Выдать права на исполнение:

```bash
chmod +x ./scripts/install.sh ./scripts/uninstall.sh ./scripts/reinstall.sh
```

4. Запустить скрипт установки:

```bash
sudo ./scripts/install.sh
```

5. Следовать инструкциям установщика

После завершения установки веб-интерфейс WGDashboard будет доступен по адресу `http://<IP-сервера>:10086`.

## Структура проекта

```
.
├── config.conf                    # Главный конфигурационный файл
├── manual/                        # Директория с руководствами пользователя
│   └── wstunnel_user_guide.md    # Руководство по использованию WSTunnel
├── scripts/                       # Директория с основными скриптами
│   ├── install.sh                # Основной скрипт установки
│   ├── uninstall.sh             # Удаление VPN-сервера
│   ├── backup.sh                # Управление резервными копиями
│   ├── logs.sh                  # Управление логами
│   ├── reinstall.sh             # Переустановка сервера
│   ├── 00_check_prerequisites.sh # Проверка системных требований
│   ├── 01_prepare_server.sh     # Подготовка сервера
│   ├── 02_change_network_names.sh # Изменение имен сетевых интерфейсов
│   ├── 03_configure_firewall.sh  # Настройка файрвола
│   ├── 04_install_wireguard.sh  # Установка WireGuard
│   ├── 05_install_wgdashboard.sh # Установка WGDashboard
│   ├── 06_install_wstunnel.sh   # Установка WSTunnel
│   └── utils/                    # Вспомогательные утилиты
│       ├── backup_utils.sh      # Утилиты резервного копирования
│       ├── detect_network.sh    # Утилиты определения сетевых параметров
│       ├── log_utils.sh         # Утилиты логирования
│       └── system_utils.sh      # Системные утилиты
├── README.md                     # Основная документация
├── README_Manual_Install.md      # Руководство по ручной установке
└── README_File_Structure_After_Project_Installation.md    # Документация по структуре файлов после установки
```

## Структура файлов после установки проекта

```
.
├── config.conf                    # Файл конфигурации с настройками по умолчанию
├── manual/                        # Директория с руководствами пользователя
│   └── wstunnel_user_guide.md    # Руководство по использованию WSTunnel
├── manual_Install/                # Директория с руководствами по ручной установке
│   ├── 0README_Preparing_the_server_for_installation_and_configuration.md
│   ├── 1README_Change_Default_Network_Name_(ens33_ens3_ens18)_to_eth0.md
│   ├── 2README_Configuring_The_Firewall.md
│   ├── 3README_WireGuard_install.md
│   ├── 4README_WGDashboard_Install.md
│   └── 5README_WSTunel_Obfuscation.md
├── logs/                         # Директория для логов
│   ├── install_log.txt          # Детальный лог процесса установки
│   ├── uninstall_log.txt        # Детальный лог процесса удаления
│   ├── operations_log.txt       # Лог общих операций и текущей работы скриптов
│   └── reinstall_log.txt        # Детальный лог процесса переустановки
├── backups/                      # Директория для бэкапов
│   ├── logs/                    # Архивы логов (после ротации)
│   ├── configs/                 # Бэкапы конфигурационных файлов
│   └── templates/               # Шаблоны оригинальных конфигурационных файлов
├── scripts/                      # Директория с основными скриптами
│   ├── install.sh              # Основной скрипт установки
│   ├── uninstall.sh           # Скрипт удаления инфраструктуры
│   ├── backup.sh              # Управление резервными копиями
│   ├── logs.sh               # Управление логами
│   ├── reinstall.sh          # Скрипт переустановки инфраструктуры
│   ├── 00_check_prerequisites.sh    # Проверка предварительных требований
│   ├── 01_prepare_server.sh         # Подготовка сервера (обновление, пакеты)
│   ├── 02_change_network_names.sh   # Изменение имен сетевых интерфейсов (опционально)
│   ├── 03_configure_firewall.sh     # Настройка файрвола iptables
│   ├── 04_install_wireguard.sh      # Установка и настройка WireGuard
│   ├── 05_install_wgdashboard.sh    # Установка и настройка WGDashboard
│   ├── 06_install_wstunnel.sh       # Установка и настройка Wstunnel (опционально)
│   ├── 07_backup_management.sh      # Настройка системы бэкапов
│   ├── 08_log_management.sh         # Настройка системы управления логами
│   └── utils/                       # Вспомогательные утилиты
│       ├── backup_utils.sh         # Функции для создания и управления бэкапами
│       ├── detect_network.sh       # Определение сетевых параметров (IP сервера, шлюз)
│       ├── log_utils.sh           # Функции для стандартизированного логирования
│       └── system_utils.sh        # Общие системные утилиты
├── README.md                      # Основная документация проекта
├── README_Manual_Install.md       # Руководство по ручной установке
└── README_File_Structure_After_Project_Installation.md     # Документация по структуре файлов после установки
```

## Файлы и директории после установки
```
.
/etc/
├── wireguard/                    # Основная директория WireGuard
│   ├── wg0.conf                 # Основной конфиг WireGuard
│   ├── privatekey              # Приватный ключ сервера
│   ├── publickey               # Публичный ключ сервера
│   └── wstunnel_secret        # Секретный ключ WSTunnel (если установлен)
├── systemd/system/              # Файлы служб systemd
│   ├── wg-quick@wg0.service    # Служба WireGuard
│   ├── wg-dashboard.service    # Служба WGDashboard (если установлен)
│   └── wstunnel.service        # Служба WSTunnel (если установлен)
├── iptables/                    # Конфигурация файрвола
│   └── rules.v4                # Правила iptables
└── cron.d/                      # Задания cron
    ├── vpn-backup              # Задание для резервного копирования
    └── vpn-logs                # Задание для ротации логов

/root/
├── WGDashboard/                 # Директория WGDashboard (если установлен)
│   └── src/                    # Исходный код и конфигурация WGDashboard
├── wstunnel_client_info.txt    # Информация для подключения WSTunnel
└── .wg-dashboard/              # Конфигурация WGDashboard
    └── db/                     # База данных WGDashboard

/usr/local/
├── bin/
│   └── wstunnel                # Исполняемый файл WSTunnel (если установлен)
└── lib/
    └── systemd/system/         # Дополнительные службы systemd

/var/log/
└── vpn/                        # Системные логи VPN-сервера
    ├── wireguard.log          # Логи WireGuard
    ├── wgdashboard.log        # Логи WGDashboard
    └── wstunnel.log           # Логи WSTunnel
```

## Основные команды

### Установка

```bash
sudo ./scripts/install.sh
```

### Удаление

```bash
sudo ./scripts/uninstall.sh
```

### Управление резервными копиями

```bash
sudo ./scripts/backup.sh create
```
> Создание резервной копии

```bash
sudo ./scripts/backup.sh list
```
> Просмотр списка резервных копий

```bash
sudo ./scripts/backup.sh restore <ID>
```
> Восстановление резервной копии

```bash
sudo ./scripts/backup.sh delete <ID>
```
> Удаление резервной копии

```bash
sudo ./scripts/backup.sh cleanup
```
> Автоматическая очистка старых копий

### Управление логами

```bash
sudo ./scripts/logs.sh view wireguard
```
> Просмотр логов WireGuard

```bash
sudo ./scripts/logs.sh tail wgdashboard
```
> Просмотр логов в реальном времени

```bash
sudo ./scripts/logs.sh clean all
```
> Очистка всех логов

```bash
sudo ./scripts/logs.sh rotate
```
> Ротация логов

### Переустановка

```bash
sudo ./scripts/reinstall.sh
```

## Настройка конфигурации

Основной файл конфигурации `config.conf` содержит настройки для всех компонентов системы. Вы можете настроить:

- Порты для WireGuard, WGDashboard и WSTunnel
- Настройки внутренней сети VPN
- Параметры логирования и резервного копирования
- Опциональные компоненты для установки
- Настройки файрвола
- Учетные данные для веб-интерфейса

## Добавление клиентов

1. Откройте веб-интерфейс WGDashboard в браузере: `http://<IP-сервера>:10086`
2. Войдите, используя логин `admin` и пароль, указанный при установке
3. Перейдите в раздел "Клиенты" и нажмите "Добавить клиента"
4. Заполните необходимые данные и сгенерируйте конфигурацию
5. Скачайте сгенерированный QR-код или конфигурационный файл для использования на клиентских устройствах

## Использование WSTunnel (обфускация трафика)

Если при установке был выбран компонент WSTunnel, клиентам необходимо использовать дополнительные настройки для обфускации трафика. Инструкции для подключения клиентов через WSTunnel будут выведены после завершения установки.

## Устранение проблем

### Распространенные проблемы:

1. **Не работает подключение к VPN**:
   - Проверьте статус сервера: `sudo wg show`
   - Проверьте логи: `sudo ./scripts/logs.sh view wireguard`
   - Проверьте статус файрвола: `sudo ufw status` или `sudo firewall-cmd --list-all`

2. **Не удается войти в WGDashboard**:
   - Проверьте, запущен ли сервис: `sudo systemctl status wgdashboard`
   - Проверьте логи: `sudo ./scripts/logs.sh view wgdashboard`

3. **Проблемы с WSTunnel**:
   - Проверьте статус сервиса: `sudo systemctl status wstunnel`
   - Проверьте логи: `sudo ./scripts/logs.sh view wstunnel`

### Восстановление после сбоя:

В случае серьезных проблем можно восстановить систему из резервной копии:

```bash
sudo ./scripts/backup.sh list
```
> Просмотр доступных копий

```bash
sudo ./scripts/backup.sh restore <ID>
```
> Восстановление из копии

## Безопасность

- Регулярно выполняйте обновления системы
- Создавайте резервные копии конфигурации
- Меняйте пароль WGDashboard периодически
- Не используйте стандартные порты для сервисов
- Ограничивайте доступ к серверу только необходимыми IP-адресами

## Дополнительные ресурсы

- [Официальная документация WireGuard](https://www.wireguard.com/quickstart/)
- [Документация WGDashboard](https://github.com/donaldzou/WGDashboard)
- [Документация WSTunnel](https://github.com/erebe/wstunnel)

## Проект поддерживает возможность ручной установки и настройки со специально подготовленными руководствами и пояснениями

> [**Руководство по ручной настройке безопасного VPN-сервера на базе WireGuard с веб-интерфейсом управления WGDashboard и возможностью обфускации трафика для обхода блокировок при помощи WSTunel**](README_Manual_Install.md)

> [**Подробная документация по структуре файлов и директорий после установки проекта**](README_File_Structure_After_Project_Installation.md)

## Лицензия
---