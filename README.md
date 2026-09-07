# tg-web-proxy
## Требования
Свяжите домен или поддомен с A-записью на IPv4 вашего VPS.
Если домен добавлен Cloudflare / DNS: Запись поддомена должна быть строго в режиме DNS only (серое облако). Проксирование Cloudflare (WAF/Challenge) блокирует скрытые фоновые запросы WebView.
## 🔥 Автоматическая установка (Быстрый старт)

Вы можете развернуть всю инфраструктуру автоматически с помощью готового bash-скрипта. Подключитесь к вашему серверу по SSH (например, ssh root@ваш_ip) и выполните следующие шаги:
```bash
# Скачиваем скрипт
wget https://raw.githubusercontent.com/Kaprojennoe/telegram-web-proxy-setup/main/install.sh

# Делаем скрипт исполняемым
chmod +x install.sh
sudo bash install.sh
```
## 🛠 Ручная установка
### 1. Создайте новый файл скрипта:
```bash
nano install_tg_proxy.sh
```
### 2. Вставьте в него следующий код:
```bash
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
```
(Вставьте код, сохраните через Ctrl+O, Enter, затем выйдите через Ctrl+X)

### Сделайте его исполняемым и запустите:
   ```bash
chmod +x install_tproxy_fixed.sh
sudo bash install_tproxy_fixed.sh
   ```
### Ссылка для подключения имеет стандартный формат Telegram:
```bash
https://t.me/webproxy?server=ВАШ_ДОМЕН&secret=ВАШ_СЕКРЕТ
```
### Узнать свой секрет И ДОБАВИТЬ В НЕГО dd в начале
```bash
sudo grep MTPROXY_SECRET /etc/mtproxy/mtproxy.env | cut -d= -f2
```
### Узнать свой домен
```bash
sudo grep public_hostname /etc/tproxy-server/config.json | awk -F'"' '{print $4}'
```

## Проверка работоспособности
https://ВАШ_ДОМЕН
## Проверка статуса MTProxy
Выполните эту команду, чтобы убедиться, что MTProxy запущен и слушает порт:
```bash
sudo systemctl status mtproxy
```

Должно быть active (running). Затем проверьте, слушает ли он порт:
```bash
sudo ss -lntp | grep 2398
```
```bash
sudo journalctl -u mtproxy --since "10 minutes ago" --no-pager
```
### Проверка логов tproxy-server
Попробуйте подключиться с клиента, а затем сразу выполните:
```bash
sudo journalctl -u tproxy-server --since "2 minutes ago" --no-pager
```
Ищите ошибки или предупреждения. Если видите что-то вроде "bridge not found" или "session creation failed" — это укажет на проблему.
### Проверка firewall
Убедитесь, что firewall не блокирует внутренние порты:
```bash
sudo nft list table inet tproxy_backend
```
Также проверьте, что порты 2398, 8888, 8080, 8081 не слушаются на внешнем интерфейсе (должны слушаться только на 127.0.0.1):
```bash
sudo ss -lntp
```
### Проверка секрета и профиля
Посмотрите, какой секрет используется в профиле:
```bash
sudo cat /etc/tproxy-server/profiles.json
```
И какой секрет передается MTProxy:
```bash
sudo cat /etc/mtproxy/mtproxy.env
```
Убедитесь, что в profiles.json секрет совпадает с тем, что вы используете в клиенте (без префикса dd, если он есть в mtproxy.env — установщик автоматически убирает dd для бэкенда).
### Проверка bridge capability
Откройте в браузере (не в Telegram!) эту ссылку, подставив ваш реальный секрет:

https://ВАШ_ДОМЕН/?bridge=dd0123456789abcdef0123456789abcdef

Если вы видите ту же страницу "Welcome" — это нормально (bridge не должен быть доступен без правильной capability). Если видите ошибку или что-то другое — это укажет на проблему.

## Исправление прав доступа
   
### Дадим права на выполнение для всех пользователей
```bash
sudo chmod 755 /opt/MTProxy/objs/bin/mtproto-proxy
```
### Проверим права на директории
```bash
sudo chmod 755 /opt/MTProxy
sudo chmod 755 /opt/MTProxy/objs
sudo chmod 755 /opt/MTProxy/objs/bin
```
### Проверим, что пользователь mtproxy может зайти в рабочую директорию
```bash
sudo chown -R root:root /opt/MTProxy
```
### Перезапустим сервис
```bash
sudo systemctl daemon-reload
sudo systemctl restart mtproxy
sudo systemctl status mtproxy --no-pager
```
   
### Проверка результата
После выполнения этих команд MTProxy должен запуститься. Проверьте статус:
```bash
sudo systemctl status mtproxy --no-pager
```
### Проверка статуса всех сервисов:
```bash
sudo systemctl status caddy mtproxy tproxy-server
```
### Мониторинг логов в реальном времени (если вдруг что-то пойдет не так):
```bash
sudo journalctl -u tproxy-server -f
```
### Безопасное обновление прокси до новой версии (когда она выйдет):
```bash
cd /tmp/tproxy-server && sudo ./deploy/update-relay.sh
```
