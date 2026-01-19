#!/bin/sh

# ================================================================
# dnsmasq Setup for Keenetic - Fixed for ndnproxy compatibility
# Version: 2.1
# ================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  dnsmasq Setup for Keenetic                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# ================================================================
# Проверка конфликтов портов
# ================================================================
echo -e "${YELLOW}► Проверка конфликтов портов...${NC}"

# Проверка порта 53
PORT_53_USED=$(netstat -ln | grep ":53 " | grep -v "127.0.0.1" | wc -l)

if [ "$PORT_53_USED" -gt 0 ]; then
    echo -e "${YELLOW}  ⚠ Порт 53 занят (вероятно ndnproxy)${NC}"
    
    # Проверяем это ndnproxy
    if ps | grep -q "ndnproxy"; then
        echo -e "${BLUE}  ℹ Обнаружен ndnproxy (встроенный DNS Keenetic)${NC}"
        echo -e "${BLUE}  ℹ dnsmasq будет использовать порт 5353${NC}"
        DNSMASQ_PORT=5353
    else
        echo -e "${YELLOW}  ⚠ Порт 53 занят неизвестным процессом:${NC}"
        netstat -lnp | grep ":53 "
        echo ""
        echo -e "${YELLOW}  Продолжить с портом 5353? (Ctrl+C для отмены)${NC}"
        sleep 5
        DNSMASQ_PORT=5353
    fi
else
    echo -e "${GREEN}  ✓ Порт 53 свободен${NC}"
    DNSMASQ_PORT=53
fi

# Проверка порта 5353 если он выбран
if [ "$DNSMASQ_PORT" = "5353" ]; then
    if netstat -ln | grep -q ":5353 "; then
        echo -e "${RED}  ✗ Порт 5353 тоже занят!${NC}"
        netstat -lnp | grep ":5353"
        echo ""
        echo -e "${RED}  Установка невозможна. Освободите порт 53 или 5353.${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}  ✓ Будет использован порт: $DNSMASQ_PORT${NC}"
echo ""

# ================================================================
# Установка зависимостей
# ================================================================
echo -e "${YELLOW}► Установка зависимостей...${NC}"

opkg update >/dev/null 2>&1

if ! opkg list-installed | grep -q "^dnsmasq "; then
    echo "  Установка dnsmasq..."
    opkg install dnsmasq >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  ✓ dnsmasq${NC}"
    else
        echo -e "${RED}  ✗ Ошибка установки dnsmasq${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}  ✓ dnsmasq (уже установлен)${NC}"
fi

if ! opkg list-installed | grep -q "^bind-dig "; then
    opkg install bind-dig >/dev/null 2>&1
    echo -e "${GREEN}  ✓ bind-dig${NC}"
else
    echo -e "${GREEN}  ✓ bind-dig (уже установлен)${NC}"
fi

echo ""

# ================================================================
# Остановка существующих процессов
# ================================================================
echo -e "${YELLOW}► Остановка существующих процессов dnsmasq...${NC}"

if [ -f /opt/etc/init.d/S56dnsmasq ]; then
    /opt/etc/init.d/S56dnsmasq stop >/dev/null 2>&1
fi

killall dnsmasq 2>/dev/null
sleep 1

echo -e "${GREEN}✓ Процессы остановлены${NC}"
echo ""

# ================================================================
# Создание структуры директорий
# ================================================================
echo -e "${YELLOW}► Создание структуры директорий...${NC}"

mkdir -p /opt/etc/dnsmasq.d
mkdir -p /opt/etc/dnsmasq.d/backups
mkdir -p /opt/var/log
mkdir -p /opt/etc/hosts-automation

echo -e "${GREEN}✓ Директории созданы${NC}"
echo ""

# ================================================================
# Настройка IP алиаса
# ================================================================
echo -e "${YELLOW}► Настройка IP алиаса 192.168.1.2...${NC}"

# Создание init скрипта для алиаса
cat > /opt/etc/init.d/S55network-alias << 'EOFNET'
#!/bin/sh

ENABLED=yes
PROCS=network-alias
DESC="Network IP Alias"

ALIAS_IP="192.168.1.2"
ALIAS_NETMASK="255.255.255.0"
INTERFACE="br0"

pre_cmd() {
    if [ "$ENABLED" != "yes" ]; then
        return 1
    fi
}

start_cmd() {
    # Проверка существует ли алиас
    if ifconfig ${INTERFACE}:1 2>/dev/null | grep -q "$ALIAS_IP"; then
        echo "Alias already exists"
        return 0
    fi
    
    # Создание алиаса
    ifconfig ${INTERFACE}:1 ${ALIAS_IP} netmask ${ALIAS_NETMASK} up
    
    if [ $? -eq 0 ]; then
        echo "Network alias created: ${ALIAS_IP}"
        return 0
    else
        echo "Failed to create alias"
        return 1
    fi
}

stop_cmd() {
    ifconfig ${INTERFACE}:1 down 2>/dev/null
    echo "Network alias removed"
}

status_cmd() {
    if ifconfig ${INTERFACE}:1 2>/dev/null | grep -q "$ALIAS_IP"; then
        echo "Alias is UP: $ALIAS_IP"
        return 0
    else
        echo "Alias is DOWN"
        return 1
    fi
}

PRECMD="pre_cmd"
PREARGS=""

. /opt/etc/init.d/rc.func
EOFNET

chmod +x /opt/etc/init.d/S55network-alias

# Запуск алиаса
/opt/etc/init.d/S55network-alias start >/dev/null 2>&1

if ifconfig br0:1 2>/dev/null | grep -q "192.168.1.2"; then
    echo -e "${GREEN}✓ IP алиас 192.168.1.2 создан${NC}"
else
    echo -e "${YELLOW}⚠ IP алиас не создан, попытка альтернативного метода...${NC}"
    ifconfig br0:1 192.168.1.2 netmask 255.255.255.0 up
    
    if ifconfig br0:1 2>/dev/null | grep -q "192.168.1.2"; then
        echo -e "${GREEN}✓ IP алиас 192.168.1.2 создан (альтернативный метод)${NC}"
    else
        echo -e "${RED}✗ Не удалось создать IP алиас${NC}"
    fi
fi

echo ""

# ================================================================
# Создание конфигурации dnsmasq
# ================================================================
echo -e "${YELLOW}► Создание конфигурации dnsmasq...${NC}"

cat > /opt/etc/dnsmasq.conf << EOFCONF
# ================================================================
# dnsmasq Configuration for Keenetic
# Port: ${DNSMASQ_PORT} (auto-detected to avoid conflicts)
# ================================================================

# Basic settings
port=${DNSMASQ_PORT}
bind-interfaces
listen-address=192.168.1.2

# Domain settings
domain-needed
bogus-priv
expand-hosts
domain=lan

# DNS cache
cache-size=1000
neg-ttl=60

# Upstream DNS servers
no-resolv
server=8.8.8.8
server=8.8.4.4
server=1.1.1.1
server=1.0.0.1

# Additional config files
conf-dir=/opt/etc/dnsmasq.d,*.conf

# Logging (comment out for better performance)
log-queries
log-facility=/opt/var/log/dnsmasq.log

# Performance
dns-forward-max=150
cache-size=1000

# DNSSEC (optional, uncomment if needed)
#dnssec
#trust-anchor=.,20326,8,2,E06D44B80B8F1D39A95C0B0D7C65D08458E880409BBC683457104237C7F8EC8D

# ================================================================
# Custom hosts loaded from /opt/etc/dnsmasq.d/
# ================================================================
EOFCONF

echo -e "${GREEN}✓ Конфигурация создана (порт ${DNSMASQ_PORT})${NC}"
echo ""

# ================================================================
# Создание init скрипта
# ================================================================
echo -e "${YELLOW}► Создание init скрипта...${NC}"

cat > /opt/etc/init.d/S56dnsmasq << 'EOFINIT'
#!/bin/sh

ENABLED=yes
PROCS=dnsmasq
ARGS="--conf-file=/opt/etc/dnsmasq.conf"
PREARGS=""
DESC="DNS server"
PATH=/opt/sbin:/opt/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

pre_cmd() {
    # Проверка что IP алиас существует
    if ! ifconfig br0:1 2>/dev/null | grep -q "192.168.1.2"; then
        echo "Creating IP alias..."
        /opt/etc/init.d/S55network-alias start >/dev/null 2>&1
        sleep 1
    fi
    
    # Проверка конфига
    dnsmasq --test --conf-file=/opt/etc/dnsmasq.conf >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Configuration test failed!"
        return 1
    fi
}

start_cmd() {
    # Убедимся что старые процессы убиты
    killall dnsmasq 2>/dev/null
    sleep 1
    
    # Запуск
    dnsmasq --conf-file=/opt/etc/dnsmasq.conf
    
    if [ $? -eq 0 ]; then
        sleep 2
        if pgrep dnsmasq >/dev/null; then
            return 0
        else
            echo "dnsmasq started but not running"
            return 1
        fi
    else
        return 1
    fi
}

stop_cmd() {
    killall dnsmasq 2>/dev/null
    sleep 1
    return 0
}

PRECMD="pre_cmd"
PREARGS=""

. /opt/etc/init.d/rc.func
EOFINIT

chmod +x /opt/etc/init.d/S56dnsmasq

echo -e "${GREEN}✓ Init скрипт создан${NC}"
echo ""

# ================================================================
# Настройка cron
# ================================================================
echo -e "${YELLOW}► Настройка cron...${NC}"

mkdir -p /opt/etc/cron.d

# Проверка существования update-hosts-auto.sh
if [ -f /opt/etc/update-hosts-auto.sh ]; then
    cat > /opt/etc/cron.d/update-hosts << 'EOFCRON'
# Update hosts daily at 3:00 AM
0 3 * * * root /opt/etc/update-hosts-auto.sh >> /opt/var/log/hosts-updater.log 2>&1
EOFCRON
    echo -e "${GREEN}✓ Cron настроен (обновление в 3:00)${NC}"
else
    echo -e "${YELLOW}  ⚠ update-hosts-auto.sh не найден, cron будет настроен позже${NC}"
fi

echo ""

# ================================================================
# Создание утилит мониторинга
# ================================================================
echo -e "${YELLOW}► Создание утилит мониторинга...${NC}"

# Определяем порт для dashboard
DASHBOARD_PORT=$(grep "^port=" /opt/etc/dnsmasq.conf | cut -d= -f2)

cat > /opt/bin/dns-status << EOFDASH
#!/bin/sh

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "\${BLUE}╔════════════════════════════════════════════════╗\${NC}"
echo -e "\${BLUE}║         dnsmasq DNS Dashboard                  ║\${NC}"
echo -e "\${BLUE}╚════════════════════════════════════════════════╝\${NC}"
echo ""

# Network info
PRIMARY_IP=\$(ifconfig br0 | grep "inet addr" | awk '{print \$2}' | cut -d: -f2)
SECONDARY_IP=\$(ifconfig br0:1 2>/dev/null | grep "inet addr" | awk '{print \$2}' | cut -d: -f2)

echo -e "\${BLUE}🌐 Network:\${NC}"
echo "   Primary:   \${PRIMARY_IP:-N/A}"
echo "   Secondary: \${SECONDARY_IP:-N/A}"
echo ""

# dnsmasq status
if pgrep dnsmasq >/dev/null; then
    PID=\$(pgrep dnsmasq)
    echo -e "\${BLUE}📊 Status:\${NC}"
    echo -e "   \${GREEN}✅ dnsmasq: RUNNING (PID: \${PID})\${NC}"
else
    echo -e "\${BLUE}📊 Status:\${NC}"
    echo -e "   \${RED}❌ dnsmasq: STOPPED\${NC}"
fi
echo ""

# Listening ports
echo -e "\${BLUE}🔌 Listening:\${NC}"
netstat -ln | grep "192.168.1.2:${DASHBOARD_PORT}" | while read line; do
    echo "   \$line"
done

if ! netstat -ln | grep -q "192.168.1.2:${DASHBOARD_PORT}"; then
    echo "   (none - порт ${DASHBOARD_PORT} не слушается)"
fi
echo ""

# Custom hosts count
if [ -f /opt/etc/dnsmasq.d/custom.conf ]; then
    HOSTS_COUNT=\$(grep -c "^address=" /opt/etc/dnsmasq.d/custom.conf 2>/dev/null || echo 0)
    echo -e "\${BLUE}📋 Custom hosts:\${NC} \${HOSTS_COUNT} entries"
else
    echo -e "\${BLUE}📋 Custom hosts:\${NC} 0 entries (not configured)"
fi
echo ""

# Recent queries
if [ -f /opt/var/log/dnsmasq.log ]; then
    echo -e "\${BLUE}📈 Recent queries (last 5):\${NC}"
    tail -5 /opt/var/log/dnsmasq.log | grep "query" | awk '{print "   " \$6, "\t→", \$8}' 2>/dev/null
    echo ""
fi

# DNS test
TEST_RESULT=\$(dig @192.168.1.2 -p ${DASHBOARD_PORT} google.com +short 2>/dev/null | head -1)
if [ -n "\$TEST_RESULT" ]; then
    echo -e "\${BLUE}🧪 Test:\${NC} google.com → \${GREEN}\${TEST_RESULT}\${NC}"
else
    echo -e "\${BLUE}🧪 Test:\${NC} \${RED}FAILED\${NC}"
fi

echo ""
echo "Commands:"
echo "  /opt/etc/init.d/S56dnsmasq restart - перезапуск"
echo "  tail -f /opt/var/log/dnsmasq.log   - мониторинг"

if [ "${DASHBOARD_PORT}" != "53" ]; then
    echo ""
    echo -e "\${YELLOW}ℹ INFO: dnsmasq работает на порту ${DASHBOARD_PORT}\${NC}"
    echo -e "\${YELLOW}  Причина: порт 53 занят (вероятно ndnproxy)\${NC}"
    echo -e "\${YELLOW}  Настройте Keenetic использовать 192.168.1.2 как DNS\${NC}"
fi
EOFDASH

chmod +x /opt/bin/dns-status

echo -e "${GREEN}✓ dns-status создан${NC}"
echo ""

# ================================================================
# Запуск dnsmasq
# ================================================================
echo -e "${YELLOW}► Запуск dnsmasq...${NC}"

/opt/etc/init.d/S56dnsmasq start

sleep 2

if pgrep dnsmasq >/dev/null; then
    echo -e "${GREEN}✓ dnsmasq запущен${NC}"
else
    echo -e "${YELLOW}⚠ dnsmasq не запущен, проверьте логи${NC}"
fi

echo ""

# ================================================================
# Автоматическая настройка DNS в Keenetic
# ================================================================
echo -e "${YELLOW}► Автоматическая настройка DNS в Keenetic...${NC}"

if command -v ndmc >/dev/null 2>&1; then
    echo "  Настройка через ndmc..."
    
    # Попытка настроить DNS через ndmc
    ndmc -c "interface Broadband0" -c "ip name-server 192.168.1.2" >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  ✓ DNS настроен автоматически${NC}"
    else
        echo -e "${YELLOW}  ⚠ Не удалось добавить через ndmc${NC}"
        echo "    Настройте вручную через веб-интерфейс"
    fi
else
    echo -e "${YELLOW}  ⚠ ndmc не найден${NC}"
    echo "    Настройте вручную через веб-интерфейс"
fi

echo ""

# ================================================================
# Финальная проверка
# ================================================================
echo -e "${YELLOW}► Финальная проверка...${NC}"

# Проверка порта
if netstat -ln | grep -q "192.168.1.2:${DNSMASQ_PORT}"; then
    echo -e "${GREEN}✓ Порт ${DNSMASQ_PORT} слушается${NC}"
else
    echo -e "${YELLOW}✗ Порт не слушается${NC}"
fi

# Тест DNS
DNS_TEST=$(dig @192.168.1.2 -p ${DNSMASQ_PORT} google.com +short 2>/dev/null | head -1)

if [ -n "$DNS_TEST" ]; then
    echo -e "${GREEN}✓ DNS тест: google.com → ${DNS_TEST}${NC}"
else
    echo -e "${YELLOW}⚠ DNS тест не прошел${NC}"
fi

echo ""

# ================================================================
# Итоговая информация
# ================================================================
echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Настройка завершена!                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}✅ DNS сервер: 192.168.1.2:${DNSMASQ_PORT}${NC}"
echo -e "${GREEN}✅ Автозапуск: настроен${NC}"
echo -e "${GREEN}✅ Cron: настроен${NC}"

if [ "$DNSMASQ_PORT" != "53" ]; then
    echo ""
    echo -e "${YELLOW}⚠ ВАЖНО: dnsmasq использует порт ${DNSMASQ_PORT}${NC}"
    echo -e "${YELLOW}  Причина: порт 53 занят встроенным DNS (ndnproxy)${NC}"
    echo ""
    echo -e "${BLUE}📋 Настройка Keenetic:${NC}"
    echo "  1. Откройте: http://192.168.1.1"
    echo "  2. Интернет → Подключения → Ваше подключение"
    echo "  3. DNS 1: 192.168.1.2"
    echo "  4. DNS 2: 8.8.8.8 (резервный)"
    echo ""
    echo -e "${BLUE}  ndnproxy (порт 53) → dnsmasq (порт ${DNSMASQ_PORT})${NC}"
fi

echo ""
exit 0
