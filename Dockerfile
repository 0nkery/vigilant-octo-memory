FROM elixir

ARG TWITTER_CONSUMER_KEY
ARG TWITTER_CONSUMER_SECRET
ARG TWITTER_OWNER_TOKEN
ARG TWITTER_OWNER_TOKEN_SECRET

RUN mix local.hex --force
RUN mix local.rebar --force

ENV MIX_ENV=prod

COPY mix.exs mix.lock /app/
COPY config /app/config
WORKDIR /app

RUN mix deps.get --only prod
RUN mix deps.compile

COPY . /app
RUN mix compile

CMD elixir --sname server -S mix run --no-halt
