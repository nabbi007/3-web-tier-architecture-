# Kanban Application

Simple Kanban board application for 3-tier architecture demo.

## Structure
- `server.js` - Express server with MySQL connection
- `public/` - Frontend files (HTML, CSS, JS)
- `package.json` - Dependencies

## Environment Variables
Create a `.env` file with:
```
DB_HOST=your-rds-endpoint
DB_USER=admin
DB_PASSWORD=your-password
DB_NAME=kanbandb
PORT=80
```

## Deploy to GitHub
1. Initialize git: `git init`
2. Add files: `git add .`
3. Commit: `git commit -m "Initial commit"`
4. Add remote: `git remote add origin <your-repo-url>`
5. Push: `git push -u origin main`

## Usage in Terraform
Update the git URL in your user data script to point to this repository.
