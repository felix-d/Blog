---
title: "Dockerizing Phoenix"
date: 2018-02-18T12:56:42-05:00
draft: false
tags: ["docker", "phoenix", "elixir"]
---

As I dabble more and more with [Elixir](https://elixir-lang.org/) and
[Phoenix](http://phoenixframework.org/), I was looking into an efficient way to
Dockerize Phoenix applications. Although they are not totally incompatible in
practice, using Docker makes sense if you don't rely on hot code upgrades.

I wanted my containers to use a base [Alpine](https://hub.docker.com/_/alpine/)
image and [Distillery](https://github.com/bitwalker/distillery) releases to be
as lightweight as possible.

I ended up leveraging [multi-stage
builds](https://docs.docker.com/develop/develop-images/multistage-build/) to
write my Dockerfile. It uses three different stages. The first stage compile
assets using [Yarn](https://yarnpkg.com/en/) [^yarn], the second one builds the
Distillery release and the third one contains the release.

Note that the image building the Distillery release need to run on the same OS as the one running the release.

Here's the Dockerfile I use for my Phoenix projects. I use a similar one for
plain Elixir projects, but as you would have probably guessed, I simply remove
the assets compilation stage.

[^yarn]: You could use a similar approach with [NPM](https://www.npmjs.com/).

{{< highlight docker >}}
# Assets compilation
FROM aparedes/alpine-node-yarn as node

## Node modules
COPY ./deps /tmp/deps
COPY ./assets/package.json /tmp/deps
COPY ./assets/yarn.lock /tmp/deps
WORKDIR /tmp/deps
RUN yarn

## Assets compilation
COPY ./assets /tmp/assets
RUN cp -R /tmp/deps/node_modules /tmp/assets
WORKDIR /tmp/assets
RUN ./node_modules/.bin/brunch build --production

# Distillery release
FROM bitwalker/alpine-elixir as distillery

COPY . /app
COPY --from=node /tmp/priv/static /app/priv/static

WORKDIR /app

ENV MIX_ENV prod
RUN sed -n 's/ *app: :\([a-z_]*\),/\1/p' mix.exs > APP_NAME
RUN sed -n 's/ *version: "\([0-9\.]*\)",/\1/p' mix.exs > APP_VERSION

RUN mix deps.get && mix phx.digest && mix release
RUN mkdir target
RUN APP_VERSION=$(cat APP_VERSION) APP_NAME=$(cat APP_NAME) \
  sh -c 'tar xzf ./_build/prod/rel/$APP_NAME/releases/$APP_VERSION/$APP_NAME.tar.gz -C ./target'

# Final image
FROM alpine:latest

ENV APP_SECRET=secret REPLACE_OS_VARS=1 PORT=4000 SNAME=web ERLANG_COOKIE=secret

RUN apk add --update openssl bash && \
    rm -rf /var/cache/apk/*

COPY bin/start app/start
COPY rel/vm.args /app
COPY --from=distillery /app/target /app
COPY --from=distillery /app/APP_NAME /app

WORKDIR /app

CMD ./bin/$(cat APP_NAME) foreground
{{< / highlight >}}
