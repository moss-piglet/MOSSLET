# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian
# instead of Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?page=1&name=ubuntu
# https://hub.docker.com/_/ubuntu?tab=tags
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://hub.docker.com/_/debian?tab=tags&page=1&name=bullseye-20230612-slim - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: hexpm/elixir:1.19.4-erlang-28.2-debian-bullseye-20251117-slim
#
ARG ELIXIR_VERSION=1.19.4
ARG OTP_VERSION=28.2
ARG DEBIAN_VERSION=bullseye-20251117-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} as builder

# install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git \
  && apt-get install -y libsodium-dev && apt install -y libvips-dev && apt-get clean && rm -f /var/lib/apt/lists/*_*

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# make bumblebee cache dir
RUN mkdir /app/.bumblebee

# set build ENV
ENV MIX_ENV="prod"
ENV BUMBLEBEE_OFFLINE=false
ENV BUMBLEBEE_CACHE_DIR="/app/.bumblebee"

# install mix dependencies
COPY mix.exs mix.lock ./

# install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git nodejs npm \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/

RUN mix deps.compile

COPY priv priv
COPY priv/dict/eff_large_wordlist.txt priv/dict/eff_large_wordlist.txt

COPY lib lib

COPY assets assets

# compile assets
RUN mix assets.deploy

# Compile the release
RUN mix compile
# RUN mix run -e 'Mosslet.Application.load_serving()' --no-start
# RUN /bin/mosslet eval 'Mosslet.Application.load_serving()'

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && apt-get install -y libstdc++6 openssl libncurses5 libsodium-dev locales \
  && apt install -y libvips-dev libheif-examples && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8
ENV ECTO_IPV6 true
ENV ERL_AFLAGS "-proto_dist inet6_tcp"

WORKDIR "/app"
RUN chown nobody /app

ENV BUMBLEBEE_CACHE_DIR="/app/.bumblebee"

# set runner ENV
ENV MIX_ENV="prod"
ENV BUMBLEBEE_OFFLINE=true


# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/mosslet ./
COPY --from=builder --chown=nobody:root /app/.bumblebee/ ./.bumblebee

USER nobody

CMD ["/app/bin/server"]