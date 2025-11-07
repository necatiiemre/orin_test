#!/usr/bin/env python3
"""
PDF Report Generator for Nvidia Jetson AGX Orin / AGX Orin Industrial Test Software
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
    from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
                                    PageBreak, Image, PageTemplate, Frame, KeepInFrame, HRFlowable)
    from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT, TA_JUSTIFY
    from reportlab.pdfgen import canvas
    from reportlab.platypus.tableofcontents import TableOfContents
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

    def __init__(self, output_dir: str = None, logo_path: str = None, logo_position: str = 'header', logo_opacity: float = 1.0):
        """
        Initialize PDF report generator

        Args:
            output_dir: Directory where PDF files will be saved
            logo_path: Path to logo image file (PNG, JPG, etc.)
            logo_position: Logo position - 'header' (top left, default and recommended for visibility)
            logo_opacity: Logo opacity (0.0 to 1.0, default 1.0 for full visibility)
        """
        self.output_dir = output_dir or os.getcwd()
        self.logo_path = logo_path
        self.logo_position = logo_position
        self.logo_opacity = logo_opacity
        self.styles = getSampleStyleSheet()
        self._setup_custom_styles()

        # Counters for sections, figures, and tables
        self.section_counter = 0
        self.figure_counter = 0
        self.table_counter = 0
        self.current_section_title = "Nvidia Jetson AGX Orin / AGX Orin Industrial Test Software"
        self.total_pages = 0  # Will be calculated during build

    def _setup_custom_styles(self):
        """Setup custom paragraph styles with improved typography"""
        # Title style - Enhanced with better spacing
        self.styles.add(ParagraphStyle(
            name='CustomTitle',
            parent=self.styles['Heading1'],
            fontSize=22,
            textColor=colors.HexColor('#1a5490'),
            spaceAfter=30,
            spaceBefore=0,
            alignment=TA_CENTER,
            fontName='Helvetica-Bold',
            leading=26
        ))

        # Section header style - Professional and prominent
        self.styles.add(ParagraphStyle(
            name='SectionHeader',
            parent=self.styles['Heading2'],
            fontSize=16,
            textColor=colors.HexColor('#1a5490'),
            spaceAfter=16,
            spaceBefore=24,
            fontName='Helvetica-Bold',
            leading=20,
            keepWithNext=True
        ))

        # Subsection header style - Clear and structured
        self.styles.add(ParagraphStyle(
            name='SubsectionHeader',
            parent=self.styles['Heading3'],
            fontSize=13,
            textColor=colors.HexColor('#2c5aa0'),
            spaceAfter=12,
            spaceBefore=16,
            fontName='Helvetica-Bold',
            leading=16,
            keepWithNext=True
        ))

        # Improved body text style
        self.styles.add(ParagraphStyle(
            name='EnhancedBody',
            parent=self.styles['Normal'],
            fontSize=11,
            leading=15,
            spaceAfter=8,
            spaceBefore=0,
            alignment=TA_LEFT,
            fontName='Helvetica'
        ))

        # Monospace style for code/logs - Clean and readable
        self.styles.add(ParagraphStyle(
            name='CodeStyle',
            parent=self.styles['Code'],
            fontSize=10,
            fontName='Courier',
            leftIndent=12,
            spaceAfter=6,
            leading=14,
            textColor=colors.HexColor('#1a1a1a')
        ))

        # Info box style - Plain text without background or borders
        self.styles.add(ParagraphStyle(
            name='InfoBox',
            parent=self.styles['Normal'],
            fontSize=11,
            textColor=colors.HexColor('#1a1a1a'),
            leftIndent=0,
            rightIndent=0,
            spaceAfter=8,
            spaceBefore=8,
            leading=15,
            fontName='Helvetica'
        ))

        # Product info style - For product metadata sections
        self.styles.add(ParagraphStyle(
            name='ProductInfo',
            parent=self.styles['Normal'],
            fontSize=11,
            textColor=colors.HexColor('#1a1a1a'),
            leftIndent=0,
            rightIndent=0,
            spaceAfter=6,
            leading=14,
            fontName='Helvetica'
        ))

        # Caption style for figures and tables
        self.styles.add(ParagraphStyle(
            name='Caption',
            parent=self.styles['Normal'],
            fontSize=10,
            textColor=colors.HexColor('#555555'),
            alignment=TA_CENTER,
            spaceAfter=12,
            spaceBefore=6,
            leading=12,
            fontName='Helvetica-Oblique'
        ))

        # Key-Value style for structured data
        self.styles.add(ParagraphStyle(
            name='KeyValue',
            parent=self.styles['Normal'],
            fontSize=11,
            leading=16,
            spaceAfter=6,
            spaceBefore=2,
            leftIndent=12,
            fontName='Helvetica'
        ))

    def _create_header_footer(self, canvas_obj, doc):
        """Create professional header and footer for each page with logo in top left"""
        canvas_obj.saveState()

        # Get page dimensions
        page_width, page_height = letter

        # Header section - appears on all pages
        # Smaller logo for header (0.5 inch high to fit better)
        logo_height_in_header = 0.5 * inch
        logo_width_in_header = 0.5 * inch

        if self.logo_path and os.path.exists(self.logo_path):
            try:
                # Full opacity for header logo (always visible)
                canvas_obj.setFillAlpha(1.0)
                canvas_obj.setStrokeAlpha(1.0)

                # Position logo in top left corner of header
                logo_x = inch
                logo_y = page_height - 0.75 * inch

                # Draw the logo (maintains aspect ratio automatically)
                canvas_obj.drawImage(
                    self.logo_path,
                    logo_x, logo_y,
                    width=logo_width_in_header,
                    height=logo_height_in_header,
                    preserveAspectRatio=True,
                    mask='auto'
                )

            except Exception as e:
                # If logo fails to load, continue without it
                print(f"Warning: Could not load logo from {self.logo_path}: {e}")

        # Header line (below logo and text)
        canvas_obj.setStrokeColor(colors.HexColor('#2c5aa0'))
        canvas_obj.setLineWidth(1.5)
        canvas_obj.line(inch, page_height - 0.85 * inch, page_width - inch, page_height - 0.85 * inch)

        # Header text - position to the right of logo (or centered if no logo)
        canvas_obj.setFont('Helvetica-Bold', 10)
        canvas_obj.setFillColor(colors.HexColor('#2c5aa0'))

        # Calculate text position based on whether logo exists
        if self.logo_path and os.path.exists(self.logo_path):
            # Position text to the right of the logo (with more space)
            text_x = inch + logo_width_in_header + 0.15 * inch
            text_y = page_height - 0.63 * inch

            # Report title next to logo
            canvas_obj.setFont('Helvetica-Bold', 10)
            canvas_obj.drawString(text_x, text_y, "Nvidia Jetson AGX Orin / AGX Orin Industrial Test Software")

            # Section title below report title (only after first page)
            if doc.page > 1:
                canvas_obj.setFont('Helvetica', 8)
                canvas_obj.setFillColor(colors.HexColor('#555555'))
                canvas_obj.drawString(text_x, text_y - 0.13 * inch, self.current_section_title[:60])
        else:
            # No logo - center the text
            canvas_obj.setFont('Helvetica-Bold', 11)
            canvas_obj.drawCentredString(page_width / 2, page_height - 0.65 * inch, "Nvidia Jetson AGX Orin / AGX Orin Industrial Test Software")

            if doc.page > 1:
                canvas_obj.setFont('Helvetica', 9)
                canvas_obj.setFillColor(colors.HexColor('#555555'))
                canvas_obj.drawCentredString(page_width / 2, page_height - 0.8 * inch, self.current_section_title)

        # Page number in header (top right corner)
        canvas_obj.setFont('Helvetica', 9)
        canvas_obj.setFillColor(colors.HexColor('#2c5aa0'))
        if self.total_pages > 0:
            canvas_obj.drawRightString(page_width - inch, page_height - 0.63 * inch, f"{doc.page} / {self.total_pages}")
        else:
            canvas_obj.drawRightString(page_width - inch, page_height - 0.63 * inch, f"Page {doc.page}")

        # Footer separator line
        canvas_obj.setStrokeColor(colors.HexColor('#cccccc'))
        canvas_obj.setLineWidth(0.5)
        canvas_obj.line(inch, 0.65 * inch, page_width - inch, 0.65 * inch)

        # Footer text
        canvas_obj.setFont('Helvetica', 8)
        canvas_obj.setFillColor(colors.HexColor('#666666'))
        canvas_obj.drawString(
            inch, 0.5 * inch,
            f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S %Z')}"
        )
        canvas_obj.drawCentredString(
            page_width / 2, 0.5 * inch,
            "Nvidia Jetson AGX Orin / AGX Orin Industrial Test Software - Confidential"
        )

        # Turkish eyes only on bottom right
        canvas_obj.drawRightString(
            page_width - inch, 0.5 * inch,
            "Turkish eyes only"
        )

        canvas_obj.restoreState()

    def _build_with_page_numbers(self, doc, story):
        """Build PDF with two-pass approach to calculate total pages"""
        import copy

        # First pass - count pages without page numbers
        first_pass_buffer = io.BytesIO()
        first_pass_doc = SimpleDocTemplate(
            first_pass_buffer,
            pagesize=doc.pagesize,
            rightMargin=doc.rightMargin,
            leftMargin=doc.leftMargin,
            topMargin=doc.topMargin,
            bottomMargin=doc.bottomMargin
        )

        # Deep copy story for first pass
        story_copy = copy.deepcopy(story)

        # Build first pass to count pages
        first_pass_doc.build(story_copy, onFirstPage=lambda c, d: None, onLaterPages=lambda c, d: None)
        self.total_pages = first_pass_doc.page

        # Second pass - build with correct page numbers
        doc.build(story, onFirstPage=self._create_header_footer, onLaterPages=self._create_header_footer)

    def _create_product_info_section(self, product_data: Dict[str, str]) -> List:
        """
        Create a professional product information section

        Args:
            product_data: Dictionary with product information keys and values

        Returns:
            List of flowables for the product info section
        """
        elements = []

        # Section header
        elements.append(Paragraph("Product Information", self.styles['SectionHeader']))
        elements.append(Spacer(1, 12))

        # Create product info table
        table_data = []
        for key, value in product_data.items():
            # Format key-value pairs in a table
            formatted_key = f"<b>{key}:</b>"
            table_data.append([Paragraph(formatted_key, self.styles['ProductInfo']),
                             Paragraph(str(value), self.styles['ProductInfo'])])

        if table_data:
            # Create a clean, professional table for product info
            product_table = Table(table_data, colWidths=[2.5*inch, 4*inch])
            product_table.setStyle(TableStyle([
                ('TEXTCOLOR', (0, 0), (-1, -1), colors.HexColor('#1a1a1a')),
                ('ALIGN', (0, 0), (0, -1), 'RIGHT'),
                ('ALIGN', (1, 0), (1, -1), 'LEFT'),
                ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
                ('FONTNAME', (1, 0), (1, -1), 'Helvetica'),
                ('FONTSIZE', (0, 0), (-1, -1), 11),
                ('LEFTPADDING', (0, 0), (-1, -1), 8),
                ('RIGHTPADDING', (0, 0), (-1, -1), 8),
                ('TOPPADDING', (0, 0), (-1, -1), 6),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('LINEBELOW', (0, 0), (-1, -1), 0.5, colors.HexColor('#cccccc')),
            ]))
            elements.append(product_table)

        elements.append(Spacer(1, 24))

        return elements

    def _create_numbered_figure(self, image_path: str, caption: str = None, max_width: float = 7*inch, max_height: float = 5*inch) -> List:
        """
        Create a figure with automatic numbering and caption, with stable positioning

        Args:
            image_path: Path to image file
            caption: Optional caption text
            max_width: Maximum width for the image
            max_height: Maximum height for the image

        Returns:
            List of flowables for the figure
        """
        elements = []

        self.figure_counter += 1

        try:
            # Get image dimensions to preserve aspect ratio
            from PIL import Image as PILImage
            with PILImage.open(image_path) as img:
                img_width, img_height = img.size
                aspect_ratio = img_width / img_height

                # Calculate display size while preserving aspect ratio
                if img_width > img_height:
                    display_width = min(max_width, img_width / 100)  # Convert pixels to inches at 100 DPI
                    display_height = display_width / aspect_ratio
                    if display_height > max_height:
                        display_height = max_height
                        display_width = display_height * aspect_ratio
                else:
                    display_height = min(max_height, img_height / 100)
                    display_width = display_height * aspect_ratio
                    if display_width > max_width:
                        display_width = max_width
                        display_height = display_width / aspect_ratio

            # Use KeepInFrame to prevent graphics from shifting
            img = Image(image_path, width=display_width, height=display_height)
            img.hAlign = 'CENTER'

            # Wrap in KeepInFrame to ensure stable positioning
            elements.append(Spacer(1, 10))
            elements.append(img)

            # Add caption with figure number
            if caption:
                caption_text = f"Figure {self.figure_counter}: {caption}"
            else:
                caption_text = f"Figure {self.figure_counter}"

            elements.append(Paragraph(caption_text, self.styles['Caption']))
            elements.append(Spacer(1, 12))

        except Exception as e:
            print(f"Warning: Could not load image {image_path}: {e}")
            elements.append(Paragraph(f"[Image {self.figure_counter} could not be loaded]", self.styles['Normal']))

        return elements

    def _create_numbered_table(self, table_data: List[List], caption: str = None, col_widths: List = None) -> List:
        """
        Create a table with automatic numbering and caption

        Args:
            table_data: Table data as list of lists
            caption: Optional caption text
            col_widths: Optional column widths

        Returns:
            List of flowables for the table
        """
        elements = []

        self.table_counter += 1

        # Add caption with table number (before table)
        if caption:
            caption_text = f"Table {self.table_counter}: {caption}"
        else:
            caption_text = f"Table {self.table_counter}"

        elements.append(Spacer(1, 10))
        elements.append(Paragraph(caption_text, self.styles['Caption']))
        elements.append(Spacer(1, 6))

        # Create table with improved styling
        table = Table(table_data, colWidths=col_widths, repeatRows=1)
        table.setStyle(TableStyle([
            # Header row styling
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#2c5aa0')),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
            ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 11),
            ('TOPPADDING', (0, 0), (-1, 0), 12),
            ('BOTTOMPADDING', (0, 0), (-1, 0), 12),

            # Data rows styling
            ('BACKGROUND', (0, 1), (-1, -1), colors.white),
            ('TEXTCOLOR', (0, 1), (-1, -1), colors.black),
            ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
            ('FONTSIZE', (0, 1), (-1, -1), 10),
            ('TOPPADDING', (0, 1), (-1, -1), 8),
            ('BOTTOMPADDING', (0, 1), (-1, -1), 8),
            ('LEFTPADDING', (0, 0), (-1, -1), 10),
            ('RIGHTPADDING', (0, 0), (-1, -1), 10),

            # Grid and borders
            ('GRID', (0, 0), (-1, -1), 1, colors.HexColor('#cccccc')),
            ('LINEBELOW', (0, 0), (-1, 0), 2, colors.HexColor('#2c5aa0')),

            # Alternating row colors
            ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#f8f8f8')])
        ]))

        elements.append(table)
        elements.append(Spacer(1, 12))

        return elements

    def _extract_product_data(self, content: str) -> Dict[str, str]:
        """
        Extract product/device information from report content

        Args:
            content: Report text content

        Returns:
            Dictionary of product metadata
        """
        product_data = {}
        lines = content.split('\n')

        # Keywords to identify product information
        product_keywords = ['device', 'jetson', 'model', 'serial', 'tester', 'quality', 'test date',
                          'ip address', 'hostname', 'duration', 'status', 'passed', 'failed',
                          'physical cores', 'cpu cores', 'cores', 'architecture', 'kernel',
                          'ubuntu', 'os', 'ram', 'memory', 'storage', 'disk']

        device_name = None
        ip_address = None

        for line in lines:
            line = line.strip()
            if ':' in line and len(line.split(':')[0]) < 50:
                key, value = line.split(':', 1)
                key = key.strip()
                value = value.strip()

                # Check if this looks like product information
                if any(keyword in key.lower() for keyword in product_keywords):
                    # Store hostname/device name separately
                    if 'hostname' in key.lower() or ('device' in key.lower() and '.' not in value and len(value) < 30):
                        device_name = value
                    # Store IP address separately
                    elif 'ip' in key.lower() or ('device' in key.lower() and '.' in value):
                        ip_address = value

                    product_data[key] = value

        # Override Device field with hostname if available, otherwise use IP
        if device_name:
            product_data['Device'] = device_name
        elif ip_address and 'Device' in product_data and product_data['Device'] == ip_address:
            # If Device is just an IP, also check for hostname in data
            hostname = product_data.get('Hostname', product_data.get('hostname', None))
            if hostname:
                product_data['Device'] = hostname

        return product_data

    def _create_cover_page(self, title: str, product_data: Dict[str, str]) -> List:
        """
        Create a professional cover page with large logo, title, and key information

        Args:
            title: Report title
            product_data: Dictionary with product/test information

        Returns:
            List of flowables for the cover page
        """
        elements = []

        # Add appropriately-sized logo at top (if available)
        # For portrait logos (like 1330x1774), limit height to fit on page
        if self.logo_path and os.path.exists(self.logo_path):
            try:
                from PIL import Image as PILImage
                with PILImage.open(self.logo_path) as img:
                    img_width, img_height = img.size
                    aspect_ratio = img_width / img_height

                    # Determine logo size based on aspect ratio
                    # For portrait logos (height > width), limit by height
                    # For landscape logos (width > height), limit by width
                    if img_height > img_width:
                        # Portrait orientation - limit height to 1.8 inches
                        cover_logo_height = 1.8 * inch
                        cover_logo_width = cover_logo_height * aspect_ratio
                    else:
                        # Landscape orientation - limit width to 2.5 inches
                        cover_logo_width = 2.5 * inch
                        cover_logo_height = cover_logo_width / aspect_ratio

                    # Center the logo
                    logo_img = Image(self.logo_path, width=cover_logo_width, height=cover_logo_height)
                    logo_img.hAlign = 'CENTER'
                    elements.append(Spacer(1, 0.3 * inch))
                    elements.append(logo_img)
                    elements.append(Spacer(1, 0.3 * inch))
            except Exception as e:
                print(f"Warning: Could not load logo for cover page: {e}")
                elements.append(Spacer(1, 1.0 * inch))
        else:
            elements.append(Spacer(1, 1.0 * inch))

        # Report Title - Large and prominent
        elements.append(Paragraph(title, self.styles['CustomTitle']))
        elements.append(Spacer(1, 0.4 * inch))

        # Display pass/fail status prominently (if available)
        # Extract status first to display it before other info
        status_raw = product_data.get('Status', product_data.get('status', product_data.get('Test Status', product_data.get('test status', ''))))
        if status_raw:
            status_lower = status_raw.lower()
            # Determine if it's a pass or fail
            is_pass = 'pass' in status_lower and 'fail' not in status_lower
            is_fail = 'fail' in status_lower

            if is_pass or is_fail:
                status_color = '#00AA00' if is_pass else '#DD0000'  # Green for pass, red for fail
                status_text = f"""
                <para alignment="center" fontSize="24" textColor="{status_color}">
                <b>{'PASS' if is_pass else 'FAIL'}</b>
                </para>
                """
                elements.append(Paragraph(status_text, self.styles['Normal']))
                elements.append(Spacer(1, 0.3 * inch))

        # Extract key information for cover page
        # Use case-insensitive lookup for flexibility
        tester = product_data.get('Tester', product_data.get('tester', ''))
        quality_checker = product_data.get('Quality Checker', product_data.get('quality checker', ''))
        test_date = product_data.get('Test Date', product_data.get('test date', ''))
        device = product_data.get('Device', product_data.get('device', ''))
        model = product_data.get('Jetson Model', product_data.get('jetson model', ''))
        serial = product_data.get('Device Serial', product_data.get('device serial', ''))

        # Create information table for cover page - ONLY include fields with actual data
        cover_info_data = []

        # Only add fields that have actual values (not empty)
        if device and device.strip():
            cover_info_data.append(['Device:', device])
        if model and model.strip():
            cover_info_data.append(['Model:', model])
        if serial and serial.strip():
            cover_info_data.append(['Serial Number:', serial])
        if test_date and test_date.strip():
            cover_info_data.append(['Test Date:', test_date])
        if tester and tester.strip():
            cover_info_data.append(['Conducted By:', tester])
        if quality_checker and quality_checker.strip():
            cover_info_data.append(['Quality Control:', quality_checker])

        # Create professional table for cover page info
        if cover_info_data:
            # Create table with professional spacing and alignment
            cover_table = Table(cover_info_data, colWidths=[2.5*inch, 3.5*inch])
            cover_table.setStyle(TableStyle([
                ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
                ('FONTNAME', (1, 0), (1, -1), 'Helvetica'),
                ('FONTSIZE', (0, 0), (-1, -1), 12),
                ('TEXTCOLOR', (0, 0), (-1, -1), colors.HexColor('#1a1a1a')),
                ('ALIGN', (0, 0), (0, -1), 'RIGHT'),
                ('ALIGN', (1, 0), (1, -1), 'LEFT'),
                ('LEFTPADDING', (0, 0), (-1, -1), 12),
                ('RIGHTPADDING', (0, 0), (-1, -1), 12),
                ('TOPPADDING', (0, 0), (-1, -1), 8),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('LINEBELOW', (0, 0), (-1, -1), 0.5, colors.HexColor('#cccccc')),
                ('BOX', (0, 0), (-1, -1), 1, colors.HexColor('#cccccc')),
            ]))

            # Center the table
            cover_table.hAlign = 'CENTER'
            elements.append(cover_table)
            elements.append(Spacer(1, 0.8 * inch))
        else:
            # If no data available, add minimal spacing
            elements.append(Spacer(1, 0.5 * inch))

        # Footer information on cover page
        footer_text = f"""
        <para alignment="center" fontSize="10" textColor="#666666">
        <b>Nvidia Jetson AGX Orin / AGX Orin Industrial Test Software</b><br/>
        {datetime.now().strftime('%Y-%m-%d %H:%M:%S %Z')}<br/>
        <i>Confidential Document</i>
        </para>
        """
        elements.append(Paragraph(footer_text, self.styles['Normal']))

        # Page break after cover page
        elements.append(PageBreak())

        return elements

    def convert_txt_report_to_pdf(self, txt_file: str, pdf_file: str = None) -> str:
        """
        Convert a TXT report file to formatted PDF with improved structure

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

        # Extract product/device information
        product_data = self._extract_product_data(content)

        # Create PDF document with enhanced margins for header/footer
        doc = SimpleDocTemplate(
            pdf_file,
            pagesize=letter,
            rightMargin=72,
            leftMargin=72,
            topMargin=90,  # Increased for header
            bottomMargin=72
        )

        story = []

        # Reset counters
        self.section_counter = 0
        self.figure_counter = 0
        self.table_counter = 0

        # Parse and format content
        lines = content.split('\n')

        # Determine report title
        title_found = False
        title = None
        for line in lines:
            if line.strip().startswith('===') and line.strip().endswith('==='):
                title = line.strip('= ').strip()
                self.current_section_title = title
                title_found = True
                break

        if not title_found:
            # Use filename as title
            title = os.path.splitext(os.path.basename(txt_file))[0].replace('_', ' ').title()
            self.current_section_title = title

        # Create professional cover page with large logo, title, and key info
        story.extend(self._create_cover_page(title, product_data))

        # Add detailed product information section after cover page
        if product_data:
            story.extend(self._create_product_info_section(product_data))

        # Process remaining content with improved formatting
        for line in lines:
            line = line.rstrip()

            # Skip title line (already processed)
            if line.strip().startswith('===') and line.strip().endswith('==='):
                continue

            # Skip empty lines (but add spacing)
            if not line.strip():
                story.append(Spacer(1, 6))
                continue

            # Detect section headers (lines with ---)
            if line.strip().startswith('---') and line.strip().endswith('---'):
                self.section_counter += 1
                section = line.strip('- ').strip()
                section_title = f"{self.section_counter}. {section}"
                story.append(Spacer(1, 10))
                story.append(Paragraph(section_title, self.styles['SectionHeader']))
                self.current_section_title = section
                continue
            elif line.startswith('===') or line.startswith('---'):
                # Separator line
                story.append(Spacer(1, 8))
                continue

            # Detect subsection headers (lines ending with :)
            if line.strip().endswith(':') and len(line.strip()) < 80 and not line.strip().startswith(' '):
                story.append(Paragraph(line, self.styles['SubsectionHeader']))
                continue

            # Regular content
            # Escape special characters for reportlab
            line_escaped = line.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')

            # Detect key-value pairs (but skip if in product data already)
            if ':' in line and len(line.split(':')[0]) < 50:
                parts = line.split(':', 1)
                if len(parts) == 2:
                    key = parts[0].strip()
                    value = parts[1].strip()

                    # Skip if this was already in product info
                    if key not in product_data:
                        formatted_line = f"<b>{key}:</b> {value}"
                        story.append(Paragraph(formatted_line, self.styles['KeyValue']))
                    continue

            # Regular text/code
            if line.strip():
                story.append(Paragraph(line_escaped, self.styles['CodeStyle']))

        # Build PDF with page numbers
        self._build_with_page_numbers(doc, story)

        print(f"✓ Generated PDF report: {pdf_file}")
        return pdf_file

    def convert_csv_to_pdf(self, csv_file: str, pdf_file: str = None, include_charts: bool = True) -> str:
        """
        Convert a CSV monitoring log to PDF with tables and charts using improved formatting

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

        # Create PDF document with enhanced margins
        doc = SimpleDocTemplate(
            pdf_file,
            pagesize=letter,
            rightMargin=72,
            leftMargin=72,
            topMargin=90,  # Increased for header
            bottomMargin=72
        )

        story = []

        # Reset counters
        self.section_counter = 0
        self.figure_counter = 0
        self.table_counter = 0

        # Title and metadata for cover page
        title = os.path.splitext(os.path.basename(csv_file))[0].replace('_', ' ').title()
        self.current_section_title = title

        # Create simple metadata for cover page
        headers = data[0] if len(data) > 0 else []
        data_rows = data[1:] if len(data) > 1 else []

        csv_metadata = {
            'Test Date': datetime.now().strftime('%Y-%m-%d'),
            'Data File': os.path.basename(csv_file),
            'Total Rows': str(len(data_rows)),
            'Columns': str(len(headers))
        }

        # Create cover page for CSV report
        story.extend(self._create_cover_page(title, csv_metadata))

        # Summary information section
        summary_text = f"""
        <b>File:</b> {os.path.basename(csv_file)}<br/>
        <b>Columns:</b> {len(headers)}<br/>
        <b>Data Rows:</b> {len(data_rows)}<br/>
        {datetime.now().strftime('%Y-%m-%d %H:%M:%S %Z')}
        """
        story.append(Paragraph(summary_text, self.styles['InfoBox']))
        story.append(Spacer(1, 20))

        # Create charts if requested
        if include_charts and len(data_rows) > 0:
            self.section_counter += 1
            story.append(Paragraph(f"{self.section_counter}. Visualizations", self.styles['SectionHeader']))
            self.current_section_title = "Visualizations"

            chart_images = self._create_csv_charts(csv_file, headers, data_rows)
            for chart_img in chart_images:
                if chart_img:
                    # Use numbered figure with caption
                    chart_name = os.path.basename(csv_file).replace('_', ' ').replace('.csv', '')
                    story.extend(self._create_numbered_figure(chart_img, f"Monitoring data from {chart_name}"))

            if chart_images:
                story.append(PageBreak())

        # Data table (first 100 rows to avoid huge PDFs)
        self.section_counter += 1
        story.append(Paragraph(f"{self.section_counter}. Data Table", self.styles['SectionHeader']))
        self.current_section_title = "Data Table"
        story.append(Spacer(1, 12))

        max_rows = 100
        table_data = [headers]

        if len(data_rows) > max_rows:
            table_data.extend(data_rows[:max_rows])
            story.append(Paragraph(
                f"<i>Showing first {max_rows} of {len(data_rows)} rows</i>",
                self.styles['EnhancedBody']
            ))
            story.append(Spacer(1, 8))

        else:
            table_data.extend(data_rows)

        # Create numbered table with caption
        story.extend(self._create_numbered_table(table_data, f"Monitoring data ({len(data_rows)} rows)"))

        # Build PDF with page numbers
        self._build_with_page_numbers(doc, story)

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
                # Adjust figure size based on number of charts
                chart_height = min(4, 2.5 + len(numeric_columns) * 0.5)  # Max 4 inches per chart
                fig, axes = plt.subplots(len(numeric_columns), 1, figsize=(8, chart_height * len(numeric_columns)))

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
                    ax.plot(x_range, values, marker='o', markersize=1.5, linewidth=1.5)
                    ax.set_title(f"{col_name} Over Time", fontsize=11, fontweight='bold')
                    ax.set_xlabel("Sample Index", fontsize=9)
                    ax.set_ylabel(col_name, fontsize=9)
                    ax.grid(True, alpha=0.3, linewidth=0.5)

                    # Add statistics
                    valid_values = [v for v in values if v is not None]
                    if valid_values:
                        avg_val = sum(valid_values) / len(valid_values)
                        min_val = min(valid_values)
                        max_val = max(valid_values)
                        ax.axhline(y=avg_val, color='r', linestyle='--', linewidth=1, alpha=0.7, label=f'Avg: {avg_val:.2f}')
                        ax.legend(fontsize=7, loc='best')

                plt.tight_layout(pad=1.5)

                # Save to file with higher DPI
                chart_file = os.path.join(
                    self.output_dir,
                    f"chart_{os.path.splitext(os.path.basename(csv_file))[0]}.png"
                )
                plt.savefig(chart_file, dpi=150, bbox_inches='tight')
                plt.close()

                chart_images.append(chart_file)

        except Exception as e:
            print(f"Warning: Could not generate charts for {csv_file}: {e}")

        return chart_images

    def create_combined_pdf(self, test_output_dir: str, combined_pdf_file: str = None) -> str:
        """
        Create a single combined PDF from all reports and logs with improved structure

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

        # Create PDF document with enhanced margins
        doc = SimpleDocTemplate(
            combined_pdf_file,
            pagesize=letter,
            rightMargin=72,
            leftMargin=72,
            topMargin=90,  # Increased for header
            bottomMargin=72
        )

        story = []

        # Reset counters
        self.section_counter = 0
        self.figure_counter = 0
        self.table_counter = 0

        # Prepare metadata for combined report cover page
        combined_metadata = {
            'Test Output Directory': os.path.basename(test_output_dir),
            'Test Date': datetime.now().strftime('%Y-%m-%d'),
            'Report Type': 'Combined (All Tests)',
            'Document Type': 'High-Quality Professional Report'
        }

        # Create professional cover page
        self.current_section_title = "Nvidia Jetson AGX Orin / AGX Orin Industrial Test Software - Complete Test Report"
        story.extend(self._create_cover_page("Nvidia Jetson AGX Orin / AGX Orin Industrial Test Software\nComplete Test Report", combined_metadata))

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

        # Add text reports with improved structure
        if report_files:
            self.section_counter += 1
            story.append(Paragraph(f"{self.section_counter}. Test Reports", self.styles['CustomTitle']))
            self.current_section_title = "Test Reports"
            story.append(Spacer(1, 20))

            for idx, report_file in enumerate(report_files, 1):
                # Add subsection for each report
                report_name = os.path.basename(report_file).replace('_', ' ').replace('.txt', '')
                story.append(Paragraph(
                    f"{self.section_counter}.{idx} {report_name}",
                    self.styles['SectionHeader']
                ))
                story.append(Spacer(1, 10))

                # Read and add report content
                try:
                    with open(report_file, 'r', encoding='utf-8', errors='ignore') as f:
                        content = f.read()

                    # Extract and display product info for this report
                    product_data = self._extract_product_data(content)
                    if product_data:
                        story.extend(self._create_product_info_section(product_data))

                    lines = content.split('\n')
                    line_count = 0
                    for line in lines:
                        if line_count >= 200:  # Limit lines per report
                            break

                        line = line.rstrip()
                        if not line.strip():
                            story.append(Spacer(1, 4))
                            continue

                        # Skip lines already in product info
                        if ':' in line and len(line.split(':')[0]) < 50:
                            key = line.split(':', 1)[0].strip()
                            if key in product_data:
                                continue

                        line_escaped = line.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')

                        if line.startswith('===') or line.startswith('---'):
                            continue

                        story.append(Paragraph(line_escaped, self.styles['CodeStyle']))
                        line_count += 1

                    if len(lines) > 200:
                        story.append(Spacer(1, 8))
                        story.append(Paragraph(
                            f"<i>... {len(lines) - 200} more lines omitted ...</i>",
                            self.styles['EnhancedBody']
                        ))

                except Exception as e:
                    story.append(Paragraph(f"Error reading report: {e}", self.styles['EnhancedBody']))

                story.append(PageBreak())

        # Add CSV summaries and charts with improved structure
        if csv_files:
            self.section_counter += 1
            story.append(Paragraph(f"{self.section_counter}. Monitoring Logs Summary", self.styles['CustomTitle']))
            self.current_section_title = "Monitoring Logs"
            story.append(Spacer(1, 20))

            for idx, csv_file in enumerate(csv_files, 1):
                csv_name = os.path.basename(csv_file).replace('_', ' ').replace('.csv', '')
                story.append(Paragraph(
                    f"{self.section_counter}.{idx} {csv_name}",
                    self.styles['SectionHeader']
                ))
                story.append(Spacer(1, 10))

                # Read CSV and create summary
                try:
                    with open(csv_file, 'r', encoding='utf-8') as f:
                        reader = csv.reader(f)
                        data = list(reader)

                    if len(data) > 1:
                        headers = data[0]
                        data_rows = data[1:]

                        summary = f"""
                        <b>File:</b> {os.path.basename(csv_file)}<br/>
                        <b>Columns:</b> {', '.join(headers[:5])}{'...' if len(headers) > 5 else ''}<br/>
                        <b>Total Rows:</b> {len(data_rows)}<br/>
                        """
                        story.append(Paragraph(summary, self.styles['InfoBox']))
                        story.append(Spacer(1, 12))

                        # Create and add charts with numbering
                        chart_images = self._create_csv_charts(csv_file, headers, data_rows)
                        for chart_img in chart_images:
                            if chart_img and os.path.exists(chart_img):
                                story.extend(self._create_numbered_figure(chart_img, f"Monitoring data from {csv_name}"))

                except Exception as e:
                    story.append(Paragraph(f"Error processing CSV: {e}", self.styles['EnhancedBody']))

                story.append(PageBreak())

        # Build PDF with page numbers
        self._build_with_page_numbers(doc, story)

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

    parser.add_argument(
        '--logo',
        metavar='FILE',
        help='Path to logo image file (PNG, JPG, etc.) to display in header'
    )

    parser.add_argument(
        '--logo-position',
        metavar='POSITION',
        choices=['header', 'watermark', 'top-right', 'top-left', 'bottom-right', 'bottom-left'],
        default='header',
        help='Logo position: header (top left, recommended), watermark (centered transparent), or corner positions (default: header)'
    )

    parser.add_argument(
        '--logo-opacity',
        metavar='OPACITY',
        type=float,
        default=1.0,
        help='Logo opacity from 0.0 (invisible) to 1.0 (fully opaque). Default: 1.0 (fully visible in header)'
    )

    args = parser.parse_args()

    # Check if at least one input option is provided
    if not any([args.txt_report, args.csv_log, args.batch, args.combined]):
        parser.print_help()
        sys.exit(1)

    # Create PDF generator with logo parameters
    generator = PDFReportGenerator(
        logo_path=args.logo,
        logo_position=args.logo_position,
        logo_opacity=args.logo_opacity
    )

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
