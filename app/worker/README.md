# worker

Trabajo programado de tablero. Borra las tareas marcadas como hechas cuya fecha de creación es
anterior a `RETENTION_DAYS` (30 por defecto) y termina. Llega en la Semana 20, el capstone: es el
componente nuevo que entra en el CI sin escribir jobs propios, solo llamando a los reutilizables.

```bash
uv sync --locked
uv run --no-sync pytest tests/unit
# Contra un PostgreSQL de pruebas, con el esquema de la API:
DATABASE_URL=postgresql://tablero:cambiame@127.0.0.1:5432/tablero uv run --no-sync python -m tablero_worker.migrate
DATABASE_URL=postgresql://tablero:cambiame@127.0.0.1:5432/tablero RETENTION_DAYS=30 uv run --no-sync tablero-worker
# purgadas 0 tareas hechas de hace más de 30 días
```

No tiene migraciones propias: el esquema es de la API y `tablero_worker.migrate` aplica las de
`../api/migrations/`. Un cambio ahí tiene que volver a probar el worker.
