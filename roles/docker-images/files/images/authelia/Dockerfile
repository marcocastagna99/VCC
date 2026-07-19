ARG VERSION=4.39.14
FROM authelia/authelia:${VERSION}

COPY ./entrypoint.sh /entrypoint.sh

USER root
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]