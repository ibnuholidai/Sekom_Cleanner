import argparse
import json
import os
import subprocess
import sys
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Dict, List, Tuple

# -------------------- Utilities --------------------

def _run_cmd(cmd: List[str], timeout: int = 8) -> Tuple[int, str, str]:
    try:
        # Lower priority to avoid impacting UI responsiveness; keep console hidden.
        flags = subprocess.CREATE_NO_WINDOW
        try:
            flags |= getattr(subprocess, "BELOW_NORMAL_PRIORITY_CLASS", 0x00004000)  # Windows priority class
        except Exception:
            flags = subprocess.CREATE_NO_WINDOW  # fallback
        proc = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout,
            creationflags=flags
        )
        return proc.returncode, proc.stdout or "", proc.stderr or ""
    except subprocess.TimeoutExpired:
        return 124, "", "timeout"
    except Exception as e:
        return 1, "", str(e)


def _safe_int(s: str, default: int = 0) -> int:
    try:
        return int(s)
    except Exception:
        return default


# -------------------- Folder Sizes --------------------

def get_user_profile() -> str:
    # Prefer USERPROFILE on Windows
    return os.environ.get("USERPROFILE") or os.path.expanduser("~")


def dir_size_walk(path: str) -> int:
    total = 0
    for root, dirs, files in os.walk(path, topdown=True):
        # prune directories if needed (none now)
        for f in files:
            try:
                fp = os.path.join(root, f)
                total += os.path.getsize(fp)
            except Exception:
                pass
    return total


def calc_folder_sizes() -> List[Dict]:
    names = ["3D Objects", "Documents", "Downloads", "Music", "Pictures", "Videos"]
    base = get_user_profile()
    results: List[Dict] = []
    lock = threading.Lock()

    def task(name: str):
        p = os.path.join(base, name)
        exists = os.path.exists(p) and os.path.isdir(p)
        sz = 0
        if exists:
            try:
                sz = dir_size_walk(p)
            except Exception:
                sz = 0
        with lock:
            results.append({
                "Name": name,
                "Path": p,
                "Exists": exists,
                "SizeBytes": int(sz)
            })

    # Use moderate parallelism to avoid heavy disk thrashing
    max_workers = max(2, os.cpu_count() - 1 if os.cpu_count() else 2)
    with ThreadPoolExecutor(max_workers=max_workers) as ex:
        futs = [ex.submit(task, n) for n in names]
        for _ in as_completed(futs):
            pass

    # Preserve order
    ordered = sorted(results, key=lambda x: names.index(x["Name"]) if x["Name"] in names else 999)
    return ordered


# -------------------- Activation (Windows/Office) --------------------

def parse_windows_activation() -> Dict:
    """
    Use slmgr.vbs outputs; avoid PowerShell CIM to reduce risk of environment-specific failures.
    Add cscript time limits to prevent indefinite hangs on some systems.
    """
    status = "❓ Cannot check"
    detail = None
    active = False
    needs = False
    info: Dict[str, str] = {}

    # Use batch mode with explicit script timeout to avoid long hangs.
    # Note: //T:nn limits script execution time (seconds). We also keep our subprocess timeout.
    xpr_cmd = ["cscript", "//nologo", "//B", "//T:10", r"C:\Windows\System32\slmgr.vbs", "/xpr"]
    dlv_cmd = ["cscript", "//nologo", "//B", "//T:12", r"C:\Windows\System32\slmgr.vbs", "/dlv"]

    # /xpr gives overall activation status (permanent or expiration)
    rc_xpr, out_xpr, _ = _run_cmd(xpr_cmd, timeout=12)
    # /dlv provides details we can parse (edition, channel, partial key)
    rc_dlv, out_dlv, _ = _run_cmd(dlv_cmd, timeout=15)

    if rc_dlv == 0 and out_dlv:
        # Try extract edition, channel (Description), partial key
        try:
            for line in out_dlv.splitlines():
                low = line.lower().strip()
                if "description:" in low:
                    desc = line.split(":", 1)[1].strip()
                    info["channel"] = desc
                if line.lower().startswith("name:"):
                    edition = line.split(":", 1)[1].strip()
                    info["edition"] = edition
                if "partial product key:" in low:
                    part = line.split(":", 1)[1].strip()
                    info["partialKey"] = part
        except Exception:
            pass

    if rc_xpr == 0 and out_xpr:
        lower = out_xpr.lower()
        if "permanently activated" in lower:
            active = True
            status = "✅ Activated"
            ch = info.get("channel", "")
            detail = f"Aktif permanen{(' (' + ch + ')') if ch else ''}"
        elif ("will expire" in lower) or ("activated until" in lower) or ("grace" in lower):
            active = False
            status = "⚠️ Grace/Not activated"
            detail = out_xpr.strip()
            needs = True
        else:
            status = "❓ Cannot check"
            detail = out_xpr.strip()
    else:
        # If /xpr fails but /dlv returns something
        if rc_dlv == 0 and out_dlv:
            # Heuristic: if Description contains "retail" or "mak" assume active but unclear
            desc = info.get("channel", "").lower()
            if any(k in desc for k in ("retail", "mak", "oem", "volume", "kms")):
                active = True
                status = "✅ Activated"
                detail = f"Channel: {info.get('channel','')}"
            else:
                status = "❓ Cannot check"
        else:
            # Both failed (likely timeout or policy). Return a deferred status instead of hard failure.
            status = "⏳ Ditunda (akan diperbarui)"
            detail = "slmgr timeout/policy; coba ulang di background"

    return {
        "status": status,
        "isActive": active,
        "needsUpdate": needs,
        "detail": detail or "",
        "info": info
    }


def main():
    parser = argparse.ArgumentParser(description="Sekom Python checks")
    parser.add_argument("--folder-sizes", action="store_true", help="Output known user folder sizes as JSON")
    parser.add_argument("--windows-activation", action="store_true", help="Output Windows activation status JSON")
    args = parser.parse_args()

    try:
        if args.folder_sizes:
            data = calc_folder_sizes()
            print(json.dumps(data, separators=(",", ":")))
            return
        if args.windows_activation:
            data = parse_windows_activation()
            print(json.dumps(data, separators=(",", ":")))
            return

        # If no option given, print help-like JSON
        print(json.dumps({"error": "no_action", "message": "Specify --folder-sizes or --windows-activation"}))
    except Exception as e:
        print(json.dumps({"error": "exception", "message": str(e)}))
        sys.exit(1)


if __name__ == "__main__":
    main()
