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
