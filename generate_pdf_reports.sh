#!/bin/bash
###############################################################################
# PDF Report Generator Wrapper Script
#
# This script provides an easy interface to generate PDF reports from
# Jetson Orin test output files
#
# Usage:
#   ./generate_pdf_reports.sh [OPTIONS] <test_output_directory>
#
# Options:
#   --combined-only     Generate only a combined PDF (skip individual PDFs)
#   --no-charts         Disable chart generation for CSV files
#   --help              Show this help message
#
# Examples:
#   ./generate_pdf_reports.sh test_output_20250106_120000
#   ./generate_pdf_reports.sh --combined-only test_output_20250106_120000
###############################################################################

set -e  # Exit on error

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PDF_GENERATOR="$SCRIPT_DIR/pdf_report_generator.py"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check dependencies
check_dependencies() {
    log_info "Checking Python dependencies..."

    if ! command -v python3 &> /dev/null; then
        log_error "python3 is not installed"
        exit 1
    fi

    # Check if required Python packages are installed
    python3 -c "import reportlab" 2>/dev/null || {
        log_warning "reportlab is not installed"
        log_info "Installing dependencies from requirements.txt..."
        pip3 install -r "$SCRIPT_DIR/requirements.txt" --user || {
            log_error "Failed to install dependencies"
            log_info "Please install manually with: pip3 install reportlab matplotlib"
            exit 1
        }
    }

    python3 -c "import matplotlib" 2>/dev/null || {
        log_warning "matplotlib is not installed"
        log_info "Installing dependencies from requirements.txt..."
        pip3 install -r "$SCRIPT_DIR/requirements.txt" --user || {
            log_error "Failed to install dependencies"
            log_info "Please install manually with: pip3 install reportlab matplotlib"
            exit 1
        }
    }

    log_success "All dependencies are installed"
}

# Function to show help
show_help() {
    cat << EOF
PDF Report Generator for Jetson Orin Test Suite

Usage:
  $0 [OPTIONS] <test_output_directory>

Options:
  --combined-only     Generate only a combined PDF (skip individual PDFs)
  --no-charts         Disable chart generation for CSV files
  --test-type TYPE    Test type for organization (cpu, gpu, ram, storage, etc.)
  --help              Show this help message

Examples:
  # Generate all PDFs (individual + combined)
  $0 test_output_20250106_120000

  # Generate PDFs for CPU test only
  $0 --test-type cpu test_output_20250106_120000

  # Generate only combined PDF
  $0 --combined-only test_output_20250106_120000

  # Generate PDFs without charts
  $0 --no-charts test_output_20250106_120000

Description:
  This script converts test reports (TXT) and monitoring logs (CSV) to
  formatted PDF files with charts and visualizations.

  Output PDFs will be saved in: <test_output_directory>/pdf_reports/[test_type]/

EOF
}

# Parse arguments
COMBINED_ONLY=false
NO_CHARTS=""
TEST_TYPE=""
OUTPUT_BASE_DIR=""
TEST_OUTPUT_DIR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --combined-only)
            COMBINED_ONLY=true
            shift
            ;;
        --no-charts)
            NO_CHARTS="--no-charts"
            shift
            ;;
        --test-type)
            TEST_TYPE="$2"
            shift 2
            ;;
        --output-base-dir)
            OUTPUT_BASE_DIR="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        -*)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            TEST_OUTPUT_DIR="$1"
            shift
            ;;
    esac
done

# Validate input
if [ -z "$TEST_OUTPUT_DIR" ]; then
    log_error "No test output directory specified"
    show_help
    exit 1
fi

if [ ! -d "$TEST_OUTPUT_DIR" ]; then
    log_error "Directory not found: $TEST_OUTPUT_DIR"
    exit 1
fi

if [ ! -f "$PDF_GENERATOR" ]; then
    log_error "PDF generator script not found: $PDF_GENERATOR"
    exit 1
fi

# Check dependencies
check_dependencies

# Make PDF generator executable
chmod +x "$PDF_GENERATOR"

# Generate PDFs
log_info "Starting PDF generation..."
log_info "Test output directory: $TEST_OUTPUT_DIR"

# Build test type option
TEST_TYPE_OPT=""
if [ -n "$TEST_TYPE" ]; then
    TEST_TYPE_OPT="--test-type $TEST_TYPE"
    log_info "Test type: $TEST_TYPE"
fi

# Build output base dir option
OUTPUT_BASE_DIR_OPT=""
if [ -n "$OUTPUT_BASE_DIR" ]; then
    OUTPUT_BASE_DIR_OPT="--output-base-dir $OUTPUT_BASE_DIR"
    log_info "Output base directory: $OUTPUT_BASE_DIR"
fi

if [ "$COMBINED_ONLY" = true ]; then
    log_info "Mode: Combined PDF only"
    python3 "$PDF_GENERATOR" --combined "$TEST_OUTPUT_DIR" $NO_CHARTS $TEST_TYPE_OPT $OUTPUT_BASE_DIR_OPT
else
    log_info "Mode: Individual + Combined PDFs"
    python3 "$PDF_GENERATOR" --batch "$TEST_OUTPUT_DIR" $NO_CHARTS $TEST_TYPE_OPT $OUTPUT_BASE_DIR_OPT
fi

# Check if PDFs were generated
if [ -n "$OUTPUT_BASE_DIR" ]; then
    # Custom output directory
    if [ -n "$TEST_TYPE" ]; then
        PDF_DIR="$OUTPUT_BASE_DIR/$TEST_TYPE"
    else
        PDF_DIR="$OUTPUT_BASE_DIR"
    fi
elif [ -n "$TEST_TYPE" ]; then
    # Default with test type
    PDF_DIR="$TEST_OUTPUT_DIR/pdf_reports/$TEST_TYPE"
else
    # Default without test type
    PDF_DIR="$TEST_OUTPUT_DIR/pdf_reports"
fi
if [ -d "$PDF_DIR" ]; then
    PDF_COUNT=$(find "$PDF_DIR" -name "*.pdf" | wc -l)
    if [ "$PDF_COUNT" -gt 0 ]; then
        log_success "Generated $PDF_COUNT PDF file(s)"
        log_info "PDF files saved in: $PDF_DIR"
        echo ""
        ls -lh "$PDF_DIR"/*.pdf 2>/dev/null | awk '{print "  - " $9 " (" $5 ")"}'
    else
        log_warning "No PDF files were generated"
    fi
else
    log_warning "PDF output directory was not created"
fi

echo ""
log_success "PDF generation complete!"
