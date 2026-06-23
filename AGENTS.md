# Repository Guidelines

## Project Structure & Module Organization

The project is a full-stack application designed for lead scouting, consisting of a FastAPI backend and a React frontend.

- **`.\backend\`**: FastAPI application managing lead scraping and AI scoring logic.
    - **`.\backend\main.py`**: API entry point and router configuration.
    - **`.\backend\scraper.py`**: Core heuristic-based lead scanner.
    - **`.\backend\ai.py`**: Integration with Google Gemini API for AI-powered lead enrichment.
- **`.\frontend\`**: React SPA built with Vite and TypeScript.
    - Uses **shadcn/ui** and **Tailwind CSS** for the interface.
    - Employs **HashRouter** for compatibility with static hosting environments.
- **`.\deployment\`**: Infrastructure-as-code for Ubuntu/GCP.
    - Includes **Nginx** configurations and **systemd** service definitions for production deployment.

## Build, Test, and Development Commands

### Full Stack Development
The root `dev.sh` script automates starting both tiers:
```bash
bash dev.sh
```

### Backend (Python)
- **Run Development Server**: `cd backend && uvicorn main:app --reload --port 8000`
- **Run Tests**: `cd backend && python test_api.py`
- **Install Dependencies**: `cd backend && pip install -r requirements.txt`

### Frontend (Node.js)
- **Run Development Server**: `cd frontend && npm run dev`
- **Build for Production**: `cd frontend && npm run build`
- **Lint Code**: `cd frontend && npm run lint`

## Coding Style & Naming Conventions

### Frontend
- **Strict TypeScript**: Enforced via `tsconfig.json` (`strict: true`, `noUnusedLocals`, `noUnusedParameters`).
- **Component Pattern**: Follows shadcn/ui patterns; components are located in `.\frontend\src\components\`.
- **Path Aliases**: Use `@/*` to reference `.\frontend\src\*`.

### Backend
- **Type Hinting**: Mandatory use of Python type hints for all function signatures and FastAPI endpoints.
- **Logging**: Standardized logging via `logging.basicConfig` in `main.py`.

## Testing Guidelines

- **Backend**: Integration tests are maintained in `.\backend\test_api.py`. These tests verify API health, configuration, and scanning logic against a running server.
- **Frontend**: Currently relies on `npm run lint` for static analysis; no unit test suite is established yet.
