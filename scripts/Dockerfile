FROM python:3.11-slim

WORKDIR /app

# Install required packages
RUN pip install --no-cache-dir flask pyyaml requests tqdm pyfiglet gunicorn cryptography

# Copy application files
COPY scripts/onboarding_portal.py ./
COPY scripts/templates /app/templates/
COPY scripts/static /app/static/

# Create necessary directories
RUN mkdir -p templates/apps

# Set environment variables
ENV PORT=5000
ENV DEBUG=False
ENV SECURE_COOKIES=True
ENV ADMIN_USERNAME=admin
# In production, use a secret manager or mounted secret
ENV ADMIN_PASSWORD=changeme
ENV SECRET_KEY=replace_with_random_value_in_production

# Expose port for the application
EXPOSE 5000

# Create a non-root user for security
RUN adduser --disabled-password --gecos "" appuser
RUN chown -R appuser:appuser /app
USER appuser

# Command to run the application with Gunicorn for production
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "4", "--timeout", "120", "onboarding_portal:app"]
