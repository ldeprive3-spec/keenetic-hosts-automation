#!/bin/sh

# ================================================================
# Keenetic DNS + DPI Bypass Uninstaller
# GitHub: https://github.com/ldeprive3-spec/keenetic-hosts-automation
# Version: 1.1 - Fixed stdin issue
# ================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}╔════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  Keenetic DNS + DPI Bypass Uninstaller        ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════╝${NC}"
echo ""

# ================================================================
# Проверка root
# ================================================================
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}✗ Требуются права root!${NC}"
    exit 1
fi

# ================================================================
# Предупреждение
# ================================================================
echo -e "${YELLOW}⚠ ВНИМАНИЕ!${NC}"
echo ""
echo "Это удалит следующие компоненты:"
echo "  • dnsmasq (DNS сервер)"
echo "  • nfqws-keenetic (DPI bypass)"
echo "  • Все конфигурации"
echo "  • Все логи"
echo "  • Cron задачи"
echo "  • IP алиас 192.168.1.2"
echo ""
echo -e "${YELLOW}Бэкапы будут сохранены в /opt/etc/dnsmasq.d/backups/${NC}"
echo ""

# Проверка переменной окружения CONFIRM
if [ -n "$CONFIRM" ]; then
    if [ "$CONFIRM" = "yes" ] || [ "$CONFIRM" = "YES" ]; then
        echo -e "${GREEN}✓ Подтверждение получено через переменную CONFIRM${NC}"
        echo ""
    else
        echo -e "${GREEN}Удаление отменено (CONFIRM != yes)${NC}"
        exit 0
    fi
else
    # Интерактивный режим
    echo -e "${RED}Продолжить удаление? (yes/no)${NC}"
    
    # Проверяем доступен ли stdin
    if [ -t 0 ]; then
        read -r CONFIRM_INPUT
        if [ "$CONFIRM_INPUT" != "yes" ] && [ "$CONFIRM_INPUT" != "YES" ]; then
            echo ""
            echo -e "${GREEN}Удаление отменено${NC}"
            exit 0
        fi
    else
        echo ""
        echo -e "${YELLOW}⚠ Стандартный ввод недоступен (curl | sh)${NC}"
        echo ""
        echo -e "${BLUE}Для автоматического удаления используйте:${NC}"
        echo "  CONFIRM=yes curl ... | sh"
        echo ""
        echo -e "${BLUE}Или скачайте и запустите локально:${NC}"
        echo "  curl -fsSL URL -o /tmp/uninstall.sh"
        echo "  sh /tmp/uninstall.sh"
        echo ""
        echo -e "${GREEN}Удаление отменено${NC}"
        exit 0
    fi
fi

echo ""
echo -e "${BLUE}Начинаем удаление...${NC}"
echo ""

# ================================================================
# Удаление dnsmasq
# ================================================================
echo -e "${YELLOW}► Удаление dnsmasq...${NC}"

# Остановка сервиса
if [ -f /opt/etc/init.d/S56dnsmasq ]; then
    echo "  Остановка dnsmasq..."
    /opt/etc/init.d/S56dnsmasq stop >/dev/null 2>&1 || true
fi

# Убийство процессов
DNSMASQ_PIDS=$(ps | grep "[d]nsmasq" | awk '{print $1}' 2>/dev/null || true)
if [ -n "$DNSMASQ_PIDS" ]; then
    echo "  Завершение процессов dnsmasq..."
    for PID in $DNSMASQ_PIDS; do
        kill -9 $PID 2>/dev/null || true
    done
fi

# Удаление пакета
if opkg list-installed | grep -q "^dnsmasq "; then
    echo "  Удаление пакета dnsmasq..."
    opkg remove dnsmasq >/dev/null 2>&1 || true
fi

# Удаление конфигов
echo "  Удаление конфигурационных файлов..."
rm -f /opt/etc/dnsmasq.conf 2>/dev/null || true
rm -f /opt/etc/dnsmasq.d/user-custom.conf 2>/dev/null || true
rm -f /opt/etc/dnsmasq.d/custom.conf 2>/dev/null || true

# Бэкапы НЕ удаляем (сохраняем для восстановления)
if [ -d /opt/etc/dnsmasq.d/backups ]; then
    BACKUP_COUNT=$(ls -1 /opt/etc/dnsmasq.d/backups/ 2>/dev/null | wc -l || echo 0)
    if [ "$BACKUP_COUNT" -gt 0 ]; then
        echo -e "  ${GREEN}✓ Бэкапы сохранены: /opt/etc/dnsmasq.d/backups/ ($BACKUP_COUNT файлов)${NC}"
    fi
fi

# Удаление пустых директорий
rmdir /opt/etc/dnsmasq.d 2>/dev/null || true

# Удаление init скрипта
rm -f /opt/etc/init.d/S56dnsmasq 2>/dev/null || true

# Удаление скриптов
rm -f /opt/etc/update-hosts-auto.sh 2>/dev/null || true
rm -f /opt/bin/dns-status 2>/dev/null || true

# Удаление sources.list
rm -rf /opt/etc/hosts-automation 2>/dev/null || true

echo -e "${GREEN}✓ dnsmasq удален${NC}"
echo ""

# ================================================================
# Удаление nfqws
# ================================================================
echo -e "${YELLOW}► Удаление nfqws-keenetic...${NC}"

# Остановка сервиса
if [ -f /opt/etc/init.d/S51nfqws ]; then
    echo "  Остановка nfqws..."
    /opt/etc/init.d/S51nfqws stop >/dev/null 2>&1 || true
fi

# Удаление пакетов
if opkg list-installed | grep -q "nfqws-keenetic"; then
    echo "  Удаление пакетов nfqws..."
    opkg remove nfqws-keenetic-web >/dev/null 2>&1 || true
    opkg remove nfqws-keenetic >/dev/null 2>&1 || true
fi

# Удаление конфигов
echo "  Удаление конфигурационных файлов nfqws..."
rm -rf /opt/etc/nfqws 2>/dev/null || true

# Удаление репозитория
rm -f /opt/etc/opkg/nfqws-keenetic.conf 2>/dev/null || true

# Удаление скриптов интеграции
rm -f /opt/etc/sync-dns-dpi.sh 2>/dev/null || true

echo -e "${GREEN}✓ nfqws-keenetic удален${NC}"
echo ""

# ================================================================
# Удаление IP алиаса
# ================================================================
echo -e "${YELLOW}► Удаление IP алиаса...${NC}"

# Остановка сервиса
if [ -f /opt/etc/init.d/S55network-alias ]; then
    /opt/etc/init.d/S55network-alias stop >/dev/null 2>&1 || true
fi

# Удаление алиаса
ifconfig br0:1 down 2>/dev/null || true

# Удаление init скрипта
rm -f /opt/etc/init.d/S55network-alias 2>/dev/null || true

echo -e "${GREEN}✓ IP алиас удален${NC}"
echo ""

# ================================================================
# Удаление cron задач
# ================================================================
echo -e "${YELLOW}► Удаление cron задач...${NC}"

rm -f /opt/etc/cron.d/update-hosts 2>/dev/null || true
rm -f /opt/etc/cron.d/sync-dns-dpi 2>/dev/null || true

# Перезапуск cron
if [ -f /opt/etc/init.d/S10cron ]; then
    /opt/etc/init.d/S10cron restart >/dev/null 2>&1 || true
fi

echo -e "${GREEN}✓ Cron задачи удалены${NC}"
echo ""

# ================================================================
# Удаление логов
# ================================================================
echo -e "${YELLOW}► Удаление логов...${NC}"

# Проверка переменной DELETE_LOGS
if [ -n "$DELETE_LOGS" ]; then
    if [ "$DELETE_LOGS" = "yes" ] || [ "$DELETE_LOGS" = "YES" ]; then
        rm -f /opt/var/log/dnsmasq.log 2>/dev/null || true
        rm -f /opt/var/log/hosts-updater.log 2>/dev/null || true
        rm -f /opt/var/log/hosts-stats.txt 2>/dev/null || true
        rm -f /opt/var/log/nfqws.log 2>/dev/null || true
        rm -f /opt/var/log/sync-dns-dpi.log 2>/dev/null || true
        echo -e "${GREEN}✓ Логи удалены${NC}"
    else
        echo -e "${BLUE}✓ Логи сохранены (DELETE_LOGS != yes)${NC}"
    fi
else
    # Интерактивный режим
    if [ -t 0 ]; then
        echo ""
        echo -e "${YELLOW}Удалить логи? (yes/no)${NC}"
        echo "  /opt/var/log/dnsmasq.log"
        echo "  /opt/var/log/hosts-updater.log"
        echo "  /opt/var/log/hosts-stats.txt"
        echo "  /opt/var/log/nfqws.log"
        echo "  /opt/var/log/sync-dns-dpi.log"
        echo ""
        read -r DELETE_LOGS_INPUT
        
        if [ "$DELETE_LOGS_INPUT" = "yes" ] || [ "$DELETE_LOGS_INPUT" = "YES" ]; then
            rm -f /opt/var/log/dnsmasq.log 2>/dev/null || true
            rm -f /opt/var/log/hosts-updater.log 2>/dev/null || true
            rm -f /opt/var/log/hosts-stats.txt 2>/dev/null || true
            rm -f /opt/var/log/nfqws.log 2>/dev/null || true
            rm -f /opt/var/log/sync-dns-dpi.log 2>/dev/null || true
            echo -e "${GREEN}✓ Логи удалены${NC}"
        else
            echo -e "${BLUE}✓ Логи сохранены${NC}"
        fi
    else
        echo -e "${BLUE}✓ Логи сохранены (автоматический режим)${NC}"
    fi
fi

echo ""

# ================================================================
# Очистка iptables правил nfqws (если остались)
# ================================================================
echo -e "${YELLOW}► Очистка iptables правил...${NC}"

# Удаление правил nfqws
iptables -t mangle -D POSTROUTING -j nfqws_mark 2>/dev/null || true
iptables -t mangle -F nfqws_mark 2>/dev/null || true
iptables -t mangle -X nfqws_mark 2>/dev/null || true
iptables -D POSTROUTING -m mark --mark 0x40000000/0x40000000 -j NFQUEUE --queue-num 200 2>/dev/null || true

echo -e "${GREEN}✓ iptables правила очищены${NC}"
echo ""

# ================================================================
# Проверка остатков
# ================================================================
echo -e "${YELLOW}► Проверка остатков...${NC}"

REMNANTS=0

# Проверка процессов
if pgrep dnsmasq >/dev/null 2>&1; then
    echo -e "${YELLOW}  ⚠ Процесс dnsmasq всё ещё запущен${NC}"
    REMNANTS=1
fi

if pgrep nfqws >/dev/null 2>&1; then
    echo -e "${YELLOW}  ⚠ Процесс nfqws всё ещё запущен${NC}"
    REMNANTS=1
fi

# Проверка IP алиаса
if ifconfig br0:1 2>/dev/null | grep -q "192.168.1.2"; then
    echo -e "${YELLOW}  ⚠ IP алиас 192.168.1.2 всё ещё существует${NC}"
    REMNANTS=1
fi

# Проверка портов
if netstat -ln 2>/dev/null | grep -q "192.168.1.2:"; then
    echo -e "${YELLOW}  ⚠ Порты на 192.168.1.2 всё ещё слушаются${NC}"
    REMNANTS=1
fi

if [ $REMNANTS -eq 0 ]; then
    echo -e "${GREEN}✓ Остатков не обнаружено${NC}"
fi

echo ""

# ================================================================
# Восстановление DNS настроек Keenetic (попытка)
# ================================================================
echo -e "${YELLOW}► Попытка восстановления DNS настроек Keenetic...${NC}"

if command -v ndmc >/dev/null 2>&1; then
    echo "  Сброс на автоматические DNS через ndmc..."
    ndmc -c "interface Broadband0" -c "no ip name-server" >/dev/null 2>&1 || true
    echo -e "${BLUE}  ℹ Проверьте DNS в веб-интерфейсе: http://192.168.1.1${NC}"
else
    echo -e "${YELLOW}  ⚠ ndmc не найден${NC}"
    echo -e "${YELLOW}  Настройте DNS вручную:${NC}"
    echo "    1. Откройте http://192.168.1.1"
    echo "    2. Интернет → Подключения → Ваше подключение"
    echo "    3. DNS → Автоматически или укажите провайдерские DNS"
fi

echo ""

# ================================================================
# Итоговая информация
# ================================================================
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Удаление завершено!                    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BLUE}📋 Что было удалено:${NC}"
echo "  ✓ dnsmasq (пакет и конфиги)"
echo "  ✓ nfqws-keenetic (пакеты и конфиги)"
echo "  ✓ IP алиас 192.168.1.2"
echo "  ✓ Init скрипты (S55, S56, S51)"
echo "  ✓ Cron задачи"
echo "  ✓ Скрипты обновления и синхронизации"

if [ -n "$DELETE_LOGS" ] && { [ "$DELETE_LOGS" = "yes" ] || [ "$DELETE_LOGS" = "YES" ]; }; then
    echo "  ✓ Логи"
else
    echo "  ✓ Логи (сохранены в /opt/var/log/)"
fi

echo ""

if [ -d /opt/etc/dnsmasq.d/backups ]; then
    echo -e "${BLUE}💾 Бэкапы сохранены:${NC}"
    echo "  /opt/etc/dnsmasq.d/backups/"
    echo ""
fi

echo -e "${YELLOW}📋 Следующие шаги:${NC}"
echo "  1. Проверьте DNS в Keenetic: http://192.168.1.1"
echo "  2. Интернет → Подключения → Ваше подключение"
echo "  3. Убедитесь что DNS настроен (автоматически или вручную)"
echo ""
echo -e "${BLUE}  Для повторной установки:${NC}"
echo "  curl -fsSL https://raw.githubusercontent.com/ldeprive3-spec/keenetic-hosts-automation/main/install.sh | sh"
echo ""

# Рекомендация перезагрузки
echo -e "${YELLOW}💡 Рекомендуется перезагрузить роутер:${NC}"
echo "  reboot"
echo ""

exit 0
