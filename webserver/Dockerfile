FROM python:3.9-slim

WORKDIR /app
COPY . /app

RUN apt-get update \
    && apt-get install -y gcc libpq-dev \
    && pip install --no-cache-dir -r requirements.txt

CMD ["python", "app.py"]
