"""Smoke-test Game's file and NDJSON bundles with and without a supplied environment."""

import hashlib
import json
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory


def check_bundle(executable, output, manifest=None):
    args = ["--environment", manifest] if manifest else []
    stream = subprocess.check_output([executable, "--ndjson", *args], cwd=output)
    records = [json.loads(line) for line in stream.splitlines()]
    assert not list(output.iterdir())
    bundle = {r["path"]: r["content"].encode("utf-8") for r in records}
    assert len(bundle) == len(records)
    env = bundle["environment.json"]
    if manifest:
        assert env == manifest.read_bytes()
    else:
        assert json.loads(env)["requiredImports"] == ["PlutusCore.UPLC.BlueprintEncoding.Assurance"]

    assurance = json.loads(bundle["assurance.json"])
    for ref in [assurance["blueprint"], *assurance["checkingContexts"].values()]:
        assert hashlib.sha256(bundle[ref["uri"]]).hexdigest() == ref["hash"]["digest"]
    for ref in assurance["checkingContexts"].values():
        env_ref = json.loads(bundle[ref["uri"]])["environment"]
        assert env_ref["uri"] == "environment.json"
        assert env_ref["hash"]["digest"] == hashlib.sha256(env).hexdigest()

    subprocess.run([executable, *args], check=True, cwd=output)
    assert bundle == {p.name: p.read_bytes() for p in output.iterdir()}


if __name__ == "__main__":
    executable = Path(sys.argv[1]).resolve()
    with TemporaryDirectory() as tmp:
        root = Path(tmp)
        manifest = root / "custom.json"
        manifest.write_bytes(b'{ "format": "test fixture" }\n')
        for directory, override in [("generated", None), ("supplied", manifest)]:
            output = root / directory
            output.mkdir()
            check_bundle(executable, output, override)
    print("File and stream outputs match, including both environment manifests and their references.")
