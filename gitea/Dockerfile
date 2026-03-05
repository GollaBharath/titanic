FROM gitea/gitea:1.22.1

# Copy custom app.ini configuration
COPY app.ini /data/gitea/conf/app.ini

# Expose Gitea ports
EXPOSE 3000 2222

# Volume for Gitea data
VOLUME ["/data"]

ENV USER_UID=1000
ENV USER_GID=1000
