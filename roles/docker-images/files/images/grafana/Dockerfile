ARG VERSION=12.3
FROM grafana/grafana:${VERSION}

USER root
# TODO[VCC-009]: Add a new entrypoint for grafana and use it to replace the original

COPY .entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
USER grafana