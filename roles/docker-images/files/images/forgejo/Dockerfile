ARG VERSION=11.0.8
FROM codeberg.org/forgejo/forgejo:${VERSION}

# TODO[VCC-007]: Add a new entrypoint for forgejo and use it to replace the original

# Install required dependencies for our custom entrypoint checks
RUN apk add --no-cache \
    sudo \
    postgresql-client \
    curl \
    sed \
    util-linux

# Add our custom entrypoint
COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/s6-svscan", "/etc/s6"]