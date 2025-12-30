# Microservices Architecture Demo

**Author:** xlurr

---

## Описание

Этот проект демонстрирует микросервисную архитектуру, в которой **все межсервисные взаимодействия происходят ТОЛЬКО через API Gateway (Nginx)**.

Сервисы **не общаются напрямую** друг с другом. Gateway выступает как **единая точка входа** и **балансировщик нагрузки**.

---

## Architecture Overview

```
Client
  |
  v
API Gateway (Nginx)
  |
  |----> users-service ----> users-db
  |
  |----> orders-service (replica 1) ----\
  |                                      > orders-db
  |----> orders-service (replica 2) ----/
  |
  |----> payments-service ----> payments-db
  |
  |----> delivery-service ----> delivery-db
```

---

## Ключевые принципы

- Отсутствие прямых вызовов между сервисами
- Весь HTTP-трафик проходит через API Gateway
- Балансировка нагрузки выполняется Nginx
- Orders-сервис работает в нескольких репликах
- У каждого сервиса своя собственная база данных

---

## Взаимодействие сервисов

Каждый сервис использует переменную окружения:

```
GATEWAY_URL=http://api-gateway
```

### Пример: users-service → orders-service

```
users-service
    |
    | HTTP-запрос:
    | http://api-gateway/api/orders/user/{id}
    |
    v
API Gateway (Nginx)
    |
    | балансировка нагрузки
    |
    v
orders-service (реплика)
```

Вся логика маршрутизации и балансировки выполняется **на стороне Nginx**, а не в коде сервисов.

---

## Балансировка нагрузки

Orders-сервис запущен в нескольких экземплярах:

- orders-service-1
- orders-service-2

Nginx автоматически распределяет входящие запросы между репликами.

---

## Демонстрационный скрипт

**Файл:** showbalance.sh (корень проекта)

**Назначение:**

- Отправляет несколько запросов через API Gateway
- Показывает, какая реплика orders-service обработала запрос

**Использование:**

```
chmod +x showbalance.sh
./showbalance.sh
```

**Пример вывода:**

```
Request 1 -> instance-1
Request 2 -> instance-2
Request 3 -> instance-1
Request 4 -> instance-2
```

---

## Запуск проекта

```
docker-compose up --build
```

---

## Итог

Проект наглядно демонстрирует:

- Паттерн API Gateway
- Централизованную маршрутизацию
- Балансировку нагрузки
- Изоляцию сервисов
- Микросервисную архитектуру
