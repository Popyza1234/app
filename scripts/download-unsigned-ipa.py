#!/usr/bin/env python3
"""Download dekpop-unsigned.ipa from a successful GitHub Actions build.

Uses the GitHub credential already cached by Git Credential Manager on this
machine (`git credential fill`). The token is kept in memory and is never
printed, logged, or written to disk.

Usage:
    python scripts/download-unsigned-ipa.py
    python scripts/download-unsigned-ipa.py --repo owner/repo --output my.ipa
    python scripts/download-unsigned-ipa.py --run-id 43250078558
"""

from __future__ import annotations

import argparse
import io
import json
import os
import plistlib
import subprocess
import sys
import urllib.error
import urllib.request
import zipfile

API = "https://api.github.com"
WORKFLOW_NAME = "Build unsigned IPA"
ARTIFACT_NAME = "dekpop-unsigned-ipa"
DEFAULT_REPO = "Popyza1234/app"
DEFAULT_OUTPUT = "dekpop-unsigned.ipa"
APP_BUNDLE = "dekpop.app"
UA = "dekpop-artifact-downloader"


class NoRedirect(urllib.request.HTTPRedirectHandler):
    """Stop at the 302 so the Authorization header is not sent to the CDN."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def cached_credential() -> tuple[str, str]:
    env = os.environ.copy()
    env["GIT_TERMINAL_PROMPT"] = "0"
    env["GCM_INTERACTIVE"] = "Never"
    result = subprocess.run(
        ["git", "credential", "fill"],
        input="protocol=https\nhost=github.com\n\n",
        text=True,
        capture_output=True,
        env=env,
        timeout=30,
    )
    if result.returncode != 0:
        raise RuntimeError(
            "No cached GitHub credential. Run scripts\\push-now.cmd first, "
            "or sign in once with 'git push -u origin main'."
        )
    creds = dict(
        line.split("=", 1) for line in result.stdout.splitlines() if "=" in line
    )
    token = creds.get("password")
    if not token:
        raise RuntimeError("git credential fill returned no token.")
    return creds.get("username", "unknown"), token


def api_get(path: str, token: str):
    req = urllib.request.Request(
        API + path,
        headers={
            "Authorization": "Bearer " + token,
            "Accept": "application/vnd.github+json",
            "User-Agent": UA,
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.load(response)


def download_bytes(url: str, token: str) -> bytes:
    req = urllib.request.Request(
        url,
        headers={
            "Authorization": "Bearer " + token,
            "Accept": "application/vnd.github+json",
            "User-Agent": UA,
        },
    )
    opener = urllib.request.build_opener(NoRedirect)
    try:
        with opener.open(req, timeout=40) as response:
            return response.read()
    except urllib.error.HTTPError as exc:
        if exc.code in (301, 302, 303, 307, 308):
            location = exc.headers.get("Location")
            if not location:
                raise
            # Signed CDN URL: no Authorization header here.
            with urllib.request.urlopen(
                urllib.request.Request(location, headers={"User-Agent": UA}),
                timeout=120,
            ) as response:
                return response.read()
        raise RuntimeError(
            "GitHub returned HTTP %s. The cached credential may lack the "
            "actions:read scope; download the artifact from the Actions page instead."
            % exc.code
        ) from None


def find_artifact(repo: str, token: str, run_id: int | None):
    if run_id:
        runs = [api_get("/repos/%s/actions/runs/%d" % (repo, run_id), token)]
    else:
        listing = api_get(
            "/repos/%s/actions/runs?per_page=20&status=success" % repo, token
        )
        runs = [
            r
            for r in listing.get("workflow_runs", [])
            if r.get("name") == WORKFLOW_NAME
            and r.get("conclusion") == "success"
        ]
        if not runs:
            raise RuntimeError(
                "No successful '%s' run found for %s." % (WORKFLOW_NAME, repo)
            )
    for run in runs:
        artifacts = api_get(
            "/repos/%s/actions/runs/%d/artifacts" % (repo, run["id"]), token
        )
        for art in artifacts.get("artifacts", []):
            if art["name"] == ARTIFACT_NAME and not art.get("expired"):
                return run, art
    raise RuntimeError(
        "Artifact '%s' not found (it expires after 14 days). "
        "Re-run the workflow in the Actions tab." % ARTIFACT_NAME
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=DEFAULT_REPO, help="owner/repo")
    parser.add_argument("--run-id", type=int, help="specific workflow run id")
    parser.add_argument("--output", default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    try:
        user, token = cached_credential()
        print("==> Using cached GitHub credential for %s (token not shown)" % user)
        run, art = find_artifact(args.repo, token, args.run_id)
        print("==> Run #%s: %s (%s)" % (run["id"], run["name"], run["html_url"]))
        print("==> Artifact: %s (%s bytes)" % (art["name"], art.get("size_in_bytes")))

        payload = download_bytes(
            API + "/repos/%s/actions/artifacts/%d/zip" % (args.repo, art["id"]),
            token,
        )
        bundle = zipfile.ZipFile(io.BytesIO(payload))
        ipa_name = next((n for n in bundle.namelist() if n.endswith(".ipa")), None)
        if not ipa_name:
            raise RuntimeError("No .ipa inside the artifact: %s" % bundle.namelist())
        ipa = bundle.read(ipa_name)

        root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        out = args.output if os.path.isabs(args.output) else os.path.join(root, args.output)
        with open(out, "wb") as handle:
            handle.write(ipa)

        app = zipfile.ZipFile(io.BytesIO(ipa))
        plist_path = "Payload/%s/Info.plist" % APP_BUNDLE
        if plist_path not in app.namelist():
            raise RuntimeError("Unexpected IPA layout (missing %s)." % plist_path)
        info = plistlib.loads(app.read(plist_path))
        signed = any(
            n.startswith("Payload/%s/_CodeSignature" % APP_BUNDLE)
            for n in app.namelist()
        )
        print("==> Saved: %s (%d bytes)" % (out, len(ipa)))
        print("    Display name     : %s" % info.get("CFBundleDisplayName"))
        print("    Bundle ID        : %s" % info.get("CFBundleIdentifier"))
        print("    Version          : %s (%s)" % (
            info.get("CFBundleShortVersionString"), info.get("CFBundleVersion")))
        print("    MinimumOSVersion : %s" % info.get("MinimumOSVersion"))
        print("    Code signed      : %s" % ("yes" if signed else "NO - unsigned"))
        print("==> Next: sign it with ESign or scripts/resign-windows-zsign.ps1")
        return 0
    except (RuntimeError, urllib.error.URLError, OSError, zipfile.BadZipFile) as exc:
        print("error: %s" % exc, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
