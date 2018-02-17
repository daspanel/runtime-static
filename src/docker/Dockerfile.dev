FROM alpine:3.6
MAINTAINER Abner G Jacobsen - http://daspanel.com <admin@daspanel.com>

# Parse Daspanel common arguments for the build command.
ARG VERSION
ARG VCS_URL
ARG VCS_REF
ARG BUILD_DATE
ARG S6_OVERLAY_VERSION=v1.19.1.1
ARG DASPANEL_IMG_NAME=runtime-static
ARG DASPANEL_OS_VERSION=alpine3.6

# Set default env variables
ENV TZ="UTC"

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
    && apk add --update --no-cache ca-certificates wget tzdata unzip libcap curl tar bash git \

    # Cleanup
    && rm -rf /tmp/* \
    && rm -rf /var/cache/apk/*



