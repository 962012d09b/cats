FROM python:3.12-slim

# Get host user ID as build argument, default should almost always work
ARG USER_ID=1000
ARG GROUP_ID=1000

# Install gosu for entrypoint user switching
RUN apt-get update && apt-get install -y --no-install-recommends gosu && rm -rf /var/lib/apt/lists/*

# Create user with matching UID/GID
RUN groupadd -g $GROUP_ID celeryuser && \
    useradd -r -u $USER_ID -g celeryuser celeryuser

WORKDIR /app
RUN mkdir -p backend/database backend/modules
RUN mkdir -p datasets

COPY requirements.txt backend/
RUN pip install -r backend/requirements.txt

COPY . backend/

RUN pip install -e backend/

# Ensure ownership (this affects container filesystem, not bind mounts)
RUN chown -R celeryuser:celeryuser /app/datasets /app/backend/database

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 47126

WORKDIR /app/backend

ENTRYPOINT ["/entrypoint.sh"]
CMD ["cats_backend"]