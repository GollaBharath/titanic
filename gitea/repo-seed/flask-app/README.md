# RMS Titanic - Booking Application

This is the Flask web application for the RMS Titanic ticket booking system.

## Features

- Ticket booking interface with class selection (First, Second, Third)
- Passenger information collection
- Ticket download functionality
- JSON-based ticket storage

## Installation

```bash
pip install -r requirements.txt
python app.py
```

## Application Structure

- `app.py` - Main Flask application
- `templates/` - HTML templates for the web interface
- `requirements.txt` - Python dependencies

## Configuration

The application runs on port 5000 by default and stores tickets in `/opt/app/tickets`.

## Routes

- `/` - Main booking page
- `/book` - Process booking submissions
- `/download` - Download ticket files

## Development

This is a development version. For production deployment, use a proper WSGI server like Gunicorn or uWSGI.
