# TwitterFeed

Собирает твиты для аккаунтов, указанных в БД. Сначала получает
твиты из timeline аккаунта, затем переключается на
Twitter Streaming API.

## Build

```bash
docker-compose build app
```

## Запуск

Создайте файлик `dev.env` в корне проекта со следующими
переменными:
```bash
TWITTER_CONSUMER_KEY=your-key-goes-here
TWITTER_CONSUMER_SECRET=your-secret-goes-here
# "Your Access Token" в apps.twitter.com
# Нужно сгенерировать после создания приложения
TWITTER_OWNER_TOKEN=your-key-goes-here
TWITTER_OWNER_TOKEN_SECRET=your-secret-goes-here
```

Теперь запускаем.

```bash
docker-compose run --rm app
```

## Тесты

```bash
docker-compose run --rm app mix test
```

## Как указать аккаунты

Аккаунт в БД содержит ID аккаунта. Чтобы узнать ID по
имени пользователя, можно использовать этот
сервис, например - https://tweeterid.com/.

Аккаунты в БД можно занести через `psql` или другие интерфейсы.
Можно указать в файле `priv/repo/seeds.exs` - после этого
необходимо запустить следующую команду:

```bash
docker-compose run --rm app mix ecto.setup
```

В приложении работает координатор, которого можно попросить
обновить аккаунты из БД и начать получение твитов для них
(он и сам обновляет их время от времени).

Для этого нужно отправить ему сообщение `:update`:

```elixir
Process.send(TwitterFeed.Coordinator, :update)
```

В случае успеха появится сообщение, что началась обработка
новых аккаунтов.
