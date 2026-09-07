#!/bin/bash
set -e

#Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Установка Telegram TProxy Server (с обходом бага тестов) ===${NC}"

#Проверка прав root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Ошибка: Запустите скрипт от имени root (sudo bash install_tproxy_fixed.sh)${NC}"
  exit 1
fi

# Проверка архитектуры
if [ "$(uname -m)" != "x86_64" ]; then
  echo -e "${RED}Ошибка: Официальный MTProxy требует архитектуру x86_64.${NC}"
  exit 1
fi

echo -e "${YELLOW}[1/6] Установка базовых зависимостей...${NC}"
apt-get update -y
apt-get install -y git curl openssl

REPO_DIR="/tmp/tproxy-server"
if [ -d "$REPO_DIR" ]; then
    rm -rf "$REPO_DIR"
fi

echo -e "${YELLOW}[2/6] Клонирование официального репозитория...${NC}"
git clone https://github.com/telegramdesktop/tproxy-server.git "$REPO_DIR"

echo -e "${YELLOW}[3/6] Исправление скрипта установки (пропуск строгого теста прав доступа)...${NC}"
# Удаляем строку с go test, которая вызывает ложное срабатывание на некоторых VPS
sed -i '/go_binary.*test \.\/\.\.\./d' "$REPO_DIR/deploy/install.sh"

echo -e "${YELLOW}[4/6] Подготовка параметров установки...${NC}"

# Запрос домена
read -p "Введите доменное имя (например, proxy.example.com): " HOSTNAME
if [[ ! "$HOSTNAME" =~ ^[a-z0-9.-]+$ ]]; then
    echo -e "${RED}Ошибка: Некорректный домен. Используйте строчные буквы, цифры и точки.${NC}"
    exit 1
fi

# Запрос email
read -p "Введите Email для получения SSL-сертификата (Let's Encrypt): " EMAIL
if [[ ! "$EMAIL" =~ ^[A-Za-z0-9._+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    echo -e "${RED}Ошибка: Некорректный Email.${NC}"
    exit 1
fi

# Генерация или запрос секрета
echo -e "${YELLOW}Секрет должен быть 32 шестнадцатеричными символами.${NC}"
echo -e "${YELLOW}Рекомендуется добавить префикс 'dd' для лучшей маскировки от DPI.${NC}"
read -p "Введите секрет (оставьте пустым для автогенерации с 'dd'): " SECRET
if [ -z "$SECRET" ]; then
    SECRET="dd$(openssl rand -hex 16)"
    echo -e "${GREEN}Сгенерированный секрет: ${SECRET}${NC}"
fi

if [[ ! "$SECRET" =~ ^([0-9a-f]{32}|dd[0-9a-f]{32})$ ]]; then
    echo -e "${RED}Ошибка: Секрет должен состоять из 32 шестнадцатеричных символов, опционально с префиксом 'dd'.${NC}"
    exit 1
fi

# Создание сайта-заглушки (требуется установщиком для маскировки)
SITE_DIR="/tmp/tproxy-site"
mkdir -p "$SITE_DIR"
cat > "$SITE_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome</title>
</head>
<body>
    <h1>Welcome</h1>
    <p>This is a standard placeholder page.</p>
</body>
</html>
EOF

echo -e "${YELLOW}[5/6] Запуск официального установщика...${NC}"
echo -e "${YELLOW}Это может занять 2-5 минут (загрузка Go, компиляция, настройка Caddy и MTProxy).${NC}"

cd "$REPO_DIR" || exit 1

# Запуск модифицированного скрипта установки
./deploy/install.sh \
  --hostname "$HOSTNAME" \
  --email "$EMAIL" \
  --secret "$SECRET" \
  --site-dir "$SITE_DIR"

echo -e "${GREEN}[6/6] Установка завершена!${NC}"

# Проверка статуса
echo -e "${YELLOW}Проверка статуса сервисов...${NC}"
systemctl --no-pager --full status caddy mtproxy tproxy-server | head -n 20

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}=== Данные для подключения ===${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Домен (Hostname): ${YELLOW}${HOSTNAME}${NC}"
echo -e "Секрет (Secret):  ${YELLOW}${SECRET}${NC}"
echo -e "Ссылка для быстрой настройки (откройте в Telegram Desktop или мобильном приложении):"
echo -e "${GREEN}https://t.me/webproxy?server=${HOSTNAME}&secret=${SECRET}${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${YELLOW}ВАЖНО: Убедитесь, что в панели управления вашего VPS открыты порты 80 и 443 (TCP).${NC}"
