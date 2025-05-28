# 3D Print E-commerce Prototype

This directory contains a simple prototype of a 3D print e-commerce application based on FastAPI for the backend. A minimal Vue frontend would go in the `frontend/` directory.

## Backend

The backend exposes endpoints for uploading STL files and managing orders. Data is stored in a local SQLite database, and uploaded files are stored in the `uploads/` directory.

To run the backend (assuming dependencies are installed):

```bash
uvicorn backend.main:app --reload
```

## Frontend

The frontend directory is currently a placeholder for a Vue.js application.
