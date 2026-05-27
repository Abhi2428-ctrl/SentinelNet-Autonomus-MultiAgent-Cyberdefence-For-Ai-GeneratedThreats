FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY agents/ ./agents/
COPY backend/ ./backend/
COPY frontend/ ./frontend/
RUN mkdir -p logs data
EXPOSE 8000
CMD ["python", "backend/main.py"]
