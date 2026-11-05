import json
import sys
from collections import Counter
from pathlib import Path


reports_dir = Path(sys.argv[1])
lines = [
    "# Результаты Trivy", "",
    "Количество находок по установленным пакетам, включая находки без исправления.", "",
    "| Образ | HIGH | CRITICAL |",
    "|-------|-----:|---------:|",
]
dates = []
for name in ["backend", "frontend"]:
    report = json.loads((reports_dir / f"{name}.json").read_text())
    findings = [
        vulnerability
        for result in report.get("Results", [])
        for vulnerability in result.get("Vulnerabilities", [])
    ]
    counts = Counter(item["Severity"] for item in findings)
    lines.append(f"| {report['ArtifactName']} | {counts['HIGH']} | {counts['CRITICAL']} |")
    dates.append(f"Дата сканирования {name}: {report.get('CreatedAt', 'не указана')}")
lines.extend(["", *dates, ""])
text = "\n".join(lines) + "\n"
(reports_dir / "summary.md").write_text(text)
print(text, end="")
