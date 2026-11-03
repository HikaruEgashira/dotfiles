#!/usr/bin/env python3
"""AWS credential broker: sandbox が SSO token store を読まずに短寿命 STS credential だけ受け取る。

agent: unix socket で profile 名を 1 行受け、allowlist 内なら host の
       `aws configure export-credentials --format process` の出力をそのまま返す。
client: credential_process として呼ばれ、agent の応答 JSON を stdout に流す。

wire format は 1 行の status ("ok" / "error") と、それに続く本文。
"""

import argparse
import os
import socket
import socketserver
import subprocess
import sys

PROFILE_MAX = 256
AWS_TIMEOUT = 120


def export_credentials(aws_bin, profile):
    proc = subprocess.run(
        [aws_bin, "configure", "export-credentials", "--profile", profile, "--format", "process"],
        capture_output=True,
        text=True,
        timeout=AWS_TIMEOUT,
        check=False,
    )
    if proc.returncode != 0:
        detail = proc.stderr.strip() or f"aws exited {proc.returncode}"
        return False, detail
    return True, proc.stdout


class Handler(socketserver.StreamRequestHandler):
    def handle(self):
        line = self.rfile.readline(PROFILE_MAX + 1)
        profile = line.decode("utf-8", "replace").strip()
        if not profile or len(line) > PROFILE_MAX or profile not in self.server.allowed:
            self.reply(False, f"profile not allowed: {profile!r}")
            return
        try:
            ok, body = export_credentials(self.server.aws_bin, profile)
        except (subprocess.TimeoutExpired, OSError) as exc:
            ok, body = False, str(exc)
        self.reply(ok, body)

    def reply(self, ok, body):
        status = "ok" if ok else "error"
        self.wfile.write(f"{status}\n{body}".encode())


class Server(socketserver.ThreadingMixIn, socketserver.UnixStreamServer):
    daemon_threads = True

    def __init__(self, path, allowed, aws_bin):
        self.allowed = frozenset(allowed)
        self.aws_bin = aws_bin
        os.makedirs(os.path.dirname(path), mode=0o700, exist_ok=True)
        os.chmod(os.path.dirname(path), 0o700)
        if os.path.exists(path):
            os.unlink(path)
        super().__init__(path, Handler)
        os.chmod(path, 0o600)


def run_agent(args):
    with Server(args.socket, args.allow, args.aws) as server:
        print(f"aws-cred-agent: listening on {args.socket} for {sorted(server.allowed)}", flush=True)
        server.serve_forever()


def run_client(args):
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
        try:
            sock.connect(args.socket)
        except OSError as exc:
            print(f"aws-cred-client: cannot reach broker at {args.socket}: {exc}", file=sys.stderr)
            return 2
        sock.sendall(f"{args.profile}\n".encode())
        sock.shutdown(socket.SHUT_WR)
        chunks = []
        while chunk := sock.recv(65536):
            chunks.append(chunk)
    status, _, body = b"".join(chunks).partition(b"\n")
    if status != b"ok":
        print(f"aws-cred-client: {body.decode(errors='replace').strip()}", file=sys.stderr)
        return 1
    sys.stdout.buffer.write(body)
    sys.stdout.flush()
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(prog="aws-cred-broker")
    parser.add_argument("--socket", required=True)
    sub = parser.add_subparsers(dest="mode", required=True)
    agent = sub.add_parser("agent")
    agent.add_argument("--aws", required=True)
    agent.add_argument("--allow", action="append", default=[])
    agent.set_defaults(func=run_agent)
    client = sub.add_parser("client")
    client.add_argument("profile")
    client.set_defaults(func=run_client)
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
