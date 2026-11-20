FROM python:3.13-slim

WORKDIR /app
RUN mkdir -p /data && chown 10001:10001 /data
COPY --chown=10001:10001 server.py /app/server.py

ARG APP_VERSION=v1
ENV APP_VERSION=${APP_VERSION} \
    APP_MESSAGE="Preparatório BACEN" \
    DATA_DIR=/data \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

USER 10001:10001
EXPOSE 8080
CMD ["python", "/app/server.py"]
