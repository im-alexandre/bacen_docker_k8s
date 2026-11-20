"""Aplicação didática, sem dependências externas e sem serviço de IA.

O contador persiste no Docker Compose por meio de um volume nomeado.
No Kubernetes ele é local a cada Pod (emptyDir), sem estado compartilhado.
Os arquivos de falha em /tmp são usados somente na demonstração de probes.
"""
from contextlib import closing
from html import escape
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import socket
import sqlite3
from urllib.parse import urlsplit

DATA_DIR = Path(os.getenv("DATA_DIR", "/data"))
DATA_DIR.mkdir(parents=True, exist_ok=True)
DATABASE = DATA_DIR / "contador.sqlite"
VERSION = os.getenv("APP_VERSION", "v1")
MESSAGE = os.getenv("APP_MESSAGE", "Preparatório BACEN")


def counter(increment=False):
    with closing(sqlite3.connect(DATABASE, timeout=5)) as connection, connection:
        connection.execute("CREATE TABLE IF NOT EXISTS contador (id INTEGER PRIMARY KEY, valor INTEGER NOT NULL)")
        connection.execute("INSERT OR IGNORE INTO contador VALUES (1, 0)")
        if increment:
            connection.execute("UPDATE contador SET valor = valor + 1 WHERE id = 1")
        return connection.execute("SELECT valor FROM contador WHERE id = 1").fetchone()[0]


class Handler(BaseHTTPRequestHandler):
    def send(self, status, data, content_type="application/json; charset=utf-8"):
        payload = (json.dumps(data, ensure_ascii=False) if not isinstance(data, str) else data).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        path = urlsplit(self.path).path
        if path in ("/livez", "/readyz"):
            marker = "force-unhealthy" if path == "/livez" else "force-unready"
            healthy = not (Path("/tmp") / marker).exists()
            self.send(200 if healthy else 503, {"ok": healthy, "probe": path})
        elif path == "/info":
            self.send(200, {"versao": VERSION, "mensagem": MESSAGE,
                            "hostname": socket.gethostname(),
                            "segredo_configurado": bool(os.getenv("API_TOKEN"))})
        elif path == "/counter":
            self.send(200, {"contador": counter()})
        elif path == "/":
            self.send(200, f"""<!doctype html><html lang="pt-BR"><meta charset="utf-8">
<title>Laboratório BACEN</title><h1>{escape(MESSAGE)}</h1>
<p>Versão: {escape(VERSION)}</p><p>Host: {escape(socket.gethostname())}</p>
<p>Contador deste armazenamento: {counter()}</p>
<form method="post" action="/counter"><button>Incrementar contador</button></form>
<p><a href="/info">Informações da instância</a></p></html>""", "text/html; charset=utf-8")
        else:
            self.send(404, {"erro": "rota não encontrada"})

    def do_POST(self):
        if urlsplit(self.path).path == "/counter":
            self.send(200, {"contador": counter(increment=True)})
        else:
            self.send(404, {"erro": "rota não encontrada"})


if __name__ == "__main__":
    counter()
    ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
