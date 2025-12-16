#!/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}🔧 Установка зависимостей и генерация Swagger${NC}"
echo ""

# Установка swag
if ! command -v swag &> /dev/null; then
    echo "📦 Установка swag CLI..."
    go install github.com/swaggo/swag/cmd/swag@latest
    echo -e "${GREEN}✅ swag установлен${NC}"
else
    echo -e "${GREEN}✅ swag уже установлен${NC}"
fi

SERVICES=("users-service" "orders-service" "payments-service" "delivery-service")

for service in "${SERVICES[@]}"; do
    echo ""
    echo -e "${YELLOW}📝 Обработка $service...${NC}"
    
    if [ ! -d "$service" ]; then
        echo "  ⚠️  Папка $service не найдена, пропускаю..."
        continue
    fi
    
    cd "$service"
    
    # Добавление зависимостей
    echo "  📦 Добавление зависимостей..."
    go get github.com/swaggo/swag/cmd/swag
    go get github.com/swaggo/http-swagger
    go get github.com/gorilla/mux
    go get github.com/lib/pq
    go mod tidy
    
    # Генерация Swagger
    echo "  📚 Генерация Swagger документации..."
    swag init -g cmd/main.go --output docs
    
    # Проверка
    if [ -d "docs" ]; then
        echo -e "  ${GREEN}✅ Swagger документация создана${NC}"
        ls -la docs/
    else
        echo "  ❌ Ошибка: папка docs не создана"
    fi
    
    cd ..
done

echo ""
echo -e "${GREEN}🎉 Готово!${NC}"
echo ""
echo "Swagger UI будет доступен по адресам:"
echo "  - Users:     http://localhost:8001/swagger/index.html"
echo "  - Orders:    http://localhost:8002/swagger/index.html"
echo "  - Payments:  http://localhost:8004/swagger/index.html"
echo "  - Deliveries: http://localhost:8005/swagger/index.html"
echo ""
echo "Теперь пересоберите контейнеры:"
echo "  docker-compose down"
echo "  docker-compose build --no-cache"
echo "  docker-compose up -d"
