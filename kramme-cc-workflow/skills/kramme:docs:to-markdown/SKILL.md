---
name: kramme:docs:to-markdown
description: Convert documents and files to Markdown using markitdown. Use when converting PDF, Word (.docx), PowerPoint (.pptx), Excel (.xlsx, .xls), HTML, CSV, JSON, XML, images (with EXIF/OCR), audio (with transcription), ZIP archives, YouTube URLs, or EPubs to Markdown format for LLM processing or text analysis.
disable-model-invocation: false
user-invocable: true
---

# Markdown Converter

Convert files to Markdown with `markitdown`, run on demand via `uvx` — no manual install of markitdown.

**Requires `uv`** (which provides `uvx`). If you hit `uvx: command not found`, install `uv` (https://docs.astral.sh/uv/getting-started/installation/), or fall back to `pipx run 'markitdown[all]'` or `pip install 'markitdown[all]'` and call `markitdown` directly.

**Always pass the `[all]` extras.** PDF, Word, PowerPoint, Excel, audio transcription, and YouTube support ship as optional dependencies; bare `uvx markitdown` omits them and fails on those formats with a missing-dependency error. Use the `uvx --from 'markitdown[all]' markitdown …` form shown below.

## Basic Usage

```bash
# Convert to stdout
uvx --from 'markitdown[all]' markitdown input.pdf

# Save to file
uvx --from 'markitdown[all]' markitdown input.pdf -o output.md
uvx --from 'markitdown[all]' markitdown input.docx > output.md

# From stdin (add -x to hint the file type)
cat input.pdf | uvx --from 'markitdown[all]' markitdown -x .pdf > output.md
```

Before passing `-o` (or redirecting to a file), check whether the output path exists; if it does, confirm with the user or choose a new name before writing.

## Supported Formats

- **Documents**: PDF, Word (.docx), PowerPoint (.pptx), Excel (.xlsx, .xls)
- **Web/Data**: HTML, CSV, JSON, XML
- **Media**: Images (EXIF + OCR), Audio (EXIF + transcription)
- **Other**: ZIP (iterates contents), YouTube URLs, EPub

## Options

```bash
-o OUTPUT          # Output file (overwrites without confirmation)
-x EXTENSION       # Hint file extension (for stdin)
-m MIME_TYPE       # Hint MIME type
-c CHARSET         # Hint charset (e.g., UTF-8)
-d                 # Use Azure Document Intelligence
-e ENDPOINT        # Document Intelligence endpoint
-p, --use-plugins  # Enable 3rd-party plugins
--list-plugins     # Show installed plugins
--keep-data-uris   # Keep data URIs in output
```

## Examples

```bash
# Convert Word document
uvx --from 'markitdown[all]' markitdown report.docx -o report.md

# Convert Excel spreadsheet
uvx --from 'markitdown[all]' markitdown data.xlsx > data.md

# Convert PowerPoint presentation
uvx --from 'markitdown[all]' markitdown slides.pptx -o slides.md

# Use Azure Document Intelligence for better PDF extraction
uvx --from 'markitdown[all]' markitdown scan.pdf -d -e "https://your-resource.cognitiveservices.azure.com/"
```

## Security

markitdown reads files and fetches URLs (YouTube, HTML, remote URIs) with the current process's privileges — like `open()` or `requests.get()`. Don't point it at untrusted files or URLs in shared or hosted contexts without validating them first (restrict file paths, URI schemes, and network destinations). See markitdown's Security Considerations.

## Notes

- Output preserves document structure: headings, tables, lists, links
- `-o` overwrites the target file silently; check whether the output path exists first, and if it does, confirm with the user or choose a new name before passing `-o`
- First run caches dependencies; subsequent runs are faster
- On a missing-dependency error for a format, confirm the `[all]` extras are present (or install just the per-format extra, e.g. `'markitdown[pdf]'`); for complex PDFs with poor extraction, use `-d` with Azure Document Intelligence
- When piping via stdin, prefer `-x` (and optionally `-m`/`-c`) for better detection
