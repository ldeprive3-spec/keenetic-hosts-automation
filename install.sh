#!/bin/sh

# ================================================================
# Keenetic DNS Automation - Main Installer
# GitHub: https://github.com/ldeprive3-spec/keenetic-hosts-automation
# Version: 1.0
# ================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO_URL="https://raw.githubusercontent.com/ldeprive3-spec/keenetic-hosts-automation/main"
TEMP_DIR="/tmp/keenetic-dns-setup"

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Keenetic DNS Automation Installer            ║${NC}"
echo -e "${BLUE}║  GitHub: ldeprive3-spec/keenetic-hosts         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# ================================================================
# Проверка root прав
# ================================================================
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}✗ Требуются права root!${NC}"
    echo "Запустите: sudo $0 или выполните от root"
    exit 1
fi

echo -e "${GREEN}✓ Права root: OK${NC}"

# ================================================================
# Проверка Entware
# ================================================================
if [ ! -d "/opt/etc" ] || [ ! -f "/opt/bin/opkg" ]; then
    echo -e "${RED}✗ Entware не установлен!${NC}"
    echo ""
    echo "Установите Entware:"
    echo "1. Веб-интерфейс Keenetic → Управление → Общие настройки"
    echo "2. Изменить набор компонентов → Система OPKG"
    echo "3. Подключите USB накопитель"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ Entware: установлен${NC}"

# ================================================================
# Установка curl/wget
# ================================================================
echo ""
echo -e "${YELLOW}► Проверка инструментов загрузки...${NC}"

if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    echo "  Установка curl..."
    opkg update >/dev/null 2>&1
    opkg install curl >/dev/null 2>&1
fi

# Определение команды загрузки
if command -v curl >/dev/null 2>&1; then
    DOWNLOAD_CMD="curl -fsSL"
    echo -e "${GREEN}✓ Использую: curl${NC}"
elif command -v wget >/dev/null 2>&1; then
    DOWNLOAD_CMD="wget -qO-"
    echo -e "${GREEN}✓ Использую: wget${NC}"
else
    echo -e "${RED}✗ Не удалось установить curl/wget${NC}"
    exit 1
fi

# ================================================================
# Создание временной директории
# ================================================================
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR" || exit 1

# ================================================================
# Загрузка скриптов из GitHub
# ================================================================
echo ""
echo -e "${YELLOW}► Загрузка скриптов из GitHub...${NC}"

echo "  Загрузка setup-dnsmasq-custom.sh..."
$DOWNLOAD_CMD "${REPO_URL}/setup-dnsmasq-custom.sh" > setup-dnsmasq-custom.sh 2>/dev/null
if [ $? -eq 0 ] && [ -s setup-dnsmasq-custom.sh ]; then
    chmod +x setup-dnsmasq-custom.sh
    echo -e "  ${GREEN}✓ setup-dnsmasq-custom.sh загружен${NC}"
else
    echo -e "  ${RED}✗ Ошибка загрузки setup-dnsmasq-custom.sh${NC}"
    exit 1
fi

echo "  Загрузка update-hosts-auto.sh..."
$DOWNLOAD_CMD "${REPO_URL}/update-hosts-auto.sh" > update-hosts-auto.sh 2>/dev/null
if [ $? -eq 0 ] && [ -s update-hosts-auto.sh ]; then
    chmod +x update-hosts-auto.sh
    echo -e "  ${GREEN}✓ update-hosts-auto.sh загружен${NC}"
else
    echo -e "  ${RED}✗ Ошибка загрузки update-hosts-auto.sh${NC}"
    exit 1
fi

# ================================================================
# Запуск основного установщика
# ================================================================
echo ""
echo -e "${YELLOW}► Запуск основного установщика...${NC}"
echo ""

./setup-dnsmasq-custom.sh

SETUP_EXIT_CODE=$?

# ================================================================
# Копирование скрипта обновления
# ================================================================
if [ $SETUP_EXIT_CODE -eq 0 ]; then
    echo ""
    echo -e "${YELLOW}► Копирование скрипта обновления...${NC}"
    cp -f update-hosts-auto.sh /opt/etc/update-hosts-auto.sh
    chmod +x /opt/etc/update-hosts-auto.sh
    echo -e "${GREEN}✓ Скрипт обновления установлен${NC}"
fi

# ================================================================
# Очистка
# ================================================================
cd /
rm -rf "$TEMP_DIR"

# ================================================================
# Итоговая информация
# ================================================================
if [ $SETUP_EXIT_CODE -eq 0 ]; then
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         Установка успешно завершена!          ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}🎉 Все сервисы настроены и запущены!${NC}"
    echo ""
    echo -e "${YELLOW}📊 Команды управления:${NC}"
    echo "   dns-status                          - показать статус"
    echo "   /opt/etc/init.d/S56dnsmasq restart  - перезапустить DNS"
    echo "   /opt/etc/update-hosts-auto.sh       - обновить hosts"
    echo "   tail -f /opt/var/log/dnsmasq.log    - мониторинг логов"
    echo ""
    echo -e "${GREEN}✅ DNS сервер доступен по адресу: 192.168.1.2${NC}"
    echo ""
    echo "Запустите 'dns-status' для проверки!"
    echo ""
else
    echo ""
    echo -e "${RED}✗ Установка завершилась с ошибками${NC}"
    echo "Проверьте логи: cat /opt/var/log/dnsmasq.log"
    exit 1
fi

exit 0
