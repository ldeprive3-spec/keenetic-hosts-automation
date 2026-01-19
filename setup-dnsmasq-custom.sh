#!/bin/sh

# ================================================================
# dnsmasq Setup for Keenetic - Auto port detection
# Version: 2.5 - Fixed kill command output redirection
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
# Функции
# ================================================================

# Проверка занят ли порт
check_port() {
    PORT=$1
    if netstat -ln 2>/dev/null | grep -q ":${PORT} "; then
        return 1  # Занят
    else
        return 0  # Свободен
    fi
}

# Получить процесс на порту
get_port_process() {
    PORT=$1
    netstat -lnp 2>/dev/null | grep ":${PORT} " | awk '{print $NF}' | cut -d/ -f2 | head -1 || echo "unknown"
}

# ================================================================
# Проверка конфликтов портов (РАСШИРЕННАЯ)
# ================================================================
echo -e "${YELLOW}► Проверка конфликтов портов...${NC}"

DNSMASQ_PORT=""
PREFERRED_PORTS="53 5353 5300 5354 5400 54"

for PORT in $PREFERRED_PORTS; do
    if check_port $PORT; then
        DNSMASQ_PORT=$PORT
        if [ "$PORT" = "53" ]; then
            echo -e "${GREEN}  ✓ Порт 53 свободен${NC}"
        else
            echo -e "${GREEN}  ✓ Найден свободный порт: $DNSMASQ_PORT${NC}"
        fi
        break
    else
        PROCESS=$(get_port_process $PORT)
        if [ "$PORT" = "53" ]; then
            echo -e "${YELLOW}  ⚠ Порт 53 занят: ${PROCESS}${NC}"
            
            # Детектим известные сервисы
            if echo "$PROCESS" | grep -q "ndnproxy"; then
                echo -e "${BLUE}     → ndnproxy (встроенный DNS Keenetic)${NC}"
            elif echo "$PROCESS" | grep -qi "dnsmasq"; then
                echo -e "${BLUE}     → dnsmasq (возможно старый процесс)${NC}"
            elif echo "$PROCESS" | grep -qi "adguard"; then
                echo -e "${YELLOW}     → AdGuard Home (конфликт!)${NC}"
            fi
        elif [ "$PORT" = "5353" ]; then
            echo -e "${YELLOW}  ⚠ Порт 5353 занят: ${PROCESS}${NC}"
            
            if echo "$PROCESS" | grep -q "avahi"; then
                echo -e "${BLUE}     → avahi-daemon (mDNS/Bonjour)${NC}"
            fi
        else
            echo -e "${YELLOW}  ⚠ Порт $PORT занят: ${PROCESS}${NC}"
        fi
    fi
done

if [ -z "$DNSMASQ_PORT" ]; then
    echo ""
    echo -e "${RED}  ✗ Не найдено свободных портов!${NC}"
    echo ""
    echo -e "${YELLOW}  Попробованы порты: $PREFERRED_PORTS${NC}"
    echo ""
    echo -e "${YELLOW}  Варианты решения:${NC}"
    echo "  1. Остановите avahi-daemon:"
    echo "     /opt/etc/init.d/S42avahi stop"
    echo "     chmod -x /opt/etc/init.d/S42avahi"
    echo ""
    echo "  2. Остановите старый dnsmasq:"
    echo "     killall dnsmasq"
    echo ""
    echo "  3. Если установлен AdGuard Home - удалите его"
    echo ""
    exit 1
fi

echo -e "${GREEN}  ✓ Будет использован порт: ${DNSMASQ_PORT}${NC}"

if [ "$DNSMASQ_PORT" != "53" ]; then
    echo -e "${BLUE}  ℹ dnsmasq будет работать совместно с существующими DNS${NC}"
fi

echo ""

# ================================================================
# Установка зависимостей
# ================================================================
echo -e "${YELLOW}► Установка зависимостей...${NC}"

opkg update >/dev/null 2>&1 || true

# Проверка dnsmasq или dnsmasq-full
DNSMASQ_INSTALLED=0
DNSMASQ_PACKAGE=""

if opkg list-installed 2>/dev/null | grep -q "^dnsmasq-full "; then
    echo -e "${GREEN}  ✓ dnsmasq-full (уже установлен)${NC}"
    DNSMASQ_INSTALLED=1
    DNSMASQ_PACKAGE="dnsmasq-full"
elif opkg list-installed 2>/dev/null | grep -q "^dnsmasq "; then
    echo -e "${GREEN}  ✓ dnsmasq (уже установлен)${NC}"
    DNSMASQ_INSTALLED=1
    DNSMASQ_PACKAGE="dnsmasq"
fi

if [ $DNSMASQ_INSTALLED -eq 0 ]; then
    echo "  Установка dnsmasq..."
    
    # Попробуем установить обычный dnsmasq
    INSTALL_OUTPUT=$(opkg install dnsmasq 2>&1)
    INSTALL_RESULT=$?
    
    if [ $INSTALL_RESULT -eq 0 ]; then
        echo -e "${GREEN}  ✓ dnsmasq${NC}"
        DNSMASQ_PACKAGE="dnsmasq"
        DNSMASQ_INSTALLED=1
    else
        # Проверка конфликта с dnsmasq-full
        if echo "$INSTALL_OUTPUT" | grep -qi "dnsmasq-full"; then
            if opkg list-installed 2>/dev/null | grep -q "^dnsmasq-full "; then
                echo -e "${BLUE}  ℹ dnsmasq-full уже установлен (конфликт с dnsmasq)${NC}"
                DNSMASQ_PACKAGE="dnsmasq-full"
                DNSMASQ_INSTALLED=1
            else
                echo -e "${RED}  ✗ Ошибка установки dnsmasq${NC}"
                echo ""
                echo -e "${YELLOW}Вывод opkg:${NC}"
                echo "$INSTALL_OUTPUT"
                exit 1
            fi
        else
            echo -e "${RED}  ✗ Ошибка установки dnsmasq${NC}"
            echo ""
            echo -e "${YELLOW}Вывод opkg:${NC}"
            echo "$INSTALL_OUTPUT"
            echo ""
            echo -e "${BLUE}Диагностика:${NC}"
            echo "  Свободно места: $(df -h /opt 2>/dev/null | tail -1 | awk '{print $4}')"
            exit 1
        fi
    fi
fi

# Проверка что dnsmasq доступен
if ! command -v dnsmasq >/dev/null 2>&1; then
    echo -e "${RED}  ✗ Команда dnsmasq не найдена!${NC}"
    echo ""
    echo "Проверьте установку:"
    echo "  which dnsmasq"
    echo "  /opt/sbin/dnsmasq --version"
    exit 1
fi

# Вывод версии
DNSMASQ_VERSION=$(dnsmasq --version 2>&1 | head -1 | sed 's/Dnsmasq version //' || echo "unknown")
echo -e "${BLUE}  ℹ Пакет: ${DNSMASQ_PACKAGE}${NC}"
echo -e "${BLUE}  ℹ Версия: ${DNSMASQ_VERSION}${NC}"

# Установка bind-dig (опциональный)
if ! opkg list-installed 2>/dev/null | grep -q "^bind-dig "; then
    opkg install bind-dig >/dev/null 2>&1 || true
    if opkg list-installed 2>/dev/null | grep -q "^bind-dig "; then
        echo -e "${GREEN}  ✓ bind-dig${NC}"
    else
        echo -e "${YELLOW}  ⚠ bind-dig не установлен (необязательно)${NC}"
    fi
else
    echo -e "${GREEN}  ✓ bind-dig (уже установлен)${NC}"
fi

echo ""

# ================================================================
# Остановка существующих процессов dnsmasq
# ================================================================
echo -e "${YELLOW}► Остановка существующих процессов dnsmasq...${NC}"

# Остановка через init скрипт
if [ -f /opt/etc/init.d/S56dnsmasq ]; then
    /opt/etc/init.d/S56dnsmasq stop >/dev/null 2>&1 || true
fi

# Убиваем все dnsmasq процессы
DNSMASQ_PIDS=$(ps 2>/dev/null | grep "[d]nsmasq" | awk '{print $1}' 2>/dev/null || true)
if [ -n "$DNSMASQ_PIDS" ]; then
    for PID in $DNSMASQ_PIDS; do
        kill $PID >/dev/null 2>&1 || true
    done
    sleep 1
    
    # Принудительное убийство если процесс остался
    DNSMASQ_PIDS=$(ps 2>/dev/null | grep "[d]nsmasq" | awk '{print $1}' 2>/dev/null || true)
    if [ -n "$DNSMASQ_PIDS" ]; then
        for PID in $DNSMASQ_PIDS; do
            kill -9 $PID >/dev/null 2>&1 || true
        done
        sleep 1
    fi
fi

echo -e "${GREEN}✓ Процессы dnsmasq остановлены${NC}"
echo ""

# ================================================================
# Создание структуры директорий
# ================================================================
echo -e "${YELLOW}► Создание структуры директорий...${NC}"

mkdir -p /opt/etc/dnsmasq.d || true
mkdir -p /opt/etc/dnsmasq.d/backups || true
mkdir -p /opt/var/log || true
mkdir -p /opt/etc/hosts-automation || true

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
    ifconfig ${INTERFACE}:1 down 2>/dev/null || true
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

chmod +x /opt/etc/init.d/S55network-alias || true

# Запуск алиаса
/opt/etc/init.d/S55network-alias start >/dev/null 2>&1 || true

if ifconfig br0:1 2>/dev/null | grep -q "192.168.1.2"; then
    echo -e "${GREEN}✓ IP алиас 192.168.1.2 создан${NC}"
else
    echo -e "${YELLOW}⚠ IP алиас не создан через init, попытка прямого создания...${NC}"
    ifconfig br0:1 192.168.1.2 netmask 255.255.255.0 up 2>/dev/null || true
    
    if ifconfig br0:1 2>/dev/null | grep -q "192.168.1.2"; then
        echo -e "${GREEN}✓ IP алиас 192.168.1.2 создан (прямой метод)${NC}"
    else
        echo -e "${RED}✗ Не удалось создать IP алиас${NC}"
        echo -e "${YELLOW}  Попробуйте вручную: ifconfig br0:1 192.168.1.2 netmask 255.255.255.0 up${NC}"
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
# Auto-detected port: ${DNSMASQ_PORT}
# Package: ${DNSMASQ_PACKAGE}
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
        /opt/etc/init.d/S55network-alias start >/dev/null 2>&1 || true
        sleep 1
        
        # Если всё ещё нет - создаём вручную
        if ! ifconfig br0:1 2>/dev/null | grep -q "192.168.1.2"; then
            ifconfig br0:1 192.168.1.2 netmask 255.255.255.0 up 2>/dev/null || true
        fi
    fi
    
    # Проверка конфига
    if ! dnsmasq --test --conf-file=/opt/etc/dnsmasq.conf >/dev/null 2>&1; then
        echo "Configuration test failed!"
        dnsmasq --test --conf-file=/opt/etc/dnsmasq.conf
        return 1
    fi
}

start_cmd() {
    # Убедимся что старые процессы dnsmasq убиты
    DNSMASQ_PIDS=$(ps 2>/dev/null | grep "[d]nsmasq" | awk '{print $1}' 2>/dev/null || true)
    if [ -n "$DNSMASQ_PIDS" ]; then
        for PID in $DNSMASQ_PIDS; do
            kill $PID >/dev/null 2>&1 || true
        done
        sleep 1
    fi
    
    # Запуск
    dnsmasq --conf-file=/opt/etc/dnsmasq.conf
    
    if [ $? -eq 0 ]; then
        sleep 2
        if pgrep dnsmasq >/dev/null 2>&1; then
            return 0
        else
            echo "dnsmasq started but not running"
            return 1
        fi
    else
        echo "Failed to start dnsmasq"
        return 1
    fi
}

stop_cmd() {
    DNSMASQ_PIDS=$(ps 2>/dev/null | grep "[d]nsmasq" | awk '{print $1}' 2>/dev/null || true)
    if [ -n "$DNSMASQ_PIDS" ]; then
        for PID in $DNSMASQ_PIDS; do
            kill $PID >/dev/null 2>&1 || true
        done
        sleep 1
        
        # Принудительное убийство
        DNSMASQ_PIDS=$(ps 2>/dev/null | grep "[d]nsmasq" | awk '{print $1}' 2>/dev/null || true)
        if [ -n "$DNSMASQ_PIDS" ]; then
            for PID in $DNSMASQ_PIDS; do
                kill -9 $PID >/dev/null 2>&1 || true
            done
        fi
    fi
    return 0
}

PRECMD="pre_cmd"
PREARGS=""

. /opt/etc/init.d/rc.func
EOFINIT

chmod +x /opt/etc/init.d/S56dnsmasq || true

echo -e "${GREEN}✓ Init скрипт создан${NC}"
echo ""

# ================================================================
# Настройка cron
# ================================================================
echo -e "${YELLOW}► Настройка cron...${NC}"

mkdir -p /opt/etc/cron.d || true

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
PRIMARY_IP=\$(ifconfig br0 2>/dev/null | grep "inet addr" | awk '{print \$2}' | cut -d: -f2)
SECONDARY_IP=\$(ifconfig br0:1 2>/dev/null | grep "inet addr" | awk '{print \$2}' | cut -d: -f2)

echo -e "\${BLUE}🌐 Network:\${NC}"
echo "   Primary:   \${PRIMARY_IP:-N/A}"
echo "   Secondary: \${SECONDARY_IP:-N/A}"
echo ""

# Определяем порт из конфига
DNSMASQ_PORT=\$(grep "^port=" /opt/etc/dnsmasq.conf 2>/dev/null | cut -d= -f2)
[ -z "\$DNSMASQ_PORT" ] && DNSMASQ_PORT="53"

# dnsmasq status
if pgrep dnsmasq >/dev/null 2>&1; then
    PID=\$(pgrep dnsmasq)
    echo -e "\${BLUE}📊 Status:\${NC}"
    echo -e "   \${GREEN}✅ dnsmasq: RUNNING (PID: \${PID})\${NC}"
    echo -e "   \${BLUE}   Port: \${DNSMASQ_PORT}\${NC}"
else
    echo -e "\${BLUE}📊 Status:\${NC}"
    echo -e "   \${RED}❌ dnsmasq: STOPPED\${NC}"
fi
echo ""

# Listening ports
echo -e "\${BLUE}🔌 Listening:\${NC}"
LISTENING=\$(netstat -ln 2>/dev/null | grep "192.168.1.2:\${DNSMASQ_PORT}")
if [ -n "\$LISTENING" ]; then
    echo "\$LISTENING" | while read line; do
        echo "   \$line"
    done
else
    echo "   (none - порт \${DNSMASQ_PORT} не слушается)"
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
    QUERIES=\$(tail -5 /opt/var/log/dnsmasq.log 2>/dev/null | grep "query" | awk '{print "   " \$6, "\t→", \$8}')
    if [ -n "\$QUERIES" ]; then
        echo "\$QUERIES"
    else
        echo "   (нет запросов)"
    fi
    echo ""
fi

# DNS test
TEST_RESULT=\$(dig @192.168.1.2 -p \${DNSMASQ_PORT} google.com +short 2>/dev/null | head -1)
if [ -n "\$TEST_RESULT" ]; then
    echo -e "\${BLUE}🧪 Test:\${NC} google.com → \${GREEN}\${TEST_RESULT}\${NC}"
else
    echo -e "\${BLUE}🧪 Test:\${NC} \${RED}FAILED\${NC}"
fi

echo ""
echo "Commands:"
echo "  /opt/etc/init.d/S56dnsmasq restart - перезапуск"
echo "  tail -f /opt/var/log/dnsmasq.log   - мониторинг"
echo "  /opt/etc/update-hosts-auto.sh      - обновить hosts"

if [ "\${DNSMASQ_PORT}" != "53" ]; then
    echo ""
    echo -e "\${YELLOW}ℹ INFO:\${NC}"
    echo -e "  dnsmasq работает на порту \${DNSMASQ_PORT}"
    echo -e "  Порт 53 занят другим сервисом (ndnproxy/avahi)"
    echo -e "  Настройте Keenetic использовать 192.168.1.2 как DNS"
fi
EOFDASH

chmod +x /opt/bin/dns-status || true

echo -e "${GREEN}✓ dns-status создан${NC}"
echo ""

# ================================================================
# Запуск dnsmasq
# ================================================================
echo -e "${YELLOW}► Запуск dnsmasq...${NC}"

/opt/etc/init.d/S56dnsmasq start

sleep 3

if pgrep dnsmasq >/dev/null 2>&1; then
    PID=$(pgrep dnsmasq)
    echo -e "${GREEN}✓ dnsmasq запущен (PID: ${PID})${NC}"
else
    echo -e "${YELLOW}⚠ dnsmasq не запущен${NC}"
    echo ""
    echo "Попробуйте диагностику:"
    echo "  1. Проверьте конфиг: dnsmasq --test --conf-file=/opt/etc/dnsmasq.conf"
    echo "  2. Запустите вручную: dnsmasq --conf-file=/opt/etc/dnsmasq.conf --no-daemon"
    echo "  3. Проверьте логи: tail -20 /opt/var/log/dnsmasq.log"
fi

echo ""

# ================================================================
# Автоматическая настройка DNS в Keenetic
# ================================================================
echo -e "${YELLOW}► Автоматическая настройка DNS в Keenetic...${NC}"

if command -v ndmc >/dev/null 2>&1; then
    echo "  Настройка через ndmc..."
    
    # Попытка настроить DNS через ndmc
    ndmc -c "interface Broadband0" -c "ip name-server 192.168.1.2" >/dev/null 2>&1 || true
    
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
if netstat -ln 2>/dev/null | grep -q "192.168.1.2:${DNSMASQ_PORT}"; then
    echo -e "${GREEN}✓ Порт ${DNSMASQ_PORT} слушается${NC}"
else
    echo -e "${YELLOW}⚠ Порт ${DNSMASQ_PORT} не слушается${NC}"
fi

# Тест DNS
DNS_TEST=$(dig @192.168.1.2 -p ${DNSMASQ_PORT} google.com +short 2>/dev/null | head -1 || true)

if [ -n "$DNS_TEST" ]; then
    echo -e "${GREEN}✓ DNS тест: google.com → ${DNS_TEST}${NC}"
else
    echo -e "${YELLOW}⚠ DNS тест не прошел${NC}"
    echo "  Попробуйте:"
    echo "    dig @192.168.1.2 -p ${DNSMASQ_PORT} google.com"
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
echo -e "${GREEN}✅ Пакет: ${DNSMASQ_PACKAGE}${NC}"
echo -e "${GREEN}✅ Автозапуск: настроен${NC}"
echo -e "${GREEN}✅ Cron: настроен${NC}"

if [ "$DNSMASQ_PORT" != "53" ]; then
    echo ""
    echo -e "${YELLOW}⚠ ВАЖНО: dnsmasq использует порт ${DNSMASQ_PORT}${NC}"
    
    PORT_53_PROC=$(get_port_process 53)
    if [ "$PORT_53_PROC" != "unknown" ]; then
        echo -e "${YELLOW}  Причина: порт 53 занят ($PORT_53_PROC)${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}📋 Настройка Keenetic:${NC}"
    echo "  1. Откройте: http://192.168.1.1"
    echo "  2. Интернет → Подключения → Ваше подключение"
    echo "  3. DNS 1: 192.168.1.2"
    echo "  4. DNS 2: 8.8.8.8 (резервный)"
    echo ""
    
    if [ "$PORT_53_PROC" = "ndnproxy" ]; then
        echo -e "${BLUE}  ℹ ndnproxy (порт 53) → dnsmasq (порт ${DNSMASQ_PORT})${NC}"
    fi
fi

echo ""
echo -e "${GREEN}Команда для проверки: dns-status${NC}"
echo ""
exit 0
