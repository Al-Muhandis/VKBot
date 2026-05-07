# VKBot RT — обёртка для VK-ботов на FreePascal/Lazarus

`vkbot_rt` — runtime-пакет для создания ботов ВКонтакте на FreePascal/Lazarus.
Библиотека покрывает два основных сценария:

- **Long Poll API** (бот сам опрашивает VK API);
- **Callback API / Webhook** (ваш HTTP-сервер принимает события от VK).

## Что есть в репозитории

- `src/vkbotframework.pas` — базовый класс `TVKBot`, обработка команд/событий, отправка сообщений, клавиатуры.
- `src/vkwebhook.pas` — процессор webhook-запросов (`TVKWebhookProcessor`) с валидацией `secret` и `group_id`.
- `src/vktypes.pas` — типы событий, уровни логирования, константы API и структуры ответов webhook.
- `examples/longpoll` — пример консольного бота в режиме Long Poll.
- `examples/webhook` — примеры интеграции с `fpWeb` и Brook.
- `tests` — unit- и интеграционные тесты на `fpcunit`.

## Возможности

### 1) Команды и маршрутизация сообщений

- Регистрация команд через `CommandHandlers['start'] := @Handler;`
- Поддержка аргументов команды (`/echo привет мир` → массив аргументов).
- Дополнительные «глобальные» обработчики сообщений (`AddMessageHandler`).

### 2) Обработчики событий VK

- Enum `TVKEventType` для типизированной подписки на события (например `etWallPostNew`).
- Поддержка подписки как по enum, так и по имени события.

### 3) Отправка, редактирование и удаление сообщений

- Отправка через `SendMessage` и методы `TVKMessage.Reply/Send`.
- Редактирование через `EditMessage`.
- Удаление через `DeleteMessage` (VK API `messages.delete`, есть перегрузка для одного и нескольких `message_id`, опционально `delete_for_all`).
- Построитель клавиатур `TVKKeyboard`:
  - кнопки с цветами (`primary`, `secondary`, `negative`, `positive`),
  - payload,
  - новые строки,
  - one_time и inline.

### 4) Webhook-обработка

- `TVKWebhookProcessor.ProcessWebhook`:
  - разбирает JSON,
  - отвечает на `confirmation`,
  - валидирует `secret` и `group_id`,
  - передаёт событие в `TVKBot.ProcessUpdate`,
  - возвращает HTTP-статус и текст (`ok`/ошибка).

---

## Быстрый старт (Long Poll)

Минимальная схема:

1. Создать экземпляр `TVKBot` с токеном сообщества и `group_id`.
2. Зарегистрировать обработчики команд.
3. При необходимости подключить логирование (`OnLog`).
4. Вызвать `Start`.

Смотрите рабочий пример: `examples/longpoll/VKBotExample.pas`.

### Пример регистрации команд

```pascal
_Bot := TVKBot.Create('YOUR_TOKEN_HERE', 123456789);
_Bot.CommandHandlers['start'] := @_Handler.OnStart;
_Bot.CommandHandlers['help'] := @_Handler.OnHelp;
_Bot.CommandHandlers['echo'] := @_Handler.OnEcho;
_Bot.Start;
```

## Быстрый старт (Webhook)

Библиотека не привязана к одному web-фреймворку. В репозитории есть два примера:

- `examples/webhook/vkbot_fpweb_demo.pas`
- `examples/webhook/vkbot_brook_demo.pas`

Общая схема:

1. Создать `TVKBot`.
2. Создать `TVKWebhookProcessor` с confirmation-кодом и secret.
3. В HTTP-обработчике передавать body запроса в `ProcessWebhook`.
4. Вернуть в HTTP-ответ:
   - `Code := result.HTTPStatus`
   - `Content := result.Content`

---

## Подключение в Lazarus

1. Откройте пакет `vkbot_rt.lpk` в Lazarus.
2. Подключите к проекту.
3. Укажите юниты:

```pascal
uses VKTypes, VKBotFramework, VKWebhook;
```

## Логирование

Используйте событие `OnLog` в `TVKBot` (и/или у `TVKWebhookProcessor`) для вывода диагностических сообщений. Уровни:

## Тесты

В репозитории есть:

- тесты сообщений и клавиатур,
- тесты обработки команд и событий,
- тесты API-вызовов,
- webhook-тесты.

## Ограничения и заметки

- Реализация ориентирована на актуальную версию VK API, заданную константой `VK_API_VERSION` (в исходниках сейчас `5.199`).
- Для работы webhook необходимо корректно настроить Callback API в панели сообщества VK
  (URL, confirmation code, secret).

## Лицензия

MIT (см. файл `LICENSE`).
