FROM python:3.11-slim

WORKDIR /opt/app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY app.py .
COPY templates/ templates/

# Create tickets directory
RUN mkdir -p /opt/app/tickets

# Create a non-root user
RUN useradd -m -s /bin/bash flaskuser && \
    chown -R flaskuser:flaskuser /opt/app

USER flaskuser

EXPOSE 5000

CMD ["python", "app.py"]
