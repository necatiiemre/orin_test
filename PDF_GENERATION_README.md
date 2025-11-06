# PDF Report Generation for Jetson Orin Test Suite

This document describes how to generate PDF reports from test outputs.

## Overview

The PDF generation system converts test reports (TXT) and monitoring logs (CSV) into professionally formatted PDF documents with:
- **Formatted text reports** with proper sections and styling
- **CSV data tables** with colored headers
- **Charts and visualizations** for monitoring data
- **Combined PDFs** that include all test results in one document

## Installation

### Install Required Dependencies

```bash
# Install Python dependencies
pip3 install -r requirements.txt

# Or install manually
pip3 install reportlab matplotlib
```

### Verify Installation

```bash
python3 -c "import reportlab, matplotlib; print('Dependencies installed successfully')"
```

## Quick Start

### Generate All PDFs from Test Output

```bash
# After running tests, convert all reports to PDF
./generate_pdf_reports.sh test_output_20250106_120000
```

This will create individual PDFs for each report/log file, plus a combined PDF containing everything.

### Generate Combined PDF Only

```bash
# Create only a single combined PDF
./generate_pdf_reports.sh --combined-only test_output_20250106_120000
```

## Usage Examples

### 1. Batch Convert All Files

```bash
./generate_pdf_reports.sh test_output_20250106_120000
```

**Output:**
```
test_output_20250106_120000/
└── pdf_reports/
    ├── CPU_PERFORMANCE_REPORT.pdf
    ├── GPU_TEST_REPORT.pdf
    ├── ram_test_summary.pdf
    ├── DISK_PERFORMANCE_REPORT.pdf
    ├── COMBINED_TEST_REPORT.pdf
    ├── temperature_power_log.pdf
    ├── throttling_detection.pdf
    ├── test_output_20250106_120000_COMBINED.pdf  # All-in-one report
    └── chart_*.png  # Generated charts
```

### 2. Convert Single TXT Report

```bash
python3 pdf_report_generator.py \
    --txt-report test_output_20250106_120000/reports/CPU_PERFORMANCE_REPORT.txt \
    --output cpu_report.pdf
```

### 3. Convert Single CSV Log with Charts

```bash
python3 pdf_report_generator.py \
    --csv-log test_output_20250106_120000/monitoring/temperature_power_log.csv \
    --output temp_power.pdf
```

### 4. Convert CSV without Charts

```bash
./generate_pdf_reports.sh --no-charts test_output_20250106_120000
```

### 5. Add Logo to PDF Background

You can add a company logo or branding to the PDF background in various positions:

```bash
# Add logo as centered watermark (default, 10% opacity)
./generate_pdf_reports.sh --logo /path/to/logo.png test_output_20250106_120000

# Add logo in top-right corner
./generate_pdf_reports.sh --logo /path/to/logo.png --logo-position top-right test_output_20250106_120000

# Add logo with custom opacity (30% visible)
./generate_pdf_reports.sh --logo /path/to/logo.png --logo-opacity 0.3 test_output_20250106_120000

# Add logo in bottom-right corner with 50% opacity
./generate_pdf_reports.sh \
    --logo /path/to/logo.png \
    --logo-position bottom-right \
    --logo-opacity 0.5 \
    test_output_20250106_120000
```

**Logo Positions:**
- `watermark` - Centered, large (4x4 inches), perfect for background branding
- `top-right` - Top-right corner (1.5x1.5 inches)
- `top-left` - Top-left corner (1.5x1.5 inches)
- `bottom-right` - Bottom-right corner (1.5x1.5 inches)
- `bottom-left` - Bottom-left corner (1.5x1.5 inches)

**Logo Opacity:**
- `0.0` - Completely invisible
- `0.1` - Very subtle (10% visible, default for watermarks)
- `0.3` - Light (30% visible, good for corners)
- `0.5` - Medium (50% visible)
- `1.0` - Fully opaque (100% visible)

**Supported Logo Formats:**
- PNG (recommended, supports transparency)
- JPG/JPEG
- GIF
- BMP

## Python API Usage

You can also use the PDF generator programmatically in your Python scripts:

```python
from pdf_report_generator import PDFReportGenerator

# Initialize generator without logo
generator = PDFReportGenerator(output_dir='/path/to/output')

# Initialize generator with logo (watermark style)
generator_with_logo = PDFReportGenerator(
    output_dir='/path/to/output',
    logo_path='/path/to/logo.png',
    logo_position='watermark',
    logo_opacity=0.1
)

# Initialize generator with logo in corner
generator_corner_logo = PDFReportGenerator(
    output_dir='/path/to/output',
    logo_path='/path/to/company_logo.png',
    logo_position='top-right',
    logo_opacity=0.3
)

# Convert single TXT report
generator.convert_txt_report_to_pdf(
    'CPU_PERFORMANCE_REPORT.txt',
    'cpu_report.pdf'
)

# Convert CSV with charts
generator.convert_csv_to_pdf(
    'temperature_power_log.csv',
    'temp_power.pdf',
    include_charts=True
)

# Create combined PDF from directory
generator.create_combined_pdf(
    'test_output_20250106_120000',
    'combined_report.pdf'
)

# Batch convert all files in directory
pdf_files = generator.batch_convert_directory(
    'test_output_20250106_120000',
    create_combined=True
)
```

## Integration with Test Scripts

### Option 1: Manual Conversion After Tests

Run tests normally, then convert to PDF:

```bash
# Run tests
./jetson_combined_parallel_test.sh

# After tests complete, generate PDFs
./generate_pdf_reports.sh test_output_YYYYMMDD_HHMMSS
```

### Option 2: Automatic PDF Generation

Add PDF generation to the end of your test script:

```bash
# At the end of jetson_combined_parallel_test.sh
TEST_OUTPUT_DIR="test_output_$(date +%Y%m%d_%H%M%S)"

# Run tests...
# ...

# Generate PDFs automatically
echo "Generating PDF reports..."
./generate_pdf_reports.sh "$TEST_OUTPUT_DIR"
```

## Features

### Text Report Formatting

- **Automatic section detection** (=== and --- markers)
- **Bold key-value pairs** for easy reading
- **Monospace formatting** for data/logs
- **Page numbers and timestamps** in footer
- **Professional styling** with color-coded headers

### CSV Log Processing

- **Data tables** with formatted headers
- **Row limit** (first 100 rows shown to keep PDF size manageable)
- **Statistics display** (total rows, columns)
- **Automatic chart generation** for numeric columns

### Chart Generation

For CSV files, the generator automatically creates charts for:
- **Temperature monitoring** over time
- **Power consumption** trends
- **Performance metrics** visualization
- **Average/min/max indicators** on charts

Charts include:
- Line plots with markers
- Grid lines for easy reading
- Statistical reference lines (average)
- Proper axis labels and titles

### Combined PDF Features

The combined PDF includes:
- **Cover page** with test information
- **All text reports** with proper formatting
- **CSV summaries** with row/column counts
- **All charts** for monitoring data
- **Organized sections** (Reports, Monitoring Logs)
- **Page breaks** between sections

## Command-Line Options

### Shell Script (`generate_pdf_reports.sh`)

```bash
./generate_pdf_reports.sh [OPTIONS] <test_output_directory>

Options:
  --combined-only         Generate only combined PDF (skip individual PDFs)
  --no-charts             Disable chart generation for CSV files
  --test-type TYPE        Test type for organization (cpu, gpu, ram, storage, etc.)
  --logo FILE             Path to logo image file (PNG, JPG, etc.)
  --logo-position POS     Logo position: watermark, top-right, top-left, bottom-right, bottom-left
  --logo-opacity OPACITY  Logo opacity from 0.0 to 1.0 (default: 0.1)
  --help                  Show help message
```

### Python Script (`pdf_report_generator.py`)

```bash
python3 pdf_report_generator.py [OPTIONS]

Options:
  --txt-report FILE       Convert single TXT report to PDF
  --csv-log FILE          Convert single CSV log to PDF
  --batch DIR             Convert all files in directory (individual + combined)
  --combined DIR          Create only combined PDF from directory
  -o, --output FILE       Output PDF file path (for single conversions)
  --no-charts             Disable chart generation for CSV files
  --test-type TYPE        Test type for organization
  --output-base-dir DIR   Base directory for PDF output
  --logo FILE             Path to logo image file
  --logo-position POS     Logo position (watermark, top-right, etc.)
  --logo-opacity OPACITY  Logo opacity from 0.0 to 1.0
```

## Output Structure

After running PDF generation, your test output directory will look like:

```
test_output_20250106_120000/
├── logs/
│   ├── baseline.log
│   └── cpu_test.log
├── reports/
│   ├── CPU_PERFORMANCE_REPORT.txt
│   ├── GPU_TEST_REPORT.txt
│   └── COMBINED_TEST_REPORT.txt
├── monitoring/
│   ├── temperature_power_log.csv
│   └── throttling_detection.csv
└── pdf_reports/                          # NEW: PDF output directory
    ├── CPU_PERFORMANCE_REPORT.pdf        # Individual report PDFs
    ├── GPU_TEST_REPORT.pdf
    ├── COMBINED_TEST_REPORT.pdf
    ├── temperature_power_log.pdf         # CSV converted to PDF with charts
    ├── throttling_detection.pdf
    ├── chart_temperature_power_log.png   # Generated chart images
    ├── chart_throttling_detection.png
    └── test_output_20250106_120000_COMBINED.pdf  # All-in-one PDF
```

## File Size Considerations

The PDF generator includes optimizations to keep file sizes reasonable:

- **Text reports**: Full content included
- **CSV tables**: First 100 rows shown (with indication of total rows)
- **Charts**: Moderate resolution (100 DPI)
- **Combined PDFs**: First 200 lines per report

For very large test outputs, consider:
- Using `--combined-only` to generate just one PDF
- Using `--no-charts` to skip chart generation
- Converting only specific files with `--txt-report` or `--csv-log`

## Troubleshooting

### Missing Dependencies

```bash
# Error: reportlab is not installed
pip3 install reportlab

# Error: matplotlib is not installed
pip3 install matplotlib
```

### Permission Denied

```bash
# Make scripts executable
chmod +x generate_pdf_reports.sh pdf_report_generator.py
```

### Empty or Corrupt PDFs

- Ensure input files are valid and not empty
- Check that test reports completed successfully
- Verify CSV files have proper headers

### Charts Not Generating

- Ensure matplotlib is installed
- Check that CSV files contain numeric data
- Verify CSV files have headers and data rows

### Python Version

The PDF generator requires Python 3.6 or higher:

```bash
python3 --version  # Should be 3.6+
```

## Examples

### Example 1: Quick PDF Generation After Test

```bash
# Run test
./jetson_cpu_test.sh

# Find the output directory
ls -ltr | grep test_output

# Generate PDFs
./generate_pdf_reports.sh test_output_20250106_120000

# View PDFs
ls -lh test_output_20250106_120000/pdf_reports/
```

### Example 2: Convert Specific Reports

```bash
# Convert only CPU report
python3 pdf_report_generator.py \
    --txt-report test_output_20250106_120000/reports/CPU_PERFORMANCE_REPORT.txt

# Convert only temperature monitoring
python3 pdf_report_generator.py \
    --csv-log test_output_20250106_120000/monitoring/temperature_power_log.csv
```

### Example 3: Automated Daily Reports

```bash
#!/bin/bash
# daily_test_and_report.sh

# Run tests
./jetson_combined_parallel_test.sh

# Get latest test output directory
TEST_DIR=$(ls -td test_output_* | head -1)

# Generate PDFs
./generate_pdf_reports.sh "$TEST_DIR"

# Copy combined PDF to shared location
cp "$TEST_DIR/pdf_reports/"*_COMBINED.pdf /shared/reports/daily/
```

## PDF Customization

The PDF generator uses the following styling:

- **Page size**: Letter (8.5" x 11")
- **Margins**: 1 inch on all sides
- **Fonts**: Helvetica (headers), Courier (code/data)
- **Colors**: Blue headers, grey text, color-coded charts
- **Header/Footer**: Timestamp and page numbers

To customize styling, edit `pdf_report_generator.py` in the `_setup_custom_styles()` method.

## Integration with CI/CD

You can integrate PDF generation into CI/CD pipelines:

```yaml
# Example GitLab CI/CD
test_and_report:
  script:
    - ./jetson_combined_parallel_test.sh
    - TEST_DIR=$(ls -td test_output_* | head -1)
    - ./generate_pdf_reports.sh "$TEST_DIR"
  artifacts:
    paths:
      - test_output_*/pdf_reports/*.pdf
    expire_in: 30 days
```

## Performance

Typical conversion times (approximate):

- **Single TXT report** (10 KB): < 1 second
- **Single CSV log** (1 MB, 10K rows): 2-5 seconds
- **CSV with charts** (1 MB, 10K rows): 5-10 seconds
- **Batch conversion** (5 reports + 3 CSVs): 20-30 seconds
- **Combined PDF** (all files): 30-60 seconds

## Limitations

- CSV tables show first 100 rows only (to keep PDF size manageable)
- Text reports show first 200 lines in combined PDF
- Chart generation requires numeric data in CSV
- Very large files (> 100 MB) may take significant time to process

## Support

For issues or questions:

1. Check this README for common solutions
2. Verify dependencies are installed: `pip3 list | grep -E "(reportlab|matplotlib)"`
3. Run with verbose output: `python3 pdf_report_generator.py --help`
4. Check file permissions: `ls -l *.sh *.py`

## Files

- `pdf_report_generator.py` - Main PDF generation Python module
- `generate_pdf_reports.sh` - Shell script wrapper for easy usage
- `requirements.txt` - Python dependencies
- `PDF_GENERATION_README.md` - This documentation file

## License

Part of the Jetson Orin Test Suite
