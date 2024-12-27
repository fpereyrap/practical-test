
async function setRedisKey() {
    const key = document.getElementById("redis-key").value;
    const value = document.getElementById("redis-value").value;
    const response = await fetch(`/cache/${key}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ value }),
    });
    const result = await response.json();
    document.getElementById("redis-result").textContent = result.message;
}

async function getRedisKey() {
    const key = document.getElementById("redis-key").value;
    const response = await fetch(`/cache/${key}`);
    const result = await response.json();
    document.getElementById("redis-result").textContent = result.key ? `Value: ${result.value}` : result.message;
}

async function insertUser() {
    const name = document.getElementById("db-name").value;
    const age = document.getElementById("db-age").value;
    const response = await fetch(`/db/insert`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name, age }),
    });
    const result = await response.json();
    alert(result.message || result.error);
}

async function fetchUsers() {
    const response = await fetch(`/db/users`);
    const result = await response.json();
    const usersList = document.getElementById("users-list");
    usersList.innerHTML = "";
    result.users.forEach(user => {
        const li = document.createElement("li");
        li.textContent = `ID: ${user.id}, Name: ${user.name}, Age: ${user.age}`;
        usersList.appendChild(li);
    });
}
