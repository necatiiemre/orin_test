#!/usr/bin/env python3
"""
PDF Report Generator for Jetson Orin Test Suite
Converts TXT reports and CSV monitoring logs to formatted PDF files
"""

import os
import sys
import csv
import argparse
from datetime import datetime
from typing import List, Dict, Tuple, Optional
import io

try:
    from reportlab.lib import colors
    from reportlab.lib.pagesizes import letter, A4
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.units import inch
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, Image
    from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT
    from reportlab.pdfgen import canvas
except ImportError:
    print("ERROR: reportlab is not installed. Please install it with:")
    print("  pip3 install reportlab")
    sys.exit(1)

try:
    import matplotlib
    matplotlib.use('Agg')  # Non-interactive backend
    import matplotlib.pyplot as plt
    import matplotlib.dates as mdates
except ImportError:
    print("ERROR: matplotlib is not installed. Please install it with:")
    print("  pip3 install matplotlib")
    sys.exit(1)


class PDFReportGenerator:
    """Generate PDF reports from test output files"""

    def __init__(self, output_dir: str = None):
        """
        Initialize PDF report generator

        Args:
            output_dir: Directory where PDF files will be saved
        """
        self.output_dir = output_dir or os.getcwd()
        self.styles = getSampleStyleSheet()
        self._setup_custom_styles()

    def _setup_custom_styles(self):
        """Setup custom paragraph styles"""
        # Title style
        self.styles.add(ParagraphStyle(
            name='CustomTitle',
            parent=self.styles['Heading1'],
            fontSize=18,
            textColor=colors.HexColor('#1a5490'),
            spaceAfter=30,
            alignment=TA_CENTER,
            fontName='Helvetica-Bold'
        ))

        # Section header style
        self.styles.add(ParagraphStyle(
            name='SectionHeader',
            parent=self.styles['Heading2'],
            fontSize=14,
            textColor=colors.HexColor('#2c5aa0'),
            spaceAfter=12,
            spaceBefore=12,
            fontName='Helvetica-Bold'
        ))

        # Subsection header style
        self.styles.add(ParagraphStyle(
            name='SubsectionHeader',
            parent=self.styles['Heading3'],
            fontSize=12,
            textColor=colors.HexColor('#3d6bb3'),
            spaceAfter=8,
            spaceBefore=8,
            fontName='Helvetica-Bold'
        ))

        # Monospace style for code/logs
        self.styles.add(ParagraphStyle(
            name='CodeStyle',
            parent=self.styles['Code'],
            fontSize=9,
            fontName='Courier',
            leftIndent=20,
            spaceAfter=6
        ))

        # Info box style
        self.styles.add(ParagraphStyle(
            name='InfoBox',
            parent=self.styles['Normal'],
            fontSize=10,
            textColor=colors.HexColor('#555555'),
            leftIndent=10,
            rightIndent=10,
            spaceAfter=10
        ))

    def _create_header_footer(self, canvas_obj, doc):
        """Create header and footer for each page"""
        canvas_obj.saveState()

        # Footer
        canvas_obj.setFont('Helvetica', 8)
        canvas_obj.setFillColor(colors.grey)
        canvas_obj.drawString(
            inch, 0.5 * inch,
            f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
        )
        canvas_obj.drawRightString(
            letter[0] - inch, 0.5 * inch,
            f"Page {doc.page}"
        )

        canvas_obj.restoreState()

    def convert_txt_report_to_pdf(self, txt_file: str, pdf_file: str = None) -> str:
        """
        Convert a TXT report file to formatted PDF

        Args:
            txt_file: Path to input TXT file
            pdf_file: Path to output PDF file (optional)

        Returns:
            Path to generated PDF file
        """
        if not os.path.exists(txt_file):
            raise FileNotFoundError(f"Report file not found: {txt_file}")

        # Generate output filename if not provided
        if pdf_file is None:
            base_name = os.path.splitext(os.path.basename(txt_file))[0]
            pdf_file = os.path.join(self.output_dir, f"{base_name}.pdf")

        # Read the text file
        with open(txt_file, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()

        # Create PDF document
        doc = SimpleDocTemplate(
            pdf_file,
            pagesize=letter,
            rightMargin=72,
            leftMargin=72,
            topMargin=72,
            bottomMargin=72
        )

        story = []

        # Parse and format content
        lines = content.split('\n')

        for line in lines:
            line = line.rstrip()

            # Skip empty lines (but add spacing)
            if not line.strip():
                story.append(Spacer(1, 6))
                continue

            # Detect section headers (lines with === or ---)
            if line.strip().startswith('===') and line.strip().endswith('==='):
                # Main title
                title = line.strip('= ').strip()
                story.append(Paragraph(title, self.styles['CustomTitle']))
                continue
            elif line.strip().startswith('---') and line.strip().endswith('---'):
                # Section header
                section = line.strip('- ').strip()
                story.append(Paragraph(section, self.styles['SectionHeader']))
                continue
            elif line.startswith('===') or line.startswith('---'):
                # Separator line
                story.append(Spacer(1, 12))
                continue

            # Detect subsection headers (lines ending with :)
            if line.strip().endswith(':') and len(line.strip()) < 80:
                story.append(Paragraph(line, self.styles['SubsectionHeader']))
                continue

            # Regular content
            # Escape special characters for reportlab
            line_escaped = line.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')

            # Detect key-value pairs
            if ':' in line and len(line.split(':')[0]) < 50:
                # Format as key-value
                parts = line.split(':', 1)
                if len(parts) == 2:
                    key = parts[0].strip()
                    value = parts[1].strip()
                    formatted_line = f"<b>{key}:</b> {value}"
                    story.append(Paragraph(formatted_line, self.styles['Normal']))
                else:
                    story.append(Paragraph(line_escaped, self.styles['Normal']))
            else:
                # Regular text
                story.append(Paragraph(line_escaped, self.styles['CodeStyle']))

        # Build PDF
        doc.build(story, onFirstPage=self._create_header_footer, onLaterPages=self._create_header_footer)

        print(f"✓ Generated PDF report: {pdf_file}")
        return pdf_file

    def convert_csv_to_pdf(self, csv_file: str, pdf_file: str = None, include_charts: bool = True) -> str:
        """
        Convert a CSV monitoring log to PDF with tables and charts

        Args:
            csv_file: Path to input CSV file
            pdf_file: Path to output PDF file (optional)
            include_charts: Whether to include visualizations

        Returns:
            Path to generated PDF file
        """
        if not os.path.exists(csv_file):
            raise FileNotFoundError(f"CSV file not found: {csv_file}")

        # Generate output filename if not provided
        if pdf_file is None:
            base_name = os.path.splitext(os.path.basename(csv_file))[0]
            pdf_file = os.path.join(self.output_dir, f"{base_name}.pdf")

        # Read CSV data
        with open(csv_file, 'r', encoding='utf-8') as f:
            reader = csv.reader(f)
            data = list(reader)

        if len(data) == 0:
            raise ValueError(f"CSV file is empty: {csv_file}")

        # Create PDF document
        doc = SimpleDocTemplate(
            pdf_file,
            pagesize=letter,
            rightMargin=72,
            leftMargin=72,
            topMargin=72,
            bottomMargin=72
        )

        story = []

        # Title
        title = os.path.splitext(os.path.basename(csv_file))[0].replace('_', ' ').title()
        story.append(Paragraph(title, self.styles['CustomTitle']))
        story.append(Spacer(1, 12))

        # Summary information
        headers = data[0] if len(data) > 0 else []
        data_rows = data[1:] if len(data) > 1 else []

        summary_text = f"""
        <b>File:</b> {os.path.basename(csv_file)}<br/>
        <b>Columns:</b> {len(headers)}<br/>
        <b>Data Rows:</b> {len(data_rows)}<br/>
        <b>Generated:</b> {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
        """
        story.append(Paragraph(summary_text, self.styles['InfoBox']))
        story.append(Spacer(1, 12))

        # Create charts if requested
        if include_charts and len(data_rows) > 0:
            story.append(Paragraph("Visualizations", self.styles['SectionHeader']))

            chart_images = self._create_csv_charts(csv_file, headers, data_rows)
            for chart_img in chart_images:
                if chart_img:
                    story.append(Image(chart_img, width=6*inch, height=3*inch))
                    story.append(Spacer(1, 12))

            if chart_images:
                story.append(PageBreak())

        # Data table (first 100 rows to avoid huge PDFs)
        story.append(Paragraph("Data Table", self.styles['SectionHeader']))

        max_rows = 100
        table_data = [headers]

        if len(data_rows) > max_rows:
            table_data.extend(data_rows[:max_rows])
            story.append(Paragraph(
                f"<i>Showing first {max_rows} of {len(data_rows)} rows</i>",
                self.styles['Normal']
            ))
        else:
            table_data.extend(data_rows)

        # Create table
        table = Table(table_data, repeatRows=1)
        table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#2c5aa0')),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
            ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 10),
            ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
            ('BACKGROUND', (0, 1), (-1, -1), colors.beige),
            ('GRID', (0, 0), (-1, -1), 1, colors.black),
            ('FONTSIZE', (0, 1), (-1, -1), 8),
            ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.lightgrey])
        ]))

        story.append(table)

        # Build PDF
        doc.build(story, onFirstPage=self._create_header_footer, onLaterPages=self._create_header_footer)

        print(f"✓ Generated PDF from CSV: {pdf_file}")
        return pdf_file

    def _create_csv_charts(self, csv_file: str, headers: List[str], data_rows: List[List[str]]) -> List[Optional[str]]:
        """
        Create charts from CSV data

        Returns:
            List of image file paths
        """
        chart_images = []

        try:
            # Parse data into columns
            columns = {header: [] for header in headers}

            for row in data_rows:
                for i, value in enumerate(row):
                    if i < len(headers):
                        columns[headers[i]].append(value)

            # Determine which columns are numeric
            numeric_columns = []
            for header, values in columns.items():
                if header.lower() in ['timestamp', 'time', 'date']:
                    continue
                try:
                    # Try to convert to float
                    numeric_values = [float(v) for v in values if v.strip()]
                    if len(numeric_values) > 0:
                        numeric_columns.append(header)
                except (ValueError, AttributeError):
                    continue

            # Create a line chart for numeric columns
            if numeric_columns and len(data_rows) > 1:
                fig, axes = plt.subplots(len(numeric_columns), 1, figsize=(10, 3 * len(numeric_columns)))

                if len(numeric_columns) == 1:
                    axes = [axes]

                for idx, col_name in enumerate(numeric_columns):
                    ax = axes[idx]

                    # Get numeric values
                    values = []
                    for val in columns[col_name]:
                        try:
                            values.append(float(val))
                        except (ValueError, AttributeError):
                            values.append(None)

                    # Plot
                    x_range = range(len(values))
                    ax.plot(x_range, values, marker='o', markersize=2, linewidth=1)
                    ax.set_title(f"{col_name} Over Time", fontsize=12, fontweight='bold')
                    ax.set_xlabel("Sample Index", fontsize=10)
                    ax.set_ylabel(col_name, fontsize=10)
                    ax.grid(True, alpha=0.3)

                    # Add statistics
                    valid_values = [v for v in values if v is not None]
                    if valid_values:
                        avg_val = sum(valid_values) / len(valid_values)
                        min_val = min(valid_values)
                        max_val = max(valid_values)
                        ax.axhline(y=avg_val, color='r', linestyle='--', linewidth=1, alpha=0.7, label=f'Avg: {avg_val:.2f}')
                        ax.legend(fontsize=8)

                plt.tight_layout()

                # Save to file
                chart_file = os.path.join(
                    self.output_dir,
                    f"chart_{os.path.splitext(os.path.basename(csv_file))[0]}.png"
                )
                plt.savefig(chart_file, dpi=100, bbox_inches='tight')
                plt.close()

                chart_images.append(chart_file)

        except Exception as e:
            print(f"Warning: Could not generate charts for {csv_file}: {e}")

        return chart_images

    def create_combined_pdf(self, test_output_dir: str, combined_pdf_file: str = None) -> str:
        """
        Create a single combined PDF from all reports and logs in a test output directory

        Args:
            test_output_dir: Directory containing test reports and logs
            combined_pdf_file: Path to output combined PDF file (optional)

        Returns:
            Path to generated combined PDF file
        """
        if not os.path.exists(test_output_dir):
            raise FileNotFoundError(f"Test output directory not found: {test_output_dir}")

        # Generate output filename if not provided
        if combined_pdf_file is None:
            dir_name = os.path.basename(test_output_dir.rstrip('/'))
            combined_pdf_file = os.path.join(self.output_dir, f"{dir_name}_COMBINED.pdf")

        # Create PDF document
        doc = SimpleDocTemplate(
            combined_pdf_file,
            pagesize=letter,
            rightMargin=72,
            leftMargin=72,
            topMargin=72,
            bottomMargin=72
        )

        story = []

        # Cover page
        story.append(Paragraph("Jetson Orin Test Suite", self.styles['CustomTitle']))
        story.append(Spacer(1, 12))
        story.append(Paragraph("Complete Test Report", self.styles['SectionHeader']))
        story.append(Spacer(1, 24))

        cover_info = f"""
        <b>Test Output Directory:</b> {os.path.basename(test_output_dir)}<br/>
        <b>Generated:</b> {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}<br/>
        <b>Report Type:</b> Combined (All Tests)<br/>
        """
        story.append(Paragraph(cover_info, self.styles['InfoBox']))
        story.append(PageBreak())

        # Find all report and log files
        report_files = []
        csv_files = []

        for root, dirs, files in os.walk(test_output_dir):
            for file in files:
                file_path = os.path.join(root, file)
                if file.endswith('.txt') and 'REPORT' in file.upper():
                    report_files.append(file_path)
                elif file.endswith('.csv'):
                    csv_files.append(file_path)

        # Sort files
        report_files.sort()
        csv_files.sort()

        # Add text reports
        if report_files:
            story.append(Paragraph("Test Reports", self.styles['CustomTitle']))
            story.append(Spacer(1, 12))

            for report_file in report_files:
                story.append(Paragraph(
                    os.path.basename(report_file),
                    self.styles['SectionHeader']
                ))
                story.append(Spacer(1, 6))

                # Read and add report content
                try:
                    with open(report_file, 'r', encoding='utf-8', errors='ignore') as f:
                        content = f.read()

                    lines = content.split('\n')
                    for line in lines[:200]:  # Limit lines per report
                        line = line.rstrip()
                        if not line.strip():
                            story.append(Spacer(1, 4))
                            continue

                        line_escaped = line.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')

                        if line.startswith('===') or line.startswith('---'):
                            continue

                        story.append(Paragraph(line_escaped, self.styles['CodeStyle']))

                    if len(lines) > 200:
                        story.append(Paragraph(
                            f"<i>... {len(lines) - 200} more lines omitted ...</i>",
                            self.styles['Normal']
                        ))

                except Exception as e:
                    story.append(Paragraph(f"Error reading report: {e}", self.styles['Normal']))

                story.append(PageBreak())

        # Add CSV summaries and charts
        if csv_files:
            story.append(Paragraph("Monitoring Logs Summary", self.styles['CustomTitle']))
            story.append(Spacer(1, 12))

            for csv_file in csv_files:
                story.append(Paragraph(
                    os.path.basename(csv_file),
                    self.styles['SectionHeader']
                ))
                story.append(Spacer(1, 6))

                # Read CSV and create summary
                try:
                    with open(csv_file, 'r', encoding='utf-8') as f:
                        reader = csv.reader(f)
                        data = list(reader)

                    if len(data) > 1:
                        headers = data[0]
                        data_rows = data[1:]

                        summary = f"""
                        <b>Columns:</b> {', '.join(headers)}<br/>
                        <b>Total Rows:</b> {len(data_rows)}<br/>
                        """
                        story.append(Paragraph(summary, self.styles['InfoBox']))

                        # Create and add charts
                        chart_images = self._create_csv_charts(csv_file, headers, data_rows)
                        for chart_img in chart_images:
                            if chart_img and os.path.exists(chart_img):
                                story.append(Image(chart_img, width=6*inch, height=3*inch))
                                story.append(Spacer(1, 12))

                except Exception as e:
                    story.append(Paragraph(f"Error processing CSV: {e}", self.styles['Normal']))

                story.append(PageBreak())

        # Build PDF
        doc.build(story, onFirstPage=self._create_header_footer, onLaterPages=self._create_header_footer)

        print(f"✓ Generated combined PDF report: {combined_pdf_file}")
        return combined_pdf_file

    def batch_convert_directory(self, test_output_dir: str, create_combined: bool = True, test_type: str = None, output_base_dir: str = None) -> List[str]:
        """
        Convert all reports and CSVs in a directory to individual PDFs

        Args:
            test_output_dir: Directory containing test output files
            create_combined: Whether to also create a combined PDF
            test_type: Test type for organization (cpu, gpu, ram, storage, etc.)
            output_base_dir: Base directory for PDF output (default: test_output_dir/pdf_reports)

        Returns:
            List of generated PDF file paths
        """
        if not os.path.exists(test_output_dir):
            raise FileNotFoundError(f"Directory not found: {test_output_dir}")

        generated_pdfs = []

        # Create output directory for PDFs with optional test type subdirectory
        if output_base_dir:
            # Use custom output base directory
            if test_type:
                pdf_output_dir = os.path.join(output_base_dir, test_type)
            else:
                pdf_output_dir = output_base_dir
        else:
            # Use default structure
            if test_type:
                pdf_output_dir = os.path.join(test_output_dir, 'pdf_reports', test_type)
            else:
                pdf_output_dir = os.path.join(test_output_dir, 'pdf_reports')
        os.makedirs(pdf_output_dir, exist_ok=True)

        # Update output directory
        original_output_dir = self.output_dir
        self.output_dir = pdf_output_dir

        print(f"\n📄 Converting reports and logs to PDF...")
        print(f"   Input directory: {test_output_dir}")
        print(f"   PDF output directory: {pdf_output_dir}\n")

        # Find and convert TXT reports
        for root, dirs, files in os.walk(test_output_dir):
            # Skip the pdf_reports directory itself
            if 'pdf_reports' in root:
                continue

            for file in files:
                file_path = os.path.join(root, file)

                try:
                    if file.endswith('.txt') and any(keyword in file.upper() for keyword in ['REPORT', 'SUMMARY', 'RESULT']):
                        pdf_path = self.convert_txt_report_to_pdf(file_path)
                        generated_pdfs.append(pdf_path)

                    elif file.endswith('.csv'):
                        pdf_path = self.convert_csv_to_pdf(file_path, include_charts=True)
                        generated_pdfs.append(pdf_path)

                except Exception as e:
                    print(f"✗ Error converting {file}: {e}")

        # Create combined PDF
        if create_combined and generated_pdfs:
            try:
                combined_pdf = self.create_combined_pdf(test_output_dir)
                generated_pdfs.append(combined_pdf)
            except Exception as e:
                print(f"✗ Error creating combined PDF: {e}")

        # Restore original output directory
        self.output_dir = original_output_dir

        print(f"\n✓ Generated {len(generated_pdfs)} PDF files in: {pdf_output_dir}")

        return generated_pdfs


def main():
    """Main entry point for command-line usage"""
    parser = argparse.ArgumentParser(
        description='Convert Jetson Orin test reports and logs to PDF',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Convert a single TXT report to PDF
  %(prog)s --txt-report /path/to/CPU_PERFORMANCE_REPORT.txt

  # Convert a CSV log to PDF with charts
  %(prog)s --csv-log /path/to/temperature_power_log.csv

  # Convert all reports and logs in a directory
  %(prog)s --batch /path/to/test_output_20250106_120000

  # Create only a combined PDF from all files
  %(prog)s --combined /path/to/test_output_20250106_120000
        """
    )

    parser.add_argument(
        '--txt-report',
        metavar='FILE',
        help='Convert a single TXT report file to PDF'
    )

    parser.add_argument(
        '--csv-log',
        metavar='FILE',
        help='Convert a single CSV log file to PDF'
    )

    parser.add_argument(
        '--batch',
        metavar='DIR',
        help='Convert all reports and logs in a directory to individual PDFs'
    )

    parser.add_argument(
        '--combined',
        metavar='DIR',
        help='Create a single combined PDF from all reports and logs in a directory'
    )

    parser.add_argument(
        '-o', '--output',
        metavar='FILE',
        help='Output PDF file path (for single file conversions)'
    )

    parser.add_argument(
        '--no-charts',
        action='store_true',
        help='Disable chart generation for CSV files'
    )

    parser.add_argument(
        '--test-type',
        metavar='TYPE',
        help='Test type for organization (cpu, gpu, ram, storage, combined, etc.)'
    )

    parser.add_argument(
        '--output-base-dir',
        metavar='DIR',
        help='Base directory for PDF output (e.g., parent_dir/pdf_reports)'
    )

    args = parser.parse_args()

    # Check if at least one input option is provided
    if not any([args.txt_report, args.csv_log, args.batch, args.combined]):
        parser.print_help()
        sys.exit(1)

    # Create PDF generator
    generator = PDFReportGenerator()

    try:
        # Single TXT report conversion
        if args.txt_report:
            pdf_file = generator.convert_txt_report_to_pdf(args.txt_report, args.output)
            print(f"\n✓ Success! PDF generated: {pdf_file}\n")

        # Single CSV log conversion
        elif args.csv_log:
            include_charts = not args.no_charts
            pdf_file = generator.convert_csv_to_pdf(args.csv_log, args.output, include_charts)
            print(f"\n✓ Success! PDF generated: {pdf_file}\n")

        # Batch conversion
        elif args.batch:
            pdf_files = generator.batch_convert_directory(args.batch, create_combined=True, test_type=args.test_type, output_base_dir=args.output_base_dir)
            print(f"\n✓ Success! Generated {len(pdf_files)} PDF files\n")

        # Combined PDF only
        elif args.combined:
            pdf_file = generator.create_combined_pdf(args.combined, args.output)
            print(f"\n✓ Success! Combined PDF generated: {pdf_file}\n")

    except FileNotFoundError as e:
        print(f"\n✗ Error: {e}\n")
        sys.exit(1)
    except Exception as e:
        print(f"\n✗ Error: {e}\n")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
