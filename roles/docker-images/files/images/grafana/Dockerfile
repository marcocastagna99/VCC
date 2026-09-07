ARG VERSION=12.3
FROM grafana/grafana:${VERSION}

USER root
# Install tools needed for certificates and to drop privileges
RUN apk add --no-cache ca-certificates su-exec
# TODO[VCC-009]: Add a new entrypoint for grafana and use it to replace the original

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

# WARNING: Do NOT put "USER grafana" here. 
# The container must start as root to update system certificates, 
# then it will drop privileges inside the entrypoint script.