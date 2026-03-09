FROM python:3.11-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

FROM python:3.11-slim AS runtime

# FIX 3: Install curl for healthcheck before switching to non-root user
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app

# FIX 1: Add --chown so appuser can actually read installed packages
COPY --from=builder --chown=appuser:appuser /root/.local /home/appuser/.local

# FIX 4: Chown src files to appuser
COPY --chown=appuser:appuser src/ ./src/

# FIX 2: Add user local bin to PATH
ENV PATH=/home/appuser/.local/bin:$PATH

# Remove SUID/SGID bits
RUN find / -perm /6000 -type f -exec chmod a-s {} \; 2>/dev/null || true

USER appuser
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8080"]