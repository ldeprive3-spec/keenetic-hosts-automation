# Keenetic Hosts Automation

**Автоматическое обновление hosts → dnsmasq для роутеров Keenetic**

Дополнение к [nfqws-keenetic](https://github.com/Anonym-tsk/nfqws-keenetic) by [@Anonym-tsk](https://github.com/Anonym-tsk).

---

## 🎯 Что это?

Этот проект автоматизирует скачивание и обновление hosts-списков для роутеров Keenetic с конвертацией в формат dnsmasq.

**Работает совместно с nfqws-keenetic:**
- **nfqws-keenetic** → обход DPI блокировок (SNI, ECH, QUIC)
- **hosts-automation** → автоматическое обновление DNS блокировок

## 📋 Требования

- Роутер Keenetic (OS 4.x/5.x) или OpenWRT
- Entware установлен
- 10+ MB свободного места
- SSH доступ к роутеру

## 🚀 Быстрая установка

### Одной командой через ssh -p 222 root@192.168.1.1

```bash
wget -qO- https://raw.githubusercontent.com/ldeprive3-spec/keenetic-hosts-automation/main/install.sh | sh
```

**Что устанавливается:**
1. ✅ **nfqws-keenetic** (если не установлен) - обход DPI
2. ✅ **nfqws-keenetic-web** - веб-интерфейс
3. ✅ **dnsmasq** - DNS сервер
4. ✅ **Скрипт автообновления hosts**
5. ✅ **Cron задача** (ежедневно в 3:00 AM)

---

## 📖 Что происходит после установки

### 1. nfqws-keenetic настроен и работает
- Веб-интерфейс: **http://192.168.1.1:90**
- Обход DPI для YouTube, Discord, Twitch и других
- Автоматическое определение заблокированных доменов

### 2. dnsmasq обрабатывает DNS запросы
- Блокирует рекламу через hosts-списки
- Перенаправляет домены на нужные IP
- Работает для всех устройств в сети

### 3. Автоматическое обновление
- Каждый день в 3:00 скачивает новые списки
- Дедуплицирует домены
- Конвертирует в формат dnsmasq
- Перезапускает DNS сервер

---

## 🔧 Конфигурация

### Источники hosts

Редактируйте `/opt/etc/hosts-automation/sources.list`:

```bash
# Формат: URL|Описание
https://raw.githubusercontent.com/Internet-Helper/GeoHideDNS/refs/heads/main/hosts/hosts|GeoHide DNS
https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/refs/heads/main/.service/hosts|Zapret Discord
```

**Добавление нового источника:**

```bash
echo "https://example.com/hosts.txt|My Custom List" >> /opt/etc/hosts-automation/sources.list
/opt/etc/update-hosts-auto.sh
```

### Настройка nfqws-keenetic

**Через веб-интерфейс (рекомендуется):**
- Откройте http://192.168.1.1:90
- Вкладка **user.list** - добавьте домены вручную
- Вкладка **exclude.list** - исключите банки, госуслуги
- Вкладка **nfqws.conf** - настройте стратегии обхода

**Или вручную через SSH:**

```bash
# Основной конфиг
vi /opt/etc/nfqws/nfqws.conf

# Добавить домены
echo "youtube.com" >> /opt/etc/nfqws/user.list
echo "discord.com" >> /opt/etc/nfqws/user.list

# Исключить домены
echo "sberbank.ru" >> /opt/etc/nfqws/exclude.list
echo "gosuslugi.ru" >> /opt/etc/nfqws/exclude.list

# Перезапустить
/opt/etc/init.d/S51nfqws restart
```

---

## 📊 Управление

### Обновление hosts

```bash
# Вручную обновить сейчас
/opt/etc/update-hosts-auto.sh

# Просмотр логов в реальном времени
tail -f /opt/var/log/hosts-updater.log

# Статистика последнего обновления
cat /opt/var/log/hosts-stats.txt

# Сколько записей в dnsmasq
grep -c "^address=" /opt/etc/dnsmasq.d/custom.conf
```

### Управление nfqws

```bash
# Через веб-интерфейс
http://192.168.1.1:90

# Через SSH
/opt/etc/init.d/S51nfqws restart
/opt/etc/init.d/S51nfqws status

# Логи nfqws
tail -f /opt/var/log/nfqws.log
```

### Тестирование

```bash
# Тест DNS
nslookup youtube.com 127.0.0.1

# Тест обхода (на ПК)
curl -I https://youtube.com
curl -I https://discord.com

# Проверка процессов
ps | grep nfqws
ps | grep dnsmasq

# Проверка iptables
iptables-save | grep "queue-num 200"
```

---

## 🔄 Обновление

```bash
# Обновить nfqws-keenetic
opkg update
opkg upgrade nfqws-keenetic nfqws-keenetic-web

# Обновить hosts сейчас
/opt/etc/update-hosts-auto.sh

# Обновить скрипт hosts-automation
cd /opt/etc
wget -qO update-hosts-auto.sh https://raw.githubusercontent.com/ldeprive3-spec/keenetic-hosts-automation/main/scripts/update-hosts-auto.sh
chmod +x update-hosts-auto.sh
```

---

## 🗑️ Удаление

### Только hosts-automation

```bash
/opt/etc/uninstall-hosts-automation.sh
```

### Полное удаление (с nfqws-keenetic)

```bash
# Удалить всё
opkg remove --autoremove nfqws-keenetic nfqws-keenetic-web
/opt/etc/uninstall-hosts-automation.sh
```

---

## 📝 Файлы и логи

### Конфигурация

| Файл | Описание |
|------|----------|
| `/opt/etc/nfqws/nfqws.conf` | Конфиг nfqws |
| `/opt/etc/nfqws/user.list` | Домены для обхода |
| `/opt/etc/nfqws/exclude.list` | Исключения |
| `/opt/etc/hosts-automation/sources.list` | Источники hosts |
| `/opt/etc/dnsmasq.d/custom.conf` | DNS конфиг |

### Логи

| Файл | Описание |
|------|----------|
| `/opt/var/log/hosts-updater.log` | Логи обновления hosts |
| `/opt/var/log/hosts-stats.txt` | Статистика hosts |
| `/opt/var/log/nfqws.log` | Логи nfqws |

### Скрипты

| Файл | Описание |
|------|----------|
| `/opt/etc/update-hosts-auto.sh` | Обновление hosts |
| `/opt/etc/uninstall-hosts-automation.sh` | Удаление |
| `/opt/etc/init.d/S51nfqws` | Запуск nfqws |
| `/opt/etc/init.d/S56dnsmasq` | Запуск dnsmasq |

---

## ❓ Часто задаваемые вопросы

### Как добавить свои домены в nfqws?

**Через веб-интерфейс:**
1. Откройте http://192.168.1.1:90
2. Вкладка **user.list**
3. Добавьте домены (один на строку)
4. Сохраните

**Через SSH:**
```bash
echo "example.com" >> /opt/etc/nfqws/user.list
/opt/etc/init.d/S51nfqws restart
```

### Как исключить банки и госуслуги?

```bash
cat >> /opt/etc/nfqws/exclude.list << EOF
sberbank.ru
vtb.ru
alfabank.ru
tinkoff.ru
gosuslugi.ru
yandex.ru
EOF

/opt/etc/init.d/S51nfqws restart
```

### Как изменить время автообновления?

```bash
# Редактировать cron
vi /opt/etc/cron.d/update-hosts

# Изменить время (например, на 2:00)
0 2 * * * root /opt/etc/update-hosts-auto.sh >> /opt/var/log/hosts-updater.log 2>&1

# Перезапустить cron
/opt/etc/init.d/S10cron restart
```

### Не работает YouTube/Discord

1. **Проверьте nfqws:**
   ```bash
   ps | grep nfqws
   /opt/etc/init.d/S51nfqws restart
   ```

2. **Проверьте iptables:**
   ```bash
   iptables-save | grep "queue-num 200"
   ```

3. **Откройте веб-интерфейс:**
   - http://192.168.1.1:90
   - Проверьте стратегии обхода

4. **Подберите рабочую стратегию:**
   ```bash
   opkg install curl
   /bin/sh -c "$(curl -fsSL https://github.com/Anonym-tsk/nfqws-keenetic/raw/master/common/strategy.sh)"
   ```

### Hosts не обновляются

```bash
# Проверьте логи
tail -f /opt/var/log/hosts-updater.log

# Запустите вручную
/opt/etc/update-hosts-auto.sh

# Проверьте источники
cat /opt/etc/hosts-automation/sources.list

# Проверьте cron
cat /opt/etc/cron.d/update-hosts
```

---

## 🤝 Связанные проекты

- **[nfqws-keenetic](https://github.com/Anonym-tsk/nfqws-keenetic)** by [@Anonym-tsk](https://github.com/Anonym-tsk) - основной пакет обхода DPI
- **[zapret](https://github.com/bol-van/zapret)** by [@bol-van](https://github.com/bol-van) - оригинальный проект nfqws

---

## 💡 Поддержка

- **Automation Issues:** https://github.com/ldeprive3-spec/keenetic-hosts-automation/issues
- **nfqws-keenetic Issues:** https://github.com/Anonym-tsk/nfqws-keenetic/issues
- **Discussions:** https://github.com/Anonym-tsk/nfqws-keenetic/discussions

---

## 📄 Лицензия

MIT License

---

## 🙏 Благодарности

- **[@Anonym-tsk](https://github.com/Anonym-tsk)** - за отличный nfqws-keenetic пакет
- **[@bol-van](https://github.com/bol-van)** - за zapret/nfqws
- **Сообщество Keenetic** - за тестирование и обратную связь

---

**Сделано с ❤️ для обхода блокировок**
