# 🚀 Keenetic DNS + DPI Bypass Automation

Полная автоматизация настройки **dnsmasq** (DNS сервер с блокировкой рекламы) и **nfqws** (обход DPI блокировок) на роутерах Keenetic с Entware.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Keenetic](https://img.shields.io/badge/Keenetic-Entware-orange)](https://keenetic.com/)
[![Shell Script](https://img.shields.io/badge/Shell-Script-green.svg)](https://www.gnu.org/software/bash/)

---

## 📋 Содержание

- [Возможности](#-возможности)
- [Требования](#-требования)
- [Быстрая установка](#-быстрая-установка)
- [Компоненты](#-компоненты)
- [Управление](#-управление)
- [Настройка](#-настройка)
- [Примеры использования](#-примеры-использования)
- [Решение проблем](#-решение-проблем)
- [FAQ](#-faq)
- [Полезные ссылки](#-полезные-ссылки)

---

## ✨ Возможности

### 🛡️ dnsmasq - DNS уровень защиты

- ✅ **Блокировка рекламы** на уровне DNS
- ✅ **Custom hosts** для перенаправления доменов
- ✅ **Автообновление** списков блокировки
- ✅ **Отдельный IP** (192.168.1.2:53) для DNS сервера
- ✅ **Кеширование** DNS запросов для ускорения
- ✅ **Логирование** всех DNS запросов

### 🔓 nfqws - DPI bypass

- ✅ **Обход блокировок** YouTube, Discord, Instagram
- ✅ **Модификация TCP/UDP** пакетов
- ✅ **Обработка QUIC** протокола
- ✅ **Веб-интерфейс** для управления
- ✅ **Гибкие стратегии** обхода DPI
- ✅ **Автозапуск** при перезагрузке

### 🔗 Интеграция

- 🔗 **Автосинхронизация** списков доменов
- 🔗 **Единое управление** через hosts файлы
- 🔗 **Совместная работа** DNS + DPI уровней
- 🔗 **Dashboard** для мониторинга

---

## 📦 Требования

### Обязательно

- ✅ Роутер **Keenetic** (любая модель с USB портом)
- ✅ **USB накопитель** (флешка или HDD, минимум 512 МБ)
- ✅ **Entware** установлен на USB
- ✅ Компонент **"Система OPKG"** в Keenetic

### Для nfqws дополнительно

- ✅ Компонент **"Протокол IPv6"**
- ✅ Компонент **"Модули ядра Netfilter"**

### Как установить компоненты Keenetic

1. Откройте веб-интерфейс: `http://192.168.1.1`
2. **Управление** → **Общие настройки** → **Изменить набор компонентов**
3. Включите:
   - ✅ **Система OPKG** (в разделе "Система")
   - ✅ **Протокол IPv6** (в разделе "Сетевые функции")
   - ✅ **Модули ядра Netfilter** (в разделе "OPKG")
4. Подключите **USB накопитель**
5. Дождитесь установки Entware (5-10 минут)

---

## 🚀 Быстрая установка

### Способ 1: Одна команда (рекомендуется)

```bash
curl -fsSL https://raw.githubusercontent.com/ldeprive3-spec/keenetic-hosts-automation/main/install.sh | sh
или через wget:

bash
wget -qO- https://raw.githubusercontent.com/ldeprive3-spec/keenetic-hosts-automation/main/install.sh | sh
Способ 2: Ручная установка
bash
# Подключитесь к роутеру по SSH
ssh root@192.168.1.1

# Скачайте установщик
curl -fsSL https://raw.githubusercontent.com/ldeprive3-spec/keenetic-hosts-automation/main/install.sh -o /tmp/install.sh

# Запустите
sh /tmp/install.sh
Процесс установки
После запуска скрипт предложит выбрать режим:

text
Выберите режим установки:
  1) Только dnsmasq (DNS сервер + hosts)
  2) Только nfqws (DPI bypass для YouTube/Discord)
  3) Оба (РЕКОМЕНДУЕТСЯ - полная защита)

Ваш выбор [1-3]: 3
Рекомендуется выбрать режим 3 для полной защиты.

📦 Компоненты
1️⃣ dnsmasq
DNS сервер с блокировкой рекламы

Слушает на: 192.168.1.2:53

Upstream DNS: 8.8.8.8, 8.8.4.4, 1.1.1.1

Кеш: 1000 записей

Автообновление: ежедневно в 3:00

Что блокирует:

Рекламные сети (AdSense, DoubleClick)

Трекеры (Google Analytics, Яндекс.Метрика)

Вредоносные сайты

Пользовательские домены (custom.conf)

2️⃣ nfqws-keenetic
DPI bypass для обхода блокировок

Технология: модификация TCP/UDP пакетов

Протоколы: HTTP, HTTPS, QUIC

Стратегии: split, disorder, fake, multisplit

Очередь: NFQUEUE 200

Что разблокирует:

YouTube (в том числе с замедлением)

Discord

Instagram

Twitter/X

И другие заблокированные сервисы

3️⃣ Интеграция
Синхронизация между компонентами

Домены из dnsmasq → автоматически в nfqws

Автосинхронизация: ежедневно в 3:10

Ручная синхронизация: /opt/etc/sync-dns-dpi.sh

📊 Управление
dnsmasq команды
bash
# Показать статус и статистику
dns-status

# Перезапустить DNS сервер
/opt/etc/init.d/S56dnsmasq restart

# Остановить
/opt/etc/init.d/S56dnsmasq stop

# Запустить
/opt/etc/init.d/S56dnsmasq start

# Обновить hosts списки
/opt/etc/update-hosts-auto.sh

# Мониторинг логов в реальном времени
tail -f /opt/var/log/dnsmasq.log

# Поиск в логах
grep "youtube.com" /opt/var/log/dnsmasq.log

# Очистить лог
echo "" > /opt/var/log/dnsmasq.log
nfqws команды
bash
# Статус
/opt/etc/init.d/S51nfqws status

# Перезапустить
/opt/etc/init.d/S51nfqws restart

# Остановить
/opt/etc/init.d/S51nfqws stop

# Запустить
/opt/etc/init.d/S51nfqws start

# Веб-интерфейс (если установлен)
# http://192.168.1.1:90

# Подбор оптимальной стратегии
/bin/sh -c "$(curl -fsSL https://github.com/Anonym-tsk/nfqws-keenetic/raw/master/common/strategy.sh)"

# Просмотр правил iptables
iptables-save | grep nfqws

# Лог nfqws
cat /opt/var/log/nfqws.log
Синхронизация
bash
# Ручная синхронизация dnsmasq ↔ nfqws
/opt/etc/sync-dns-dpi.sh

# Просмотр лога синхронизации
cat /opt/var/log/sync-dns-dpi.log
🔧 Настройка
Настройка DNS в Keenetic
После установки dnsmasq настройте роутер:

Откройте: http://192.168.1.1

Интернет → Подключения → Выберите ваше подключение

Параметры IP → DNS-серверы → Настроить вручную

Укажите:

DNS 1: 192.168.1.2

DNS 2: 8.8.8.8 (резервный)

Сохраните

Проверка на клиенте:

bash
nslookup google.com 192.168.1.1
Добавление custom hosts
Редактируйте файл:

bash
nano /opt/etc/dnsmasq.d/custom.conf
Формат:

text
# Блокировка домена (вернет 0.0.0.0)
address=/ads.example.com/0.0.0.0

# Перенаправление на другой IP
address=/youtube.com/157.240.245.174
address=/discord.com/8.8.8.8

# Перенаправление поддомена
address=/cdn.example.com/192.168.1.100
Применить изменения:

bash
/opt/etc/init.d/S56dnsmasq restart
/opt/etc/sync-dns-dpi.sh  # Если установлен nfqws
Настройка nfqws
Базовая конфигурация
bash
nano /opt/etc/nfqws/nfqws.conf
Пример конфига:

text
# Основные параметры
ENABLED=yes
MODE=nfqws

# Стратегии
NFQWS_OPT_DESYNC="--dpi-desync=split2 --dpi-desync-split-pos=2"
NFQWS_OPT_DESYNC_HTTP="--dpi-desync=disorder2 --dpi-desync-disorder=1"
NFQWS_OPT_DESYNC_HTTPS="--dpi-desync=split --dpi-desync-split-pos=1"
NFQWS_OPT_DESYNC_QUIC="--dpi-desync=fake --dpi-desync-fake-quic=/opt/etc/nfqws/fake/quic_iphone_15.bin"

# Порты
NFQUEUE_NUM=200
Добавление доменов для обхода
bash
nano /opt/etc/nfqws/user.list
Формат (один домен на строку):

text
youtube.com
googlevideo.com
ytimg.com
discord.com
discordapp.com
instagram.com
Применить:

bash
/opt/etc/init.d/S51nfqws restart
Источники hosts для dnsmasq
Редактируйте скрипт обновления:

bash
nano /opt/etc/update-hosts-auto.sh
Раскомментируйте нужные источники:

bash
# StevenBlack - комплексная блокировка (включен по умолчанию)
STEVENBLACK_URL="https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"

# AdAway - блокировка рекламы
# ADAWAY_URL="https://adaway.org/hosts.txt"

# AdGuard DNS filter
# ADGUARD_URL="https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt"
Ручной запуск обновления:

bash
/opt/etc/update-hosts-auto.sh
💡 Примеры использования
Пример 1: Блокировка рекламы
bash
# Добавьте в custom.conf
echo "address=/ads.google.com/0.0.0.0" >> /opt/etc/dnsmasq.d/custom.conf
echo "address=/doubleclick.net/0.0.0.0" >> /opt/etc/dnsmasq.d/custom.conf

# Перезапустите
/opt/etc/init.d/S56dnsmasq restart

# Проверьте
dig @192.168.1.2 ads.google.com
Пример 2: Разблокировка YouTube
bash
# Добавьте домены в nfqws
cat >> /opt/etc/nfqws/user.list << EOF
youtube.com
googlevideo.com
ytimg.com
yt3.ggpht.com
EOF

# Перезапустите
/opt/etc/init.d/S51nfqws restart

# Проверьте (откройте YouTube на устройстве)
Пример 3: Локальный домен
bash
# Создайте локальный домен для устройства в сети
echo "address=/myserver.local/192.168.1.100" >> /opt/etc/dnsmasq.d/custom.conf

# Перезапустите
/opt/etc/init.d/S56dnsmasq restart

# Проверьте
ping myserver.local
Пример 4: Родительский контроль
bash
# Блокировка соцсетей для детей
cat >> /opt/etc/dnsmasq.d/custom.conf << EOF
address=/facebook.com/0.0.0.0
address=/instagram.com/0.0.0.0
address=/tiktok.com/0.0.0.0
address=/vk.com/0.0.0.0
EOF

# Применить
/opt/etc/init.d/S56dnsmasq restart
🐛 Решение проблем
dnsmasq не запускается
Проблема: failed to create listening socket for port 53

Решение:

bash
# Проверьте занят ли порт 53
netstat -ln | grep :53

# Если занят системным DNS (ndnproxy) - это нормально
# dnsmasq использует отдельный IP 192.168.1.2

# Проверьте алиас
ifconfig br0:1

# Если алиаса нет, создайте:
/opt/etc/init.d/S55network-alias start
nfqws не работает
Проблема: YouTube/Discord всё ещё заблокирован

Решение:

Проверьте компоненты Keenetic:

bash
# IPv6 должен быть включен
ip -6 addr show

# Netfilter модули должны быть загружены
lsmod | grep nf
Проверьте правила iptables:

bash
iptables-save | grep "queue-num 200"

# Должно быть примерно так:
# -A POSTROUTING -j nfqws_mark
# -A POSTROUTING -m mark --mark 0x40000000/0x40000000 -j NFQUEUE --queue-num 200
Подберите стратегию:

bash
/bin/sh -c "$(curl -fsSL https://github.com/Anonym-tsk/nfqws-keenetic/raw/master/common/strategy.sh)"
DNS не разрешается
Проблема: сайты не открываются

Решение:

bash
# Проверьте dnsmasq
ps | grep dnsmasq

# Если не запущен
/opt/etc/init.d/S56dnsmasq start

# Проверьте порт
netstat -ln | grep "192.168.1.2:53"

# Тест DNS
dig @192.168.1.2 google.com

# Если не работает, проверьте конфиг
dnsmasq --test --conf-file=/opt/etc/dnsmasq.conf
Медленный интернет
Проблема: интернет стал медленнее после установки

Решение:

Отключите логирование dnsmasq:

bash
nano /opt/etc/dnsmasq.conf
# Закомментируйте строку:
# log-queries

/opt/etc/init.d/S56dnsmasq restart
Оптимизируйте nfqws:

bash
nano /opt/etc/nfqws/nfqws.conf
# Используйте более легкие стратегии
NFQWS_OPT_DESYNC="--dpi-desync=split2"
Автозапуск не работает
Проблема: после перезагрузки сервисы не стартуют

Решение:

bash
# Проверьте init скрипты
ls -lh /opt/etc/init.d/S55network-alias
ls -lh /opt/etc/init.d/S56dnsmasq
ls -lh /opt/etc/init.d/S51nfqws

# Должны быть исполняемыми (rwx)
chmod +x /opt/etc/init.d/S55network-alias
chmod +x /opt/etc/init.d/S56dnsmasq
chmod +x /opt/etc/init.d/S51nfqws

# Проверьте Entware autorun
cat /opt/etc/init.d/rc.unslung
🙋 FAQ
Вопрос: Будет ли работать на старых моделях Keenetic?
Ответ: Да, если есть USB порт и поддержка Entware. Минимальная модель: Keenetic Start (KN-1110).

Вопрос: Сколько места нужно на USB?
Ответ: Минимум 512 МБ, рекомендуется 2 ГБ для логов и бэкапов.

Вопрос: Можно ли использовать без USB?
Ответ: Нет, Entware требует USB накопитель. Альтернатива - установка на внутреннюю память (не рекомендуется).

Вопрос: Влияет ли на скорость интернета?
Ответ: Минимально. dnsmasq кеширует DNS (ускоряет), nfqws добавляет ~1-5 мс задержки.

Вопрос: Можно ли использовать с VPN?
Ответ: Да, совместимо с OpenVPN, WireGuard, IPSec.

Вопрос: Как удалить?
Ответ:

bash
# Удаление dnsmasq
opkg remove dnsmasq
rm -rf /opt/etc/dnsmasq.conf /opt/etc/dnsmasq.d

# Удаление nfqws
opkg remove nfqws-keenetic nfqws-keenetic-web
rm -rf /opt/etc/nfqws

# Удаление скриптов
rm -f /opt/etc/init.d/S55network-alias
rm -f /opt/etc/init.d/S56dnsmasq
rm -f /opt/etc/update-hosts-auto.sh
rm -f /opt/bin/dns-status

# Перезагрузите роутер
reboot
Вопрос: Работает ли с AdGuard Home?
Ответ: Конфликтует (оба используют порт 53). Нужно выбрать один: либо AdGuard Home, либо dnsmasq.

📁 Структура файлов
text
/opt/
├── bin/
│   └── dns-status              # Dashboard для мониторинга
├── etc/
│   ├── dnsmasq.conf            # Основной конфиг dnsmasq
│   ├── dnsmasq.d/
│   │   ├── custom.conf         # Пользовательские hosts
│   │   └── auto-blocked.conf   # Авто-генерируемые блокировки
│   ├── nfqws/
│   │   ├── nfqws.conf          # Конфиг nfqws
│   │   └── user.list           # Список доменов для DPI bypass
│   ├── init.d/
│   │   ├── S55network-alias    # Init скрипт IP алиаса
│   │   ├── S56dnsmasq          # Init скрипт dnsmasq
│   │   └── S51nfqws            # Init скрипт nfqws
│   ├── cron.d/
│   │   ├── update-hosts        # Cron для обновления hosts
│   │   └── sync-dns-dpi        # Cron для синхронизации
│   ├── update-hosts-auto.sh    # Скрипт обновления hosts
│   └── sync-dns-dpi.sh         # Скрипт синхронизации
└── var/
    ├── log/
    │   ├── dnsmasq.log         # Лог DNS запросов
    │   ├── nfqws.log           # Лог nfqws
    │   ├── hosts-updater.log   # Лог обновлений
    │   └── sync-dns-dpi.log    # Лог синхронизации
    └── backups/
        └── hosts/              # Бэкапы hosts файлов
🔗 Полезные ссылки
Документация
Официальный сайт Keenetic

Entware Wiki

dnsmasq Documentation

nfqws-keenetic GitHub

zapret GitHub

Форумы и сообщества
Форум Keenetic

4PDA - Keenetic

Telegram канал Keenetic

Hosts списки
StevenBlack/hosts

AdAway

AdGuard DNS filter

🤝 Участие в разработке
Pull requests приветствуются!

Как внести вклад
Fork репозиторий

Создайте ветку: git checkout -b feature/amazing-feature

Commit изменения: git commit -m 'Add amazing feature'

Push в ветку: git push origin feature/amazing-feature

Откройте Pull Request

Сообщить об ошибке
Откройте Issue с описанием:

Модель роутера

Версия прошивки Keenetic

Логи: /opt/var/log/dnsmasq.log, /opt/var/log/nfqws.log

Шаги для воспроизведения

📄 Лицензия
MIT License

Copyright (c) 2026 ldeprive3-spec

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

💖 Благодарности
Anonym-tsk за nfqws-keenetic

bol-van за zapret

StevenBlack за unified hosts

Сообщество Keenetic за поддержку

📞 Контакты
GitHub Issues: Задать вопрос

Telegram: @your_telegram (опционально)

<div align="center">
⭐ Если проект помог - поставьте звезду! ⭐

Made with ❤️ for Keenetic community
