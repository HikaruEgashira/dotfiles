#!/usr/bin/env python3
import errno
import os
import socket
import stat
import sys


def clear_stale_socket(path):
    try:
        before = os.lstat(path)
    except FileNotFoundError:
        return
    if not stat.S_ISSOCK(before.st_mode):
        raise RuntimeError(f"refusing to remove non-socket: {path}")
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as probe:
        probe.settimeout(1)
        try:
            probe.connect(path)
        except OSError as error:
            if error.errno != errno.ECONNREFUSED:
                raise
        else:
            raise RuntimeError(f"agent socket is already listening: {path}")
    after = os.lstat(path)
    if (before.st_dev, before.st_ino) != (after.st_dev, after.st_ino):
        raise RuntimeError(f"socket changed during probe: {path}")
    os.unlink(path)


if __name__ == "__main__":
    path, agent = sys.argv[1:]
    clear_stale_socket(path)
    os.execv(agent, [agent, "-D", "-a", path])
