import express, { Request, Response } from "express";
import { v4 as uuidv4 } from "uuid";

interface Task {
  id: string;
  title: string;
  completed: boolean;
  createdAt: string;
}

const app = express();
app.use(express.json());

const tasks: Task[] = [];

app.get("/tasks", (_req: Request, res: Response) => {
  res.json(tasks);
});

app.post("/tasks", (req: Request, res: Response) => {
  const task: Task = {
    id: uuidv4(),
    title: req.body.title,
    completed: false,
    createdAt: new Date().toISOString(),
  };
  tasks.push(task);
  res.status(201).json(task);
});

app.patch("/tasks/:id", (req: Request, res: Response) => {
  const task = tasks.find((t) => t.id === req.params.id);
  if (!task) {
    res.status(404).json({ error: "Task not found" });
    return;
  }
  if (req.body.title !== undefined) task.title = req.body.title;
  if (req.body.completed !== undefined) task.completed = req.body.completed;
  res.json(task);
});

app.delete("/tasks/:id", (req: Request, res: Response) => {
  const index = tasks.findIndex((t) => t.id === req.params.id);
  if (index === -1) {
    res.status(404).json({ error: "Task not found" });
    return;
  }
  tasks.splice(index, 1);
  res.status(204).send();
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Task API running on port ${PORT}`);
});
