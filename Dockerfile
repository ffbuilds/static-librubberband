
# bump: rubberband /RUBBERBAND_VERSION=([\d.]+)/ https://github.com/breakfastquay/rubberband.git|^2
# bump: rubberband after ./hashupdate Dockerfile RUBBERBAND $LATEST
# bump: rubberband link "CHANGELOG" https://github.com/breakfastquay/rubberband/blob/default/CHANGELOG
# bump: rubberband link "Source diff $CURRENT..$LATEST" https://github.com/breakfastquay/rubberband/compare/$CURRENT..$LATEST
ARG RUBBERBAND_VERSION=2.0.2
ARG RUBBERBAND_URL="https://breakfastquay.com/files/releases/rubberband-$RUBBERBAND_VERSION.tar.bz2"
ARG RUBBERBAND_SHA256=b9eac027e797789ae99611c9eaeaf1c3a44cc804f9c8a0441a0d1d26f3d6bdf9

# Must be specified
ARG ALPINE_VERSION

FROM alpine:${ALPINE_VERSION} AS base

FROM base AS download
ARG RUBBERBAND_URL
ARG RUBBERBAND_SHA256
ARG WGET_OPTS="--retry-on-host-error --retry-on-http-error=429,500,502,503 -nv"
WORKDIR /tmp
RUN \
  apk add --no-cache --virtual download \
    coreutils wget tar && \
  wget $WGET_OPTS -O rubberband.tar.bz2 "$RUBBERBAND_URL" && \
  echo "$RUBBERBAND_SHA256  rubberband.tar.bz2" | sha256sum --status -c - && \
  mkdir rubberband && \
  tar xf rubberband.tar.bz2 -C rubberband --strip-components=1 && \
  rm rubberband.tar.bz2 && \
  apk del download

FROM base AS build
COPY --from=download /tmp/rubberband/ /tmp/rubberband/
WORKDIR /tmp/rubberband
RUN \
  apk add --no-cache --virtual build \
    build-base meson ninja pkgconf fftw-dev libsamplerate-dev && \
  meson -Ddefault_library=static -Dfft=fftw -Dresampler=libsamplerate build && \
  ninja -j$(nproc) -vC build install && \
  echo "Requires.private: fftw3 samplerate" >> /usr/local/lib/pkgconfig/rubberband.pc && \
  # Sanity tests
  pkg-config --exists --modversion --path rubberband && \
  ar -t /usr/local/lib/librubberband.a && \
  readelf -h /usr/local/lib/librubberband.a && \
  # Cleanup
  apk del build

FROM scratch
ARG RUBBERBAND_VERSION
COPY --from=build /usr/local/lib/pkgconfig/rubberband.pc /usr/local/lib/pkgconfig/rubberband.pc
COPY --from=build /usr/local/lib/librubberband.a /usr/local/lib/librubberband.a
COPY --from=build /usr/local/include/rubberband/ /usr/local/include/rubberband/
