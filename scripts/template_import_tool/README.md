Template Import Tool (local)

Lightweight Swift CLI to help you:
- Generate a robust prompt for converting natural text → ProjectTemplate JSON
- Validate template JSON (modern ProjectTemplate or legacy steps format)
- Convert legacy JSON → modern JSON

Usage

- Generate prompt from natural text
  - echo "...your Japanese natural description..." > input.txt
  - swift scripts/template_import_tool/TemplateImportTool.swift make-prompt --in input.txt > prompt.txt

- Validate a JSON file
  - swift scripts/template_import_tool/TemplateImportTool.swift validate --json tsurutsu-template.json

- Convert legacy → modern JSON
  - swift scripts/template_import_tool/TemplateImportTool.swift convert --in tsurutsu-template.json --out modern.json

- Print sample JSON (modern/legacy)
  - swift scripts/template_import_tool/TemplateImportTool.swift sample modern
  - swift scripts/template_import_tool/TemplateImportTool.swift sample legacy

Notes
- No dependencies; uses Foundation only; safe to run locally.
- Validation mirrors app expectations (enums, required fields) at a high level.
- The generated prompt is designed for LLMs (ChatGPT/Claude/etc.) to return valid JSON only.

