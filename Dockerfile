FROM elixir

RUN mix local.hex --force
RUN mix local.rebar --force

COPY mix.exs mix.lock /app/
COPY config /app/config
WORKDIR /app

RUN mix deps.get --only prod
RUN mix deps.compile

COPY . /app
RUN mix compile

CMD elixir --sname server -S mix run --no-halt
