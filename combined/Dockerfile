FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary packages (SSH, web server, Python, nginx, etc.)
RUN apt-get update && apt-get install -y \
    openssh-server \
    sudo \
    curl \
    wget \
    vim \
    git \
    cron \
    autoconf \
    automake \
    libtool \
    pkg-config \
    build-essential \
    libjpeg-dev \
    libpng-dev \
    libgif-dev \
    nginx \
    python3.11 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install ImageMagick 7.1.1-35 (vulnerable version for CVE-2024-41817)
RUN cd /tmp && \
    wget https://github.com/ImageMagick/ImageMagick/archive/refs/tags/7.1.1-35.tar.gz && \
    tar xzf 7.1.1-35.tar.gz && \
    cd ImageMagick-7.1.1-35 && \
    ./configure --prefix=/usr/local --disable-shared --enable-static && \
    make -j$(nproc) && \
    make install && \
    ldconfig /usr/local/lib && \
    cd / && rm -rf /tmp/ImageMagick-7.1.1-35 /tmp/7.1.1-35.tar.gz

# Create developer user with specific password hash
# Password: 25282528 (from the writeup)
RUN useradd -m -s /bin/bash developer && \
    echo 'developer:25282528' | chpasswd

# Create directory structure
RUN mkdir -p /opt/app/static/assets/images && \
    mkdir -p /opt/app/tickets && \
    mkdir -p /opt/app/templates && \
    mkdir -p /opt/scripts && \
    mkdir -p /home/developer/gitea/data

# Copy Flask application files
COPY flask-app/requirements.txt /opt/app/
RUN pip3 install --no-cache-dir -r /opt/app/requirements.txt

COPY flask-app/app.py /opt/app/
COPY flask-app/templates/ /opt/app/templates/

# Create the vulnerable script
COPY scripts/identify_images.sh /opt/scripts/identify_images.sh
RUN chmod +x /opt/scripts/identify_images.sh

# Give developer write permissions to images directory
RUN chown -R developer:developer /opt/app/static/assets/images && \
    chmod 755 /opt/app/static/assets/images

# Create some sample images for the script to process
RUN cd /opt/app/static/assets/images && \
    convert -size 100x100 xc:white sample1.jpg && \
    convert -size 100x100 xc:black sample2.jpg

# Set up SSH
RUN mkdir -p /var/run/sshd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Add cron job to run the script every minute as root
RUN echo "* * * * * root /opt/scripts/identify_images.sh > /dev/null 2>&1" >> /etc/crontab

# Create mount point for gitea data that will be shared
RUN chown -R developer:developer /home/developer/gitea

# User flag
RUN echo "d8b1aece4bc98dac1b3cb90946c7647e" > /home/developer/user.txt && \
    chown developer:developer /home/developer/user.txt && \
    chmod 600 /home/developer/user.txt

# Root flag
RUN echo "95e72bf418462d4519f4dc695236ec2e" > /root/root.txt && \
    chmod 600 /root/root.txt

# Copy nginx configuration
COPY nginx/nginx-combined.conf /etc/nginx/nginx-combined.conf

# Start script
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 22 80

CMD ["/start.sh"]
