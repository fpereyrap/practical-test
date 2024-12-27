# File: app.py
from flask import Flask, jsonify, request, render_template
import redis
import psycopg2
import os

app = Flask(__name__, template_folder='templates', static_folder='static')

# Connect to Redis
redis_host = os.getenv("REDIS_HOST", "redis")
redis_port = os.getenv("REDIS_PORT", 6379)
redis_client = redis.StrictRedis(host=redis_host, port=redis_port, decode_responses=True)

# Connect to PostgreSQL
def get_db_connection():
    connection = psycopg2.connect(
        dbname=os.getenv("DB_NAME", "testdb"),
        user=os.getenv("DB_USER", "testuser"),
        password=os.getenv("DB_PASSWORD", "password"),
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", 5432),
    )
    return connection

# Initialize database
def init_db():
    try:
        connection = get_db_connection()
        cursor = connection.cursor()
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                name VARCHAR(100),
                age INT
            );
        """
        )
        connection.commit()
        cursor.close()
        connection.close()
    except Exception as e:
        print(f"Error initializing database: {e}")

# Initialize the database at application startup
init_db()

@app.route('/')
def hello():
    return render_template("index.html")

@app.route('/cache/<key>', methods=['GET', 'POST'])
def handle_cache(key):
    if request.method == 'POST':
        value = request.json.get('value', '')
        redis_client.set(key, value)
        return jsonify({"message": f"Key '{key}' set to '{value}' in Redis."})

    elif request.method == 'GET':
        value = redis_client.get(key)
        if value:
            return jsonify({"key": key, "value": value})
        else:
            return jsonify({"message": f"Key '{key}' not found in Redis."}), 404

@app.route('/db/insert', methods=['POST'])
def insert_data():
    data = request.json
    name = data.get('name')
    age = data.get('age')

    if not name or not age:
        return jsonify({"error": "Name and age are required."}), 400

    try:
        connection = get_db_connection()
        cursor = connection.cursor()
        cursor.execute("INSERT INTO users (name, age) VALUES (%s, %s);", (name, age))
        connection.commit()
        cursor.close()
        connection.close()
        return jsonify({"message": "Data inserted successfully."})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/db/users', methods=['GET'])
def get_users():
    try:
        connection = get_db_connection()
        cursor = connection.cursor()
        cursor.execute("SELECT id, name, age FROM users;")
        users = cursor.fetchall()
        cursor.close()
        connection.close()

        return jsonify({"users": [{"id": user[0], "name": user[1], "age": user[2]} for user in users]})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)