from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent

ASM_FILES = [
    "bootloader.asm",
    "kernel.asm",
]


def find_nasm() -> str:
    candidates = [
        shutil.which("nasm"),
        str(Path.home() / "AppData" / "Local" / "bin" / "NASM" / "nasm.exe"),
        r"C:\Users\egetr\AppData\Local\bin\NASM\nasm.exe",
    ]

    for candidate in candidates:
        if candidate and Path(candidate).exists():
            return candidate

    raise FileNotFoundError(
        "NASM bulunamadı. PATH'e eklenmiş veya C:\\Users\\egetr\\AppData\\Local\\bin\\NASM\\nasm.exe konumunda olmalı."
    )


def compile_asm(nasm_path: str, src: Path) -> Path:
    out = src.with_suffix(".bin")
    cmd = [nasm_path, "-f", "bin", str(src), "-o", str(out)]
    print(f"[compile] {src.name} -> {out.name}")
    subprocess.run(cmd, check=True)
    return out


def build_image() -> Path:
    boot = ROOT / "bootloader.bin"
    if not boot.exists():
        raise FileNotFoundError("bootloader.bin oluşturulmadı. Önce derleme adımını çalıştırın.")

    kernel = ROOT / "kernel.bin"
    if not kernel.exists():
        raise FileNotFoundError("kernel.bin oluşturulmadı. Önce derleme adımını çalıştırın.")

    image_path = ROOT / "pck.img"
    image_path.write_bytes(boot.read_bytes() + kernel.read_bytes())
    print(f"[image] {image_path.name} oluşturuldu ({image_path.stat().st_size} bayt)")
    return image_path


def main() -> int:
    print("PCK gerçek OS build başlatıldı...")

    nasm_path = find_nasm()
    compiled = []

    for name in ASM_FILES:
        src = ROOT / name
        if src.exists():
            compiled.append(compile_asm(nasm_path, src))
        else:
            print(f"[skip] {name} mevcut değil")

    if not compiled:
        print("Derlenecek .asm dosyası bulunamadı.")
        return 1

    build_image()
    print("\nBitti. Üretilen dosyalar:")
    for path in sorted(ROOT.glob("*.bin")):
        print(f" - {path.name} ({path.stat().st_size} bytes)")
    print(f" - pck.img ({(ROOT / 'pck.img').stat().st_size} bytes)")
    print("\nNot: gerçek OS akışı bootloader.bin + kernel.bin üzerinden çalışır.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # pragma: no cover
        print(f"[error] {exc}", file=sys.stderr)
        raise SystemExit(1)
