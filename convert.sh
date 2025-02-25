#!/bin/bash

# Configuration
VERSION="1.0.1"
SOURCE_DIR="src"
OUTPUT_DIR="build"
TEMPLATE="template.html"
CSS_FILES=(
    "files/css/reset.css"
    "files/css/index.css"
)

# Add supported document formats
SUPPORTED_FORMATS=(
    "*.md"      # Markdown
    "*.markdown"
    "*.mdx"
    "*.org"     # Org mode
    "*.rst"     # reStructuredText
    "*.txt"     # Plain text
    "*.tex"     # LaTeX
    "*.wiki"    # MediaWiki markup
    "*.dokuwiki" # DokuWiki markup
    "*.textile"  # Textile
    "*.asciidoc" # AsciiDoc
)

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Add after VERSION declaration
PDF_OUTPUT=false


# Error handling function
error() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

# Warning function
warning() {
    echo -e "${YELLOW}Warning: $1${NC}" >&2
}

# Success function
success() {
    echo -e "${GREEN}$1${NC}"
}

# Info function
info() {
    [ "$VERBOSE" = true ] && echo -e "${BLUE}$1${NC}"
}

# Help function
show_help() {
    cat << EOF
$(basename "$0") v$VERSION
Convert documents to HTML or PDF using pandoc.

Usage: $(basename "$0") [OPTIONS]

Options:
    -h, --help              Show this help message
    -v, --version          Show version information
    -s, --source DIR        Source directory (default: $SOURCE_DIR)
    -o, --output DIR        Output directory (default: $OUTPUT_DIR)
    -t, --template FILE     Template file (default: $TEMPLATE)
    -l, --list-formats     List supported file formats
    --verbose              Enable verbose output
    --clean                Remove output directory before starting
    --pdf                  Generate PDF instead of HTML output

Examples:
    $(basename "$0")                    # Use default settings (HTML output)
    $(basename "$0") --pdf              # Generate PDF output
    $(basename "$0") -s content -o dist # Use custom directories
    $(basename "$0") --clean            # Clean build

Supported formats:
    ${SUPPORTED_FORMATS[@]/#/    }

For more information, visit: https://pandoc.org/MANUAL.html
EOF
}

# Version function
show_version() {
    echo "$(basename "$0") version $VERSION"
}

# List supported formats
list_formats() {
    echo "Supported input formats:"
    for format in "${SUPPORTED_FORMATS[@]}"; do
        echo "    $format"
    done
}

# Check if pandoc is installed before continuing
if ! command -v pandoc >/dev/null 2>&1; then
    error "Pandoc is required but not installed. Please install pandoc."
fi

# Function to create CSS arguments array
create_css_args() {
    local source_file="$1"
    local source_dir="$2"
    
    # Calculate relative path from the HTML file to the root
    local rel_path="${source_file#"$source_dir"/}"
    local dir_depth
    dir_depth=$(echo "$rel_path" | tr -cd '/' | wc -c)
    local path_prefix=""
    
    # Add "../" for each directory level
    for ((i=0; i<dir_depth; i++)); do
        path_prefix="../$path_prefix"
    done
    
    # Return array of CSS arguments
    local css_args=()
    for css in "${CSS_FILES[@]}"; do
        css_args+=("--css" "$path_prefix$css")
    done
    printf "%s\n" "${css_args[@]}"
}

# Function to process a single file
process_file() {
    local source_file="$1"
    local source_dir="$2"
    local target_dir="$3"
    local extension="${source_file##*.}"
    
    info "Processing: $source_file"
    
    # Get relative path from source directory
    local rel_path="${source_file#"$source_dir"/}"
    local dir_path
    dir_path=$(dirname "$rel_path")
    local filename
    filename=$(basename "$source_file")
    local output_filename
    output_filename="${filename%.*}.$([ "$PDF_OUTPUT" = true ] && echo "pdf" || echo "html")"
    
    # Create target directory if it doesn't exist
    mkdir -p "$target_dir/$dir_path"
    
    # Format-specific options
    local format_opts=""
    case "$extension" in
        "tex")
            format_opts="--mathjax"
            ;;
        "org")
            format_opts="--shift-heading-level-by=1"
            ;;
        "rst")
            format_opts="--section-divs"
            ;;
        *)
            format_opts="--toc"
            ;;
    esac

    if [ "$PDF_OUTPUT" = true ]; then
        # Generate PDF file
        if ! pandoc --toc -s \
            $format_opts \
            --pdf-engine=xelatex \
            -Vversion="v$(date +%s)" \
            -Vdate="$(date +%F)" \
            -Vyear="$(date +%Y)" \
            -i "$source_file" \
            -o "$target_dir/$dir_path/$output_filename"; then
            error "Failed to convert $source_file to PDF"
            return 1
        fi
    else
        # Generate HTML file
        if ! pandoc --toc -s \
            $format_opts \
            $(create_css_args "$source_file" "$source_dir") \
            -Vversion="v$(date +%s)" \
            -Vdate="$(date +%F)" \
            -Vyear="$(date +%Y)" \
            -i "$source_file" \
            -o "$target_dir/$dir_path/$output_filename" \
            --template="$TEMPLATE"; then
            error "Failed to convert $source_file to HTML"
            return 1
        fi
    fi
        
    success "Converted: $source_file -> $target_dir/$dir_path/$output_filename"
    return 0
}

# Parse command line arguments
VERBOSE=false
CLEAN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            show_version
            exit 0
            ;;
        -s|--source)
            SOURCE_DIR="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -t|--template)
            TEMPLATE="$2"
            shift 2
            ;;
        -l|--list-formats)
            list_formats
            exit 0
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --pdf)
            PDF_OUTPUT=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Add after parsing arguments
if [ "$PDF_OUTPUT" = true ]; then
    if ! command -v xelatex >/dev/null 2>&1; then
        error "PDF generation requires xelatex. Please install texlive-xelatex package."
    fi
fi

# Create find command pattern for supported formats
FIND_PATTERN=()
for format in "${SUPPORTED_FORMATS[@]}"; do
    FIND_PATTERN+=(-o -name "$format")
done
# Remove the first -o since we don't need it for the first pattern
FIND_PATTERN=("${FIND_PATTERN[@]:1}")

# Update error checks
if [ "$PDF_OUTPUT" = false ] && [ ! -f "$TEMPLATE" ]; then
    error "Template file $TEMPLATE not found!"
fi

if [ ! -d "$SOURCE_DIR" ]; then
    error "Source directory $SOURCE_DIR not found!"
fi

# Clean up old build if requested
if [ "$CLEAN" = true ]; then
    echo "Cleaning up old build directory..."
    rm -rf "$OUTPUT_DIR"
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Copy all files from source directory if it exists
[ "$VERBOSE" = true ] && info "Copying assets..."
if [ -d "$SOURCE_DIR/files" ]; then
    cp -r "$SOURCE_DIR/files" "$OUTPUT_DIR/"
    info "Copied files directory and its contents"
else
    warning "files directory not found in source"
fi

# Find and process all supported files
[ "$VERBOSE" = true ] && info "Processing files..."
if find "$SOURCE_DIR" -type f \( "${FIND_PATTERN[@]}" \) | while read -r file; do
    process_file "$file" "$SOURCE_DIR" "$OUTPUT_DIR" || exit 1
done; then
    # Remove any hidden files (except .htaccess)
    find "$OUTPUT_DIR/" -type f -name '.*' ! -name ".htaccess" -delete
    success "Conversion complete! Output in $OUTPUT_DIR/"
    exit 0
else
    error "Conversion failed!"
fi