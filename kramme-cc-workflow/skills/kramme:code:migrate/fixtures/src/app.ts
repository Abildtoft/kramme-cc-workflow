import express from "express";
import { Pool } from "pg";

const app = express();
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

app.use(express.json());

app.get("/users", async (req, res) => {
  try {
    const result = await pool.query("SELECT * FROM users");
    const users = result.rows.map((row: any) => ({
      id: row.id,
      name: row.first_name + " " + row.last_name,
      email: row.email,
      role: row.role === 1 ? "admin" : row.role === 2 ? "editor" : "viewer",
    }));
    res.json(users);
  } catch (err) {
    console.log(err);
    res.status(500).send("Error");
  }
});

app.post("/users", async (req, res) => {
  const { first_name, last_name, email, role } = req.body;
  const roleNum = role === "admin" ? 1 : role === "editor" ? 2 : 3;
  try {
    await pool.query(
      "INSERT INTO users (first_name, last_name, email, role) VALUES ($1, $2, $3, $4)",
      [first_name, last_name, email, roleNum]
    );
    res.status(201).send("Created");
  } catch (err) {
    console.log(err);
    res.status(500).send("Error");
  }
});

app.delete("/users/:id", async (req, res) => {
  try {
    await pool.query("DELETE FROM users WHERE id = $1", [req.params.id]);
    res.send("Deleted");
  } catch (err) {
    console.log(err);
    res.status(500).send("Error");
  }
});

app.listen(3000, () => console.log("Running on 3000"));
