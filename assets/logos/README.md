# Logo Directory

Place your logo files (PNG, JPG, etc.) in this directory for use with PDF reports.

## Usage

After placing your logo file here, reference it in the PDF generator:

```bash
# Using logo from this directory
./generate_pdf_reports.sh --logo assets/logos/your_logo.png test_output_20250106_120000

# Or with full path
./generate_pdf_reports.sh --logo /home/user/orin_test/assets/logos/your_logo.png test_output_20250106_120000
```

## Recommended Logo Formats

- **PNG** (best choice - supports transparency)
- JPG/JPEG
- GIF
- BMP

## Recommended Logo Specifications

- **For watermark**: Square image (e.g., 500x500px or larger)
- **For corner logos**: Square or rectangular (e.g., 300x300px)
- **Transparent background** (PNG) works best for watermarks
- **High resolution** ensures quality in PDFs
