FROM golang:1.9-alpine3.6 as builder-caddy
LABEL maintainer="ulrich.schreiner@gmail.com"

ENV CADDY_VERSION v0.10.10

# Inject files in container file system
COPY caddy-build /caddy-build

RUN apk --no-cache update \
    && apk --no-cache --update add git bash \
    && cd /caddy-build \
    && env OS=linux ARCH=amd64 ./build_caddy.sh \
    && ls -la /caddy-build/caddy

FROM alpine:3.6
MAINTAINER Abner G Jacobsen - http://daspanel.com <admin@daspanel.com>

# Copy bynaries build before
COPY --from=builder-caddy /caddy-build/caddy /usr/sbin/caddy

# Parse Daspanel common arguments for the build command.
ARG VERSION
ARG VCS_URL
ARG VCS_REF
ARG BUILD_DATE
ARG S6_OVERLAY_VERSION=v1.20.0.0
ARG DASPANEL_IMG_NAME=runtime-static
ARG DASPANEL_OS_VERSION=alpine3.6

# Set default env variables
ENV TZ="UTC"

# Set default env variables
ENV \
    # Stop container initialization if error occurs in cont-init.d, fix-attrs.d script's
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    # Timezone
    TZ="UTC" 

# A little bit of metadata management.
# See http://label-schema.org/  
LABEL org.label-schema.schema-version="1.0" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.version=$VERSION \
      org.label-schema.vcs-url=$VCS_URL \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.name="daspanel/runtime-static" \
      org.label-schema.description="Daspanel runtime image for HTTP engine to serve static html sites."


ENV VAR_PREFIX=/var/run
ENV LOG_PREFIX=/var/log/
ENV TEMP_PREFIX=/tmp
ENV CACHE_PREFIX=/var/cache

# Inject files in container file system
COPY rootfs /

RUN set -x \

    # Install minimal packages
    && apk add --update --no-cache ca-certificates wget tzdata unzip tar libcap rsyslog 'su-exec>=0.2' \

    # Install s6 overlay init system
    && wget https://github.com/just-containers/s6-overlay/releases/download/$S6_OVERLAY_VERSION/s6-overlay-amd64.tar.gz --no-check-certificate -O /tmp/s6-overlay.tar.gz \
    && tar xvfz /tmp/s6-overlay.tar.gz -C / \
    && rm -f /tmp/s6-overlay.tar.gz \

    # Install Caddy
    && chmod 0755 /usr/sbin/caddy \
    && setcap "cap_net_bind_service=+ep" /usr/sbin/caddy \

    # Cleanup
    && rm -rf /tmp/* \
    && rm -rf /var/cache/apk/*

# Expose ports for the service
EXPOSE 80 443 2015

# Let's S6 control the init system
ENTRYPOINT ["/init"]
CMD []


