"""Tests unitarios: la lógica de retención, sin base de datos."""

from datetime import UTC, datetime

import pytest

from tablero_worker import purge as purge_module
from tablero_worker.purge import cutoff, main, purge, retention_days


def test_default_retention_is_30_days():
    assert retention_days(None) == 30
    assert retention_days("") == 30


def test_retention_from_env_value():
    assert retention_days("7") == 7


@pytest.mark.parametrize("raw", ["0", "-3", "siete"])
def test_invalid_retention_stops_the_worker(raw):
    with pytest.raises(ValueError):
        retention_days(raw)


def test_cutoff_goes_back_exactly_n_days():
    now = datetime(2026, 11, 14, 12, 0, tzinfo=UTC)
    assert cutoff(now, 30) == datetime(2026, 10, 15, 12, 0, tzinfo=UTC)


def test_main_needs_database_url(monkeypatch):
    monkeypatch.delenv("DATABASE_URL", raising=False)
    with pytest.raises(SystemExit, match="DATABASE_URL"):
        main()


class FakeConnection:
    """Lo justo de psycopg.Connection para probar la purga sin base de datos."""

    def __init__(self, rowcount):
        self.rowcount = rowcount
        self.calls = []

    def execute(self, sql, params):
        self.calls.append((sql, params))
        return self

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


def test_purge_deletes_only_done_tasks_before_cutoff():
    conn = FakeConnection(rowcount=3)
    before = datetime(2026, 10, 15, tzinfo=UTC)
    assert purge(conn, before) == 3
    sql, params = conn.calls[0]
    assert "WHERE done AND created_at < %s" in sql
    assert params == (before,)


def test_main_reports_how_many_tasks_it_purged(monkeypatch, capsys):
    monkeypatch.setenv("DATABASE_URL", "postgresql://ci@localhost/ci")
    monkeypatch.setenv("RETENTION_DAYS", "7")
    monkeypatch.setattr(purge_module.psycopg, "connect", lambda url: FakeConnection(rowcount=2))
    main()
    assert capsys.readouterr().out == "purgadas 2 tareas hechas de hace más de 7 días\n"
