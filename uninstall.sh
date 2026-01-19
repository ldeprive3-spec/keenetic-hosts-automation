#!/bin/sh

# ================================================================
# Keenetic DNS + DPI Bypass Uninstaller
# GitHub: https://github.com/ldeprive3-spec/keenetic-hosts-automation
# Version: 2.0 - Press Enter to confirm
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
# Предупреждение и подтверждение
# ================================================================
echo -e "${YELLOW}⚠ ВНИМАНИЕ! Будут удалены:${NC}"
echo ""
echo "  • dnsmasq (DNS сервер)"
echo "  • nfqws-keenetic (DPI bypass)"
echo "  • Все конфигурации"
echo "  • Все логи"
echo "  • Cron задачи"
echo "  • IP алиас 192.168.1.2"
echo ""
echo -e "${BLUE}💾 Бэкапы будут сохранены в /opt/etc/dnsmasq.d/backups/${NC}"
echo ""
echo -e "${YELLOW}════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Нажмите Enter для продолжения${NC}"
echo -e "${RED}или введите 'n' для отмены: ${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════${NC}"

# Читаем с таймаутом 30 секунд
if read -t 30 -r RESPONSE </dev/tty 2>/dev/null; then
    # Если введено n/N/no/NO - отменяем
    case "$RESPONSE" in
        n|N|no|NO|нет|Нет)
            echo ""
            echo -e "${GREEN}✓ Удаление отменено${NC}"
            exit 0
            ;;
        *)
            # Любой другой ввод (включая Enter) - продолжаем
            echo ""
            echo -e "${BLUE}► Начинаем удаление...${NC}"
            ;;
    esac
else
    # Таймаут или нет /dev/tty - автоматически продолжаем через 5 сек
    echo ""
    echo -e "${YELLOW}⚠ Интерактивный режим недоступен${NC}"
    echo -e "${BLUE}Автоматическое продолжение через 5 секунд...${NC}"
    echo -e "${YELLOW}(Нажмите Ctrl+C для отмены)${NC}"
    sleep 5
    echo ""
    echo -e "${BLUE}► Начинаем удаление...${NC}"
fi

echo ""

# ================================================================
# Удаление dnsmasq
# ================================================================
echo -e "${YELLOW}[1/8] Удаление dnsmasq...${NC}"

# Остановка сервиса
if [ -f /opt/etc/init.d/S56dnsmasq ]; then
    echo "  • Остановка сервиса..."
    /opt/etc/init.d/S56dnsmasq stop >/dev/null 2>&1 || true
    sleep 1
fi

# Убийство процессов
DNSMASQ_PIDS=$(ps | grep "[d]nsmasq" | awk '{print $1}' 2>/dev/null || true)
if [ -n "$DNSMASQ_PIDS" ]; then
    echo "  • Завершение процессов..."
    for PID in $DNSMASQ_PIDS; do
        kill -9 $PID 2>/dev/null || true
    done
    sleep 1
fi

# Удаление пакета
if opkg list-installed 2>/dev/null | grep -q "^dnsmasq "; then
    echo "  • Удаление пакета..."
    opkg remove dnsmasq >/dev/null 2>&1 || true
fi

# Бэкап конфигов перед удалением
if [ -f /opt/etc/dnsmasq.conf ]; then
    mkdir -p /opt/etc/dnsmasq.d/backups 2>/dev/null || true
    BACKUP_FILE="/opt/etc/dnsmasq.d/backups/dnsmasq.conf.$(date '+%Y%m%d_%H%M%S')"
    cp /opt/etc/dnsmasq.conf "$BACKUP_FILE" 2>/dev/null || true
    echo "  • Бэкап: $BACKUP_FILE"
fi

# Удаление конфигов
echo "  • Удаление конфигов..."
rm -f /opt/etc/dnsmasq.conf 2>/dev/null || true
rm -f /opt/etc/dnsmasq.d/user-custom.conf 2>/dev/null || true
rm -f /opt/etc/dnsmasq.d/custom.conf 2>/dev/null || true

# Удаление init скриптов
rm -f /opt/etc/init.d/S56dnsmasq 2>/dev/null || true

# Удаление утилит
rm -f /opt/etc/update-hosts-auto.sh 2>/dev/null || true
rm -f /opt/bin/dns-status 2>/dev/null || true

# Удаление sources.list
rm -rf /opt/etc/hosts-automation 2>/dev/null || true

# Проверка бэкапов
if [ -d /opt/etc/dnsmasq.d/backups ]; then
    BACKUP_COUNT=$(ls -1 /opt/etc/dnsmasq.d/backups/ 2>/dev/null | wc -l || echo 0)
    if [ "$BACKUP_COUNT" -gt 0 ]; then
        echo "  • Сохранено бэкапов: $BACKUP_COUNT"
    fi
fi

# Удаление пустых директорий (кроме backups)
rmdir /opt/etc/dnsmasq.d 2>/dev/null || true

echo -e "${GREEN}✓ dnsmasq удален${NC}"
echo ""

# ================================================================
# Удаление nfqws
# ================================================================
echo -e "${YELLOW}[2/8] Удаление nfqws-keenetic...${NC}"

# Остановка сервиса
if [ -f /opt/etc/init.d/S51nfqws ]; then
    echo "  • Остановка сервиса..."
    /opt/etc/init.d/S51nfqws stop >/dev/null 2>&1 || true
    sleep 1
fi

# Удаление пакетов
NFQWS_INSTALLED=0
if opkg list-installed 2>/dev/null | grep -q "nfqws-keenetic"; then
    echo "  • Удаление пакетов..."
    opkg remove nfqws-keenetic-web >/dev/null 2>&1 || true
    opkg remove nfqws-keenetic >/dev/null 2>&1 || true
    NFQWS_INSTALLED=1
fi

# Удаление конфигов
if [ -d /opt/etc/nfqws ]; then
    echo "  • Удаление конфигов..."
    rm -rf /opt/etc/nfqws 2>/dev/null || true
fi

# Удаление репозитория
rm -f /opt/etc/opkg/nfqws-keenetic.conf 2>/dev/null || true

# Удаление скриптов интеграции
rm -f /opt/etc/sync-dns-dpi.sh 2>/dev/null || true

if [ $NFQWS_INSTALLED -eq 1 ]; then
    echo -e "${GREEN}✓ nfqws-keenetic удален${NC}"
else
    echo -e "${BLUE}• nfqws-keenetic не был установлен${NC}"
fi

echo ""

# ================================================================
# Удаление IP алиаса
# ================================================================
echo -e "${YELLOW}[3/8] Удаление IP алиаса...${NC}"

# Остановка сервиса
if [ -f /opt/etc/init.d/S55network-alias ]; then
    echo "  • Остановка сервиса..."
    /opt/etc/init.d/S55network-alias stop >/dev/null 2>&1 || true
fi

# Удаление алиаса
if ifconfig br0:1 2>/dev/null | grep -q "192.168.1.2"; then
    echo "  • Удаление алиаса 192.168.1.2..."
    ifconfig br0:1 down 2>/dev/null || true
fi

# Удаление init скрипта
rm -f /opt/etc/init.d/S55network-alias 2>/dev/null || true

echo -e "${GREEN}✓ IP алиас удален${NC}"
echo ""

# ================================================================
# Удаление cron задач
# ================================================================
echo -e "${YELLOW}[4/8] Удаление cron задач...${NC}"

CRON_REMOVED=0

if [ -f /opt/etc/cron.d/update-hosts ]; then
    rm -f /opt/etc/cron.d/update-hosts 2>/dev/null || true
    echo "  • update-hosts"
    CRON_REMOVED=1
fi

if [ -f /opt/etc/cron.d/sync-dns-dpi ]; then
    rm -f /opt/etc/cron.d/sync-dns-dpi 2>/dev/null || true
    echo "  • sync-dns-dpi"
    CRON_REMOVED=1
fi

# Перезапуск cron
if [ $CRON_REMOVED -eq 1 ]; then
    if [ -f /opt/etc/init.d/S10cron ]; then
        /opt/etc/init.d/S10cron restart >/dev/null 2>&1 || true
    fi
    echo -e "${GREEN}✓ Cron задачи удалены${NC}"
else
    echo -e "${BLUE}• Cron задачи не найдены${NC}"
fi

echo ""

# ================================================================
# Удаление логов
# ================================================================
echo -e "${YELLOW}[5/8] Удаление логов...${NC}"

LOGS_DELETED=0

LOG_FILES="/opt/var/log/dnsmasq.log \
/opt/var/log/hosts-updater.log \
/opt/var/log/hosts-stats.txt \
/opt/var/log/nfqws.log \
/opt/var/log/sync-dns-dpi.log"

for LOG in $LOG_FILES; do
    if [ -f "$LOG" ]; then
        rm -f "$LOG" 2>/dev/null || true
        LOGS_DELETED=$((LOGS_DELETED + 1))
    fi
done

if [ $LOGS_DELETED -gt 0 ]; then
    echo "  • Удалено логов: $LOGS_DELETED"
    echo -e "${GREEN}✓ Логи удалены${NC}"
else
    echo -e "${BLUE}• Логи не найдены${NC}"
fi

echo ""

# ================================================================
# Очистка iptables правил
# ================================================================
echo -e "${YELLOW}[6/8] Очистка iptables правил...${NC}"

IPTABLES_CLEANED=0

# Удаление правил nfqws
if iptables -t mangle -L nfqws_mark >/dev/null 2>&1; then
    echo "  • Удаление цепочки nfqws_mark..."
    iptables -t mangle -D POSTROUTING -j nfqws_mark 2>/dev/null || true
    iptables -t mangle -F nfqws_mark 2>/dev/null || true
    iptables -t mangle -X nfqws_mark 2>/dev/null || true
    IPTABLES_CLEANED=1
fi

# Удаление NFQUEUE правила
if iptables -L POSTROUTING -t mangle 2>/dev/null | grep -q "NFQUEUE"; then
    echo "  • Удаление NFQUEUE правила..."
    iptables -t mangle -D POSTROUTING -m mark --mark 0x40000000/0x40000000 -j NFQUEUE --queue-num 200 2>/dev/null || true
    IPTABLES_CLEANED=1
fi

if [ $IPTABLES_CLEANED -eq 1 ]; then
    echo -e "${GREEN}✓ iptables правила очищены${NC}"
else
    echo -e "${BLUE}• iptables правила не найдены${NC}"
fi

echo ""

# ================================================================
# Проверка остатков
# ================================================================
echo -e "${YELLOW}[7/8] Проверка остатков...${NC}"

REMNANTS=0

# Проверка процессов
if pgrep dnsmasq >/dev/null 2>&1; then
    echo -e "  ${YELLOW}⚠ Процесс dnsmasq запущен${NC}"
    REMNANTS=1
fi

if pgrep nfqws >/dev/null 2>&1; then
    echo -e "  ${YELLOW}⚠ Процесс nfqws запущен${NC}"
    REMNANTS=1
fi

# Проверка IP алиаса
if ifconfig br0:1 2>/dev/null | grep -q "192.168.1.2"; then
    echo -e "  ${YELLOW}⚠ IP алиас 192.168.1.2 существует${NC}"
    REMNANTS=1
fi

# Проверка портов
if netstat -ln 2>/dev/null | grep -q "192.168.1.2:"; then
    echo -e "  ${YELLOW}⚠ Порты на 192.168.1.2 слушаются${NC}"
    REMNANTS=1
fi

if [ $REMNANTS -eq 0 ]; then
    echo -e "${GREEN}✓ Остатков не обнаружено${NC}"
else
    echo -e "${YELLOW}⚠ Обнаружены остатки (возможно потребуется перезагрузка)${NC}"
fi

echo ""

# ================================================================
# Восстановление DNS Keenetic
# ================================================================
echo -e "${YELLOW}[8/8] Восстановление DNS...${NC}"

if command -v ndmc >/dev/null 2>&1; then
    echo "  • Попытка сброса DNS через ndmc..."
    ndmc -c "interface Broadband0" -c "no ip name-server" >/dev/null 2>&1 || true
    echo -e "${BLUE}  ℹ Проверьте настройки: http://192.168.1.1${NC}"
else
    echo -e "${YELLOW}  ⚠ ndmc не найден${NC}"
fi

echo -e "${BLUE}  • Настройте DNS вручную:${NC}"
echo "    http://192.168.1.1 → Интернет → Подключения"
echo ""

# ================================================================
# Итоговая информация
# ================================================================
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         ✓ Удаление завершено!                  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BLUE}📋 Удалено:${NC}"
echo "  ✓ dnsmasq (пакет, конфиги, скрипты)"
echo "  ✓ nfqws-keenetic (пакеты, конфиги)"
echo "  ✓ IP алиас 192.168.1.2"
echo "  ✓ Init скрипты (S55, S56, S51)"
echo "  ✓ Cron задачи"
echo "  ✓ Логи"
echo "  ✓ iptables правила"
echo ""

if [ -d /opt/etc/dnsmasq.d/backups ]; then
    BACKUP_COUNT=$(ls -1 /opt/etc/dnsmasq.d/backups/ 2>/dev/null | wc -l || echo 0)
    if [ "$BACKUP_COUNT" -gt 0 ]; then
        echo -e "${BLUE}💾 Бэкапы сохранены:${NC}"
        echo "  /opt/etc/dnsmasq.d/backups/ ($BACKUP_COUNT файлов)"
        echo ""
    fi
fi

echo -e "${YELLOW}📋 Следующие шаги:${NC}"
echo "  1. Проверьте DNS: http://192.168.1.1"
echo "     Интернет → Подключения → DNS"
echo ""
echo "  2. Перезагрузите роутер:"
echo "     ${GREEN}reboot${NC}"
echo ""
echo "  3. Для повторной установки:"
echo "     ${BLUE}curl -fsSL https://raw.githubusercontent.com/ldeprive3-spec/keenetic-hosts-automation/main/install.sh | sh${NC}"
echo ""

exit 0
