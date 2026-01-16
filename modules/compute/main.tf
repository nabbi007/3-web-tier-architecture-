data "aws_ssm_parameter" "ami" {
  name = var.ami_ssm_parameter_name
}

# Launch Template
resource "aws_launch_template" "app" {
  name_prefix            = "${var.project_name}-${var.environment}-app-"
  image_id               = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [var.app_sg_id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e
    
    # Log everything to file
    exec > >(tee /var/log/user-data.log)
    exec 2>&1
    
    echo "Starting user data script..."
    
    # Update system
    apt-get update -y
    
    # Install Node.js 20.x
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
    
    # Create app directory
    mkdir -p /opt/kanban-app
    cd /opt/kanban-app
    
    # Create package.json
    cat > package.json <<'PACKAGE'
    {
      "name": "kanban-app",
      "version": "1.0.0",
      "description": "Simple Kanban API",
      "main": "server.js",
      "scripts": {
        "start": "node server.js"
      },
      "dependencies": {
        "express": "^4.18.2",
        "mysql2": "^3.6.5"
      }
    }
    PACKAGE
    
    # Create server.js
    cat > server.js <<'SERVER'
    const express = require('express');
    const mysql = require('mysql2/promise');
    const path = require('path');
    
    const app = express();
    app.use(express.json());
    app.use(express.static('public'));
    
    const DB_HOST = '${split(":", var.db_endpoint)[0]}';
    const DB_USER = '${var.db_username}';
    const DB_PASSWORD = '${var.db_password}';
    const DB_NAME = '${var.db_name}';
    const PORT = 80;
    
    let pool;
    
    // Initialize database connection pool
    async function initDB() {
      try {
        pool = mysql.createPool({
          host: DB_HOST,
          user: DB_USER,
          password: DB_PASSWORD,
          database: DB_NAME,
          waitForConnections: true,
          connectionLimit: 10,
          queueLimit: 0
        });
        
        // Create tables if they don't exist
        const connection = await pool.getConnection();
        await connection.query(`
          CREATE TABLE IF NOT EXISTS tasks (
            id INT AUTO_INCREMENT PRIMARY KEY,
            title VARCHAR(255) NOT NULL,
            description TEXT,
            status ENUM('todo', 'in-progress', 'done') DEFAULT 'todo',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
          )
        `);
        connection.release();
        console.log('Database initialized successfully');
      } catch (error) {
        console.error('Database initialization error:', error);
        throw error;
      }
    }
    
    // Health check endpoint - doesn't check DB
    app.get('/health', (req, res) => {
      res.status(200).json({ status: 'healthy', timestamp: new Date().toISOString() });
    });
    
    // Serve the main UI
    app.get('/', (req, res) => {
      res.sendFile(path.join(__dirname, 'public', 'index.html'));
    });
    
    // API Routes
    app.get('/api/tasks', async (req, res) => {
      try {
        const [rows] = await pool.query('SELECT * FROM tasks ORDER BY created_at DESC');
        res.json({ success: true, data: rows });
      } catch (error) {
        console.error('Error fetching tasks:', error);
        res.status(500).json({ success: false, error: 'Failed to fetch tasks' });
      }
    });
    
    // Get single task
    app.get('/api/tasks/:id', async (req, res) => {
      try {
        const [rows] = await pool.query('SELECT * FROM tasks WHERE id = ?', [req.params.id]);
        if (rows.length === 0) {
          return res.status(404).json({ success: false, error: 'Task not found' });
        }
        res.json({ success: true, data: rows[0] });
      } catch (error) {
        console.error('Error fetching task:', error);
        res.status(500).json({ success: false, error: 'Failed to fetch task' });
      }
    });
    
    // Create task
    app.post('/api/tasks', async (req, res) => {
      try {
        const { title, description, status } = req.body;
        if (!title) {
          return res.status(400).json({ success: false, error: 'Title is required' });
        }
        const [result] = await pool.query(
          'INSERT INTO tasks (title, description, status) VALUES (?, ?, ?)',
          [title, description || '', status || 'todo']
        );
        res.status(201).json({ 
          success: true, 
          data: { id: result.insertId, title, description, status: status || 'todo' }
        });
      } catch (error) {
        console.error('Error creating task:', error);
        res.status(500).json({ success: false, error: 'Failed to create task' });
      }
    });
    
    // Update task
    app.put('/api/tasks/:id', async (req, res) => {
      try {
        const { title, description, status } = req.body;
        const [result] = await pool.query(
          'UPDATE tasks SET title = COALESCE(?, title), description = COALESCE(?, description), status = COALESCE(?, status) WHERE id = ?',
          [title, description, status, req.params.id]
        );
        if (result.affectedRows === 0) {
          return res.status(404).json({ success: false, error: 'Task not found' });
        }
        res.json({ success: true, message: 'Task updated' });
      } catch (error) {
        console.error('Error updating task:', error);
        res.status(500).json({ success: false, error: 'Failed to update task' });
      }
    });
    
    // Delete task
    app.delete('/api/tasks/:id', async (req, res) => {
      try {
        const [result] = await pool.query('DELETE FROM tasks WHERE id = ?', [req.params.id]);
        if (result.affectedRows === 0) {
          return res.status(404).json({ success: false, error: 'Task not found' });
        }
        res.json({ success: true, message: 'Task deleted' });
      } catch (error) {
        console.error('Error deleting task:', error);
        res.status(500).json({ success: false, error: 'Failed to delete task' });
      }
    });
    
    // Start server
    async function startServer() {
      try {
        await initDB();
        app.listen(PORT, '0.0.0.0', () => {
          console.log(`Kanban API listening on port $${PORT}`);
        });
      } catch (error) {
        console.error('Failed to start server:', error);
        process.exit(1);
      }
    }
    
    startServer();
    SERVER
    
    # Create public directory and HTML/CSS/JS files
    mkdir -p /opt/kanban-app/public
    
    # Create index.html
    cat > /opt/kanban-app/public/index.html <<'HTML'
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Kanban Board - ${var.project_name}</title>
      <link rel="stylesheet" href="/style.css">
    </head>
    <body>
      <div class="container">
        <header>
          <h1>🎯 Kanban Board</h1>
          <p class="subtitle">3-Tier Architecture - ${var.environment} Environment</p>
        </header>
        
        <div class="add-task-section">
          <h2>Add New Task</h2>
          <form id="taskForm">
            <input type="text" id="taskTitle" placeholder="Task title" required>
            <textarea id="taskDescription" placeholder="Task description (optional)" rows="3"></textarea>
            <select id="taskStatus">
              <option value="todo">📝 To Do</option>
              <option value="in-progress">🚀 In Progress</option>
              <option value="done">✅ Done</option>
            </select>
            <button type="submit">Add Task</button>
          </form>
        </div>
        
        <div class="kanban-board">
          <div class="column">
            <h3>📝 To Do</h3>
            <div class="task-list" id="todo-list"></div>
          </div>
          
          <div class="column">
            <h3>🚀 In Progress</h3>
            <div class="task-list" id="in-progress-list"></div>
          </div>
          
          <div class="column">
            <h3>✅ Done</h3>
            <div class="task-list" id="done-list"></div>
          </div>
        </div>
      </div>
      
      <script src="/app.js"></script>
    </body>
    </html>
    HTML
    
    # Create style.css
    cat > /opt/kanban-app/public/style.css <<'CSS'
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      min-height: 100vh;
      padding: 20px;
    }
    
    .container {
      max-width: 1400px;
      margin: 0 auto;
    }
    
    header {
      text-align: center;
      color: white;
      margin-bottom: 30px;
    }
    
    header h1 {
      font-size: 3em;
      margin-bottom: 10px;
      text-shadow: 2px 2px 4px rgba(0,0,0,0.2);
    }
    
    .subtitle {
      font-size: 1.1em;
      opacity: 0.9;
    }
    
    .add-task-section {
      background: white;
      padding: 25px;
      border-radius: 12px;
      box-shadow: 0 8px 16px rgba(0,0,0,0.1);
      margin-bottom: 30px;
    }
    
    .add-task-section h2 {
      color: #333;
      margin-bottom: 20px;
    }
    
    #taskForm {
      display: flex;
      flex-direction: column;
      gap: 15px;
    }
    
    #taskForm input,
    #taskForm textarea,
    #taskForm select {
      padding: 12px;
      border: 2px solid #e0e0e0;
      border-radius: 8px;
      font-size: 1em;
      font-family: inherit;
      transition: border-color 0.3s;
    }
    
    #taskForm input:focus,
    #taskForm textarea:focus,
    #taskForm select:focus {
      outline: none;
      border-color: #667eea;
    }
    
    #taskForm button {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      border: none;
      padding: 15px;
      border-radius: 8px;
      font-size: 1.1em;
      font-weight: 600;
      cursor: pointer;
      transition: transform 0.2s, box-shadow 0.2s;
    }
    
    #taskForm button:hover {
      transform: translateY(-2px);
      box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
    }
    
    .kanban-board {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
      gap: 20px;
    }
    
    .column {
      background: rgba(255, 255, 255, 0.95);
      border-radius: 12px;
      padding: 20px;
      box-shadow: 0 8px 16px rgba(0,0,0,0.1);
    }
    
    .column h3 {
      color: #333;
      margin-bottom: 20px;
      font-size: 1.5em;
      text-align: center;
      padding-bottom: 15px;
      border-bottom: 3px solid #e0e0e0;
    }
    
    .task-list {
      display: flex;
      flex-direction: column;
      gap: 15px;
      min-height: 200px;
    }
    
    .task-card {
      background: white;
      border: 2px solid #e0e0e0;
      border-radius: 8px;
      padding: 15px;
      cursor: move;
      transition: all 0.3s;
    }
    
    .task-card:hover {
      box-shadow: 0 4px 12px rgba(0,0,0,0.15);
      transform: translateY(-2px);
    }
    
    .task-card h4 {
      color: #333;
      margin-bottom: 8px;
      font-size: 1.1em;
    }
    
    .task-card p {
      color: #666;
      font-size: 0.95em;
      margin-bottom: 12px;
      line-height: 1.4;
    }
    
    .task-actions {
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
    }
    
    .task-actions button {
      padding: 6px 12px;
      border: none;
      border-radius: 5px;
      cursor: pointer;
      font-size: 0.85em;
      font-weight: 600;
      transition: all 0.2s;
    }
    
    .btn-move {
      background: #4caf50;
      color: white;
    }
    
    .btn-move:hover {
      background: #45a049;
    }
    
    .btn-delete {
      background: #f44336;
      color: white;
    }
    
    .btn-delete:hover {
      background: #da190b;
    }
    
    .task-date {
      font-size: 0.8em;
      color: #999;
      margin-top: 8px;
    }
    
    .empty-state {
      text-align: center;
      color: #999;
      padding: 40px 20px;
      font-style: italic;
    }
    CSS
    
    # Create app.js
    cat > /opt/kanban-app/public/app.js <<'JAVASCRIPT'
    const API_BASE = '';
    
    // Load tasks on page load
    document.addEventListener('DOMContentLoaded', () => {
      loadTasks();
      document.getElementById('taskForm').addEventListener('submit', handleAddTask);
    });
    
    async function loadTasks() {
      try {
        const response = await fetch('/api/tasks');
        const data = await response.json();
        
        if (data.success) {
          renderTasks(data.data);
        }
      } catch (error) {
        console.error('Error loading tasks:', error);
      }
    }
    
    function renderTasks(tasks) {
      const lists = {
        'todo': document.getElementById('todo-list'),
        'in-progress': document.getElementById('in-progress-list'),
        'done': document.getElementById('done-list')
      };
      
      Object.values(lists).forEach(list => list.innerHTML = '');
      
      if (tasks.length === 0) {
        Object.values(lists).forEach(list => {
          list.innerHTML = '<div class="empty-state">No tasks yet</div>';
        });
        return;
      }
      
      tasks.forEach(task => {
        const taskElement = createTaskElement(task);
        lists[task.status].appendChild(taskElement);
      });
      
      Object.entries(lists).forEach(([status, list]) => {
        if (list.children.length === 0) {
          list.innerHTML = '<div class="empty-state">No tasks</div>';
        }
      });
    }
    
    function createTaskElement(task) {
      const div = document.createElement('div');
      div.className = 'task-card';
      div.dataset.id = task.id;
      
      const statusMap = {
        'todo': 'in-progress',
        'in-progress': 'done',
        'done': 'todo'
      };
      
      const statusLabelMap = {
        'todo': '🚀 Start',
        'in-progress': '✅ Complete',
        'done': '📝 Restart'
      };
      
      const date = new Date(task.created_at).toLocaleDateString();
      
      const nextStatus = statusMap[task.status];
      const nextLabel = statusLabelMap[task.status];
      const desc = task.description || '';
      
      div.innerHTML = '<h4>' + task.title + '</h4>' +
        (desc ? '<p>' + desc + '</p>' : '') +
        '<div class="task-actions">' +
        '<button class="btn-move" onclick="moveTask(' + task.id + ', \'' + nextStatus + '\')">' + nextLabel + '</button>' +
        '<button class="btn-delete" onclick="deleteTask(' + task.id + ')">🗑️ Delete</button>' +
        '</div>' +
        '<div class="task-date">Created: ' + date + '</div>';
      
      return div;
    }
    
    async function handleAddTask(e) {
      e.preventDefault();
      
      const title = document.getElementById('taskTitle').value;
      const description = document.getElementById('taskDescription').value;
      const status = document.getElementById('taskStatus').value;
      
      try {
        const response = await fetch('/api/tasks', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ title, description, status })
        });
        
        const data = await response.json();
        
        if (data.success) {
          document.getElementById('taskForm').reset();
          loadTasks();
        }
      } catch (error) {
        console.error('Error adding task:', error);
        alert('Failed to add task');
      }
    }
    
    async function moveTask(id, newStatus) {
      try {
        const response = await fetch('/api/tasks/' + id, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ status: newStatus })
        });
        
        const data = await response.json();
        
        if (data.success) {
          loadTasks();
        }
      } catch (error) {
        console.error('Error moving task:', error);
        alert('Failed to move task');
      }
    }
    
    async function deleteTask(id) {
      if (!confirm('Are you sure you want to delete this task?')) return;
      
      try {
        const response = await fetch('/api/tasks/' + id, {
          method: 'DELETE'
        });
        
        const data = await response.json();
        
        if (data.success) {
          loadTasks();
        }
      } catch (error) {
        console.error('Error deleting task:', error);
        alert('Failed to delete task');
      }
    }
    JAVASCRIPT
    
    # Install dependencies
    npm install --production
    
    # Create systemd service
    cat > /etc/systemd/system/kanban.service <<'SERVICE'
    [Unit]
    Description=Kanban API Service
    After=network.target
    
    [Service]
    Type=simple
    User=root
    WorkingDirectory=/opt/kanban-app
    ExecStart=/usr/bin/node server.js
    Restart=always
    RestartSec=10
    StandardOutput=append:/var/log/kanban.log
    StandardError=append:/var/log/kanban-error.log
    
    [Install]
    WantedBy=multi-user.target
    SERVICE
    
    # Start and enable service
    systemctl daemon-reload
    systemctl enable kanban
    systemctl start kanban
    
    # Wait for service to be ready
    sleep 10
    
    # Verify service is running
    systemctl status kanban
    
    echo "User data script completed successfully!"
  EOF
  )

  tags = {
    Name        = "${var.project_name}-${var.environment}-app"
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "app" {
  name                = "${var.project_name}-${var.environment}-app-asg"
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  vpc_zone_identifier = var.private_subnet_ids
  health_check_type   = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-app"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Owner"
    value               = var.owner
    propagate_at_launch = true
  }
}

# Attach ASG to Target Group
resource "aws_autoscaling_attachment" "app" {
  autoscaling_group_name = aws_autoscaling_group.app.id
  lb_target_group_arn    = var.target_group_arn
}
