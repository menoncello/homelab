#!/usr/bin/env python3
"""
Calibre Library Converter - Converts all books to EPUB format
Run daily to ensure all books have EPUB format available
"""

import subprocess
import json
import sys
from pathlib import Path

# Configuration
CALIBRE_LIBRARY = "/calibre-library"
CONVERT_FROM = ["mobi", "azw3", "azw", "djvu", "txt", "rtf"]  # PDF excluded - poor conversion quality
CONVERT_TO = "epub"

def run_command(cmd):
    """Run a shell command and return output"""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=300
        )
        return result.returncode == 0, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return False, "", "Command timed out"
    except Exception as e:
        return False, "", str(e)

def get_all_books():
    """Get all book IDs from library"""
    success, stdout, stderr = run_command(f"calibredb list --library-path {CALIBRE_LIBRARY} --for-machine --fields id,formats")
    if not success:
        print(f"Error listing books: {stderr}")
        return []

    books = []
    for line in stdout.strip().split('\n'):
        if line:
            parts = line.split(',')
            if len(parts) >= 2:
                book_id = parts[0].strip()
                formats = parts[1].strip() if len(parts) > 1 else ""
                books.append((book_id, formats))
    return books

def convert_book(book_id, source_format, target_format):
    """Convert a book from one format to another"""
    # Get the book info to find source file
    success, stdout, stderr = run_command(
        f"calibredb show {book_id} --library-path {CALIBRE_LIBRARY} --format json"
    )
    if not success:
        return False, f"Failed to get book info: {stderr}"

    try:
        book_data = json.loads(stdout)
    except json.JSONDecodeError:
        return False, "Failed to parse book info"

    # Find source format path
    source_path = None
    if book_data and len(book_data) > 0:
        book_info = book_data[0]
        if 'format_metadata' in book_info:
            for fmt in book_info['format_metadata']:
                if fmt.lower() == source_format.lower():
                    # Get the actual file path
                    success, stdout, stderr = run_command(
                        f"calibredb show {book_id} --library-path {CALIBRE_LIBRARY} "
                        f"--fields '{source_format}:'{source_format}'' --for-machine"
                    )
                    if success and stdout.strip():
                        source_path = stdout.strip().split(',')[-1]
                    break

    if not source_path or not Path(source_path).exists():
        # Alternative: find the file in library
        success, stdout, stderr = run_command(
            f"find {CALIBRE_LIBRARY} -name '*_{book_id}.{source_format}'"
        )
        if success and stdout.strip():
            source_path = stdout.strip().split('\n')[0]

    if not source_path or not Path(source_path).exists():
        return False, f"Source file not found for {source_format}"

    # Create output path
    source_obj = Path(source_path)
    output_path = source_obj.parent / f"{source_obj.stem}.{target_format}"

    # Convert using ebook-convert
    cmd = f"ebook-convert '{source_path}' '{output_path}'"
    success, stdout, stderr = run_command(cmd)

    if not success:
        return False, f"Conversion failed: {stderr}"

    # Add converted format to library
    success, stdout, stderr = run_command(
        f"calibredb add_format --library-path {CALIBRE_LIBRARY} {book_id} '{output_path}'"
    )

    if success:
        # Optionally remove the converted file from disk (Calibre copies it)
        try:
            Path(output_path).unlink(missing_ok=True)
        except:
            pass
        return True, f"Converted {source_format} → {target_format}"
    else:
        return False, f"Failed to add format to library: {stderr}"

def main():
    print("🔄 Calibre Library Converter - Starting...")
    print(f"Library: {CALIBRE_LIBRARY}")
    print(f"Target format: {CONVERT_TO}")
    print("-" * 50)

    books = get_all_books()
    print(f"📚 Found {len(books)} books in library")

    converted = 0
    skipped = 0
    errors = 0

    for book_id, formats in books:
        # Check if already has EPUB
        if formats and CONVERT_TO.lower() in formats.lower():
            skipped += 1
            continue

        # Find a convertible format
        source_fmt = None
        if formats:
            available_formats = [f.strip().lower() for f in formats.split('|')]
            for fmt in CONVERT_FROM:
                if fmt in available_formats:
                    source_fmt = fmt
                    break

        if not source_fmt:
            # Book has no convertible format
            continue

        print(f"\n📖 Converting book #{book_id} ({source_fmt} → {CONVERT_TO})...")
        success, message = convert_book(book_id, source_fmt, CONVERT_TO)

        if success:
            print(f"   ✅ {message}")
            converted += 1
        else:
            print(f"   ❌ {message}")
            errors += 1

    print("-" * 50)
    print(f"✨ Conversion complete!")
    print(f"   Converted: {converted}")
    print(f"   Skipped: {skipped} (already have EPUB)")
    print(f"   Errors: {errors}")

    return 0

if __name__ == "__main__":
    sys.exit(main())
