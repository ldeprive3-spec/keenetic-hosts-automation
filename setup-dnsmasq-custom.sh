#!/bin/sh

# ================================================================
# Keenetic dnsmasq Setup Script
# GitHub: https://github.com/ldeprive3-spec/keenetic-hosts-automation
# Version: 1.0
# ================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ================================================================
# Конфигурация
# ================================================================
DNSMASQ_IP="192.168.1.2"
ROUTER_IP="192.168.1.1"
DNSMASQ_PORT="53"
INTERFACE="br0:1"
UPSTREAM_DNS1="8.8.8.8"
UPSTREAM_DNS2="8.8.4.4"
UPSTREAM_DNS3="1.1.1.1"

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  dnsmasq Setup for Keenetic                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# ================================================================
# Проверка прав
# ================================================================
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}✗ Требуются права root!${NC}"
    exit 1
fi

# ================================================================
# Установка зависимостей
# ================================================================
echo -e "${YELLOW}► Установка зависимостей...${NC}"

PACKAGES="dnsmasq bind-dig"
opkg update >/dev/null 2>&1

for pkg in $PACKAGES; do
    if ! opkg list-installed | grep -q "^$pkg "; then
        echo "  Установка $pkg..."
        opkg install $pkg >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "  ${GREEN}✓ $pkg${NC}"
        else
            echo -e "  ${RED}✗ Ошибка: $pkg${NC}"
        fi
    else
        echo -e "  ${GREEN}✓ $pkg (уже установлен)${NC}"
    fi
done

# ================================================================
# Остановка dnsmasq
# ================================================================
echo ""
echo -e "${YELLOW}► Остановка существующих процессов...${NC}"
killall dnsmasq 2>/dev/null
sleep 1
echo -e "${GREEN}✓ Процессы остановлены${NC}"

# ================================================================
# Создание директорий
# ================================================================
echo ""
echo -e "${YELLOW}► Создание структуры директорий...${NC}"

mkdir -p /opt/etc/dnsmasq.d
mkdir -p /opt/var/log
mkdir -p /opt/etc/init.d
mkdir -p /opt/etc/cron.d
mkdir -p /opt/bin

echo -e "${GREEN}✓ Директории созданы${NC}"

# ================================================================
# Настройка сетевого алиаса
# ================================================================
echo ""
echo -e "${YELLOW}► Настройка IP алиаса ${DNSMASQ_IP}...${NC}"

cat > /opt/etc/init.d/S55network-alias << 'EOFALIAS'
#!/bin/sh

ENABLED=yes
ALIAS_IP="192.168.1.2"
NETMASK="255.255.255.0"
INTERFACE="br0:1"

start() {
    if ! ifconfig | grep -q "br0"; then
        echo "Error: br0 не найден"
        return 1
    fi
    
    ifconfig $INTERFACE $ALIAS_IP netmask $NETMASK up 2>/dev/null
    
    if ifconfig $INTERFACE 2>/dev/null | grep -q "$ALIAS_IP"; then
        echo "Алиас $ALIAS_IP добавлен"
        return 0
    else
        echo "Ошибка добавления алиаса"
        return 1
    fi
}

stop() {
    ifconfig $INTERFACE down 2>/dev/null
    echo "Алиас удален"
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        sleep 1
        start
        ;;
    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 1
        ;;
esac
EOFALIAS

chmod +x /opt/etc/init.d/S55network-alias
/opt/etc/init.d/S55network-alias start >/dev/null 2>&1

if ifconfig br0:1 2>/dev/null | grep -q "${DNSMASQ_IP}"; then
    echo -e "${GREEN}✓ IP алиас ${DNSMASQ_IP} создан${NC}"
else
    echo -e "${RED}✗ Ошибка создания алиаса${NC}"
    exit 1
fi

# ================================================================
# Конфигурация dnsmasq
# ================================================================
echo ""
echo -e "${YELLOW}► Создание конфигурации dnsmasq...${NC}"

cat > /opt/etc/dnsmasq.conf << EOFDNSMASQ
# dnsmasq Configuration
# Generated: $(date)

port=${DNSMASQ_PORT}
bind-interfaces
listen-address=${DNSMASQ_IP}

domain-needed
bogus-priv
no-resolv
no-poll

server=${UPSTREAM_DNS1}
server=${UPSTREAM_DNS2}
server=${UPSTREAM_DNS3}

cache-size=1000
neg-ttl=60
local-ttl=300

conf-dir=/opt/etc/dnsmasq.d,*.conf

log-queries
log-facility=/opt/var/log/dnsmasq.log

dns-forward-max=300
stop-dns-rebind
rebind-localhost-ok
EOFDNSMASQ

echo -e "${GREEN}✓ Конфигурация создана${NC}"

# ================================================================
# Создание custom.conf
# ================================================================
if [ ! -f /opt/etc/dnsmasq.d/custom.conf ]; then
    cat > /opt/etc/dnsmasq.d/custom.conf << 'EOFCUSTOM'
# Custom DNS entries
# Format: address=/domain.com/IP
# Example: address=/ads.example.com/0.0.0.0
EOFCUSTOM
    echo -e "${GREEN}✓ custom.conf создан${NC}"
fi

# ================================================================
# Init скрипт dnsmasq
# ================================================================
echo ""
echo -e "${YELLOW}► Создание init скрипта...${NC}"

cat > /opt/etc/init.d/S56dnsmasq << 'EOFINIT'
#!/bin/sh

ENABLED=yes
PROCS=dnsmasq
ARGS="--conf-file=/opt/etc/dnsmasq.conf"
PREARGS=""
DESC=$PROCS
PATH=/opt/sbin:/opt/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

. /opt/etc/init.d/rc.func
EOFINIT

chmod +x /opt/etc/init.d/S56dnsmasq
echo -e "${GREEN}✓ Init скрипт создан${NC}"

# ================================================================
# Настройка cron
# ================================================================
echo ""
echo -e "${YELLOW}► Настройка cron...${NC}"

cat > /opt/etc/cron.d/update-hosts << 'EOFCRON'
0 3 * * * root /opt/etc/update-hosts-auto.sh >> /opt/var/log/hosts-updater.log 2>&1
5 3 * * * root /opt/etc/init.d/S56dnsmasq restart >/dev/null 2>&1
EOFCRON

if [ -f /opt/etc/init.d/S10cron ]; then
    /opt/etc/init.d/S10cron restart >/dev/null 2>&1
    echo -e "${GREEN}✓ Cron настроен${NC}"
fi

# ================================================================
# Dashboard скрипт
# ================================================================
echo ""
echo -e "${YELLOW}► Создание утилит мониторинга...${NC}"

cat > /opt/bin/dns-status << 'EOFDASH'
#!/bin/sh

clear
echo "╔════════════════════════════════════════════════╗"
echo "║         dnsmasq DNS Dashboard                  ║"
echo "╚════════════════════════════════════════════════╝"
echo ""

echo "🌐 Network:"
PRIMARY_IP=$(ifconfig br0 2>/dev/null | grep 'inet addr' | awk '{print $2}' | cut -d: -f2)
SECONDARY_IP=$(ifconfig br0:1 2>/dev/null | grep 'inet addr' | awk '{print $2}' | cut -d: -f2)
echo "   Primary:   ${PRIMARY_IP:-N/A}"
echo "   Secondary: ${SECONDARY_IP:-N/A}"
echo ""

echo "📊 Status:"
if ps | grep -q "[d]nsmasq"; then
    PID=$(ps | grep "[d]nsmasq" | awk '{print $1}')
    echo "   ✅ dnsmasq: RUNNING (PID: $PID)"
else
    echo "   ❌ dnsmasq: STOPPED"
fi
echo ""

echo "🔌 Listening:"
netstat -ln 2>/dev/null | grep ":53 " | grep "${SECONDARY_IP}" | head -2 | sed 's/^/   /'
echo ""

HOSTS_COUNT=$(grep -c "^address=" /opt/etc/dnsmasq.d/custom.conf 2>/dev/null || echo "0")
echo "📋 Custom hosts: $HOSTS_COUNT entries"
echo ""

echo "📈 Recent queries (last 5):"
tail -5 /opt/var/log/dnsmasq.log 2>/dev/null | grep "query\[A\]" | \
    awk '{printf "   %-25s → %s\n", $6, $7}' || echo "   No queries"
echo ""

if [ -n "$SECONDARY_IP" ]; then
    TEST=$(dig @${SECONDARY_IP} google.com +short 2>/dev/null | head -1)
    if [ -n "$TEST" ]; then
        echo "🧪 Test: google.com → ${TEST}"
    else
        echo "🧪 Test: FAILED"
    fi
fi
echo ""

echo "Commands:"
echo "  /opt/etc/init.d/S56dnsmasq restart - перезапуск"
echo "  tail -f /opt/var/log/dnsmasq.log   - мониторинг"
EOFDASH

chmod +x /opt/bin/dns-status
echo -e "${GREEN}✓ dns-status создан${NC}"

# ================================================================
# Запуск dnsmasq
# ================================================================
echo ""
echo -e "${YELLOW}► Запуск dnsmasq...${NC}"

/opt/etc/init.d/S56dnsmasq start >/dev/null 2>&1
sleep 2

if ps | grep -q "[d]nsmasq"; then
    echo -e "${GREEN}✓ dnsmasq запущен${NC}"
else
    echo -e "${RED}✗ Ошибка запуска${NC}"
    exit 1
fi

# ================================================================
# Автоматическая настройка DNS в Keenetic (через ndmc)
# ================================================================
echo ""
echo -e "${YELLOW}► Автоматическая настройка DNS в Keenetic...${NC}"

# Попытка настроить через ndmc (если доступен)
if command -v ndmc >/dev/null 2>&1; then
    echo "  Настройка через ndmc..."
    
    # Добавление DNS сервера
    ndmc -c "system dns server add ${DNSMASQ_IP}" >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✓ DNS ${DNSMASQ_IP} добавлен в систему${NC}"
    else
        echo -e "  ${YELLOW}⚠ Не удалось добавить через ndmc${NC}"
        echo -e "  ${YELLOW}  Настройте вручную через веб-интерфейс${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠ ndmc не найден${NC}"
    echo -e "  ${YELLOW}  Требуется ручная настройка DNS через веб-интерфейс:${NC}"
    echo "     1. Откройте http://${ROUTER_IP}"
    echo "     2. Интернет → Подключения → Ваше подключение"
    echo "     3. DNS 1: ${DNSMASQ_IP}"
    echo "     4. DNS 2: ${UPSTREAM_DNS1}"
fi

# ================================================================
# Финальная проверка
# ================================================================
echo ""
echo -e "${YELLOW}► Финальная проверка...${NC}"

if netstat -ln 2>/dev/null | grep -q "${DNSMASQ_IP}:${DNSMASQ_PORT}"; then
    echo -e "${GREEN}✓ Порт ${DNSMASQ_PORT} активен на ${DNSMASQ_IP}${NC}"
else
    echo -e "${RED}✗ Порт не слушается${NC}"
fi

TEST_DNS=$(dig @${DNSMASQ_IP} google.com +short 2>/dev/null | head -1)
if [ -n "$TEST_DNS" ]; then
    echo -e "${GREEN}✓ DNS тест: google.com → ${TEST_DNS}${NC}"
else
    echo -e "${RED}✗ DNS тест не прошел${NC}"
fi

# ================================================================
# Итог
# ================================================================
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Настройка завершена!                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✅ DNS сервер: ${DNSMASQ_IP}:${DNSMASQ_PORT}${NC}"
echo -e "${GREEN}✅ Автозапуск: настроен${NC}"
echo -e "${GREEN}✅ Cron: настроен${NC}"
echo ""

exit 0
