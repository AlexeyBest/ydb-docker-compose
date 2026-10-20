# YDB + Prometheus + Grafana — локальный стенд

> **⚠️ Только для ознакомления**
> Этот стенд предназначен исключительно для знакомства с функциональностью YDB и её мониторинга. Он **не подходит** для промышленного использования, нагрузочного тестирования или хранения реальных данных.

---

## Что запускается

| Сервис | Образ | Порт | Назначение |
|---|---|---|---|
| **YDB** | `ydbplatform/local-ydb:latest` | `2136` (gRPC), `2135` (gRPC TLS), `8765` (Web UI) | База данных |
| **Prometheus** | `prom/prometheus:latest` | `9090` | Сбор метрик из YDB |
| **Grafana** | `grafana/grafana:latest` | `3000` | Визуализация метрик |

Все три сервиса объединены в одну Docker-сеть `monitoring`. Prometheus собирает метрики с эндпоинтов YDB каждые 15 секунд, Grafana использует Prometheus как источник данных и автоматически подгружает дашборды из директории [`grafana/dashboards/`](grafana/dashboards/).

---

## Требования

- [Docker](https://docs.docker.com/get-docker/) ≥ 24
- [Docker Compose](https://docs.docker.com/compose/install/) ≥ 2.20
- `curl` и `jq` — для скрипта обновления дашбордов

---

## Запуск

### 1. Клонировать репозиторий

```bash
git clone <url-репозитория>
cd ydb-docker
```

### 2. Запустить стек

```bash
docker compose up -d
```

Контейнеры поднимаются в следующем порядке: YDB → Prometheus → Grafana.  
YDB проходит health-check (порт `2136`) до того, как Prometheus начнёт с ней работать.

### 3. Проверить состояние

```bash
docker compose ps
```

Все три сервиса должны иметь статус `running` / `healthy`.

### 4. Открыть интерфейсы

| Сервис | URL | Логин / Пароль |
|---|---|---|
| YDB Web UI | http://localhost:8765 | — |
| Prometheus | http://localhost:9090 | — |
| Grafana | http://localhost:3000 | `admin` / `admin` |

> При первом входе в Grafana система попросит сменить пароль — это можно пропустить для локального стенда.

---

## Остановка и очистка

**Остановить контейнеры** (данные сохраняются в Docker volumes):

```bash
docker compose down
```

**Удалить контейнеры вместе со всеми данными**:

```bash
docker compose down -v
```

---

## Обновление дашбордов Grafana

Дашборды хранятся в директории [`grafana/dashboards/`](grafana/dashboards/) и берутся из официального репозитория [ydb-platform/ydb](https://github.com/ydb-platform/ydb) (ветка `main`, путь `ydb/deploy/helm/ydb-prometheus/dashboards`).

Для обновления дашбордов до актуальной версии выполните скрипт:

```bash
bash scripts/download-dashboards.sh
```

Скрипт:
1. Обращается к GitHub API и получает список JSON-файлов дашбордов.
2. Скачивает каждый файл в [`grafana/dashboards/`](grafana/dashboards/).
3. Выводит прогресс и финальный путь к файлам.

После скачивания перезапустите стек, чтобы Grafana подхватила обновлённые файлы:

```bash
docker compose restart grafana
```

### Если превышен лимит запросов к GitHub API

Без авторизации GitHub API допускает 60 запросов в час. При ошибке `403` передайте токен через переменную окружения:

```bash
GITHUB_TOKEN=your_token bash scripts/download-dashboards.sh
```

Токен можно создать в настройках GitHub: **Settings → Developer settings → Personal access tokens** (достаточно без каких-либо разрешений — только для публичных репозиториев).

---

## Структура проекта

```
.
├── docker-compose.yml                  # Описание стека
├── prometheus/
│   └── prometheus.yml                  # Конфигурация scrape-задач
├── grafana/
│   ├── dashboards/                     # JSON-файлы дашбордов
│   └── provisioning/
│       ├── datasources/
│       │   └── prometheus.yml          # Источник данных Prometheus
│       └── dashboards/
│           └── dashboards.yml          # Настройки автозагрузки дашбордов
├── scripts/
│   └── download-dashboards.sh          # Скрипт обновления дашбордов
├── ydb_certs/                          # TLS-сертификаты YDB
└── ydb_data/                           # Данные YDB (pdisks, конфиги)
```

---

## Метрики YDB в Prometheus

Prometheus собирает метрики по нескольким `job`-ам, каждый из которых соответствует отдельной подсистеме YDB:

| Job | Путь метрик | Подсистема |
|---|---|---|
| `ydb_ydb` | `/counters/counters=ydb/...` | Основные метрики БД |
| `ydb_tablets` | `/counters/counters=tablets/...` | Таблетки |
| `ydb_kqp` | `/counters/counters=kqp/...` | Query Processor |
| `ydb_grpc` | `/counters/counters=grpc/...` | gRPC-слой |
| `ydb_pdisks` | `/counters/counters=pdisks/...` | Physical Disks |
| `ydb_vdisks` | `/counters/counters=vdisks/...` | Virtual Disks |
| `ydb_proxy` | `/counters/counters=proxy/...` | Прокси |
| `ydb_coordinator` | `/counters/counters=coordinator/...` | Координатор |

Все метрики доступны напрямую через Prometheus UI: http://localhost:9090/targets
