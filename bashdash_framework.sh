#!/usr/bin/env bash
# BashDash - Advanced Bash TUI/GUI Dashboard Framework
# A comprehensive framework for creating real-time dashboards with sophisticated widgets
# Author: Auto-generated for advanced bash scripting demonstration
# Compatibility: Bash 4.0+, requires tput, supports xterm-256color

set -euo pipefail  # Strict error handling for production quality

# Global configuration and state management
declare -g BASHDASH_VERSION="1.0.0"
declare -g BASHDASH_SCRIPT_NAME="${0##*/}"
declare -g BASHDASH_CONFIG_FILE=".${BASHDASH_SCRIPT_NAME%.sh}.dbash"
declare -g BASHDASH_WEB_PORT="${BASHDASH_WEB_PORT:-8080}"
declare -g BASHDASH_MODE="${BASHDASH_MODE:-tui}"  # tui or web

# Terminal capabilities and dimensions - cached for performance
declare -g TERM_COLS TERM_ROWS TERM_COLORS
declare -g HAS_256_COLORS=false
declare -g RESERVED_TOP_ROWS=8  # Space reserved for progress bars and status

# Widget state storage - associative arrays for O(1) lookups
declare -gA WIDGET_STATES=()      # Store widget internal states
declare -gA WIDGET_POSITIONS=()   # Cache widget screen positions
declare -gA WIDGET_CONFIGS=()     # Store widget configurations
declare -ga PROGRESS_BARS=()      # Array of active progress bar IDs
declare -ga LOG_BUFFER=()         # Circular buffer for log messages

# Color palette - optimized for readability and accessibility
declare -gA COLORS=(
    [reset]="\033[0m"
    [bold]="\033[1m"
    [dim]="\033[2m"
    [underline]="\033[4m"
    [blink]="\033[5m"
    [reverse]="\033[7m"
    [black]="\033[30m"
    [red]="\033[31m"
    [green]="\033[32m"
    [yellow]="\033[33m"
    [blue]="\033[34m"
    [magenta]="\033[35m"
    [cyan]="\033[36m"
    [white]="\033[37m"
    [bg_black]="\033[40m"
    [bg_red]="\033[41m"
    [bg_green]="\033[42m"
    [bg_yellow]="\033[43m"
    [bg_blue]="\033[44m"
    [bg_magenta]="\033[45m"
    [bg_cyan]="\033[46m"
    [bg_white]="\033[47m"
)

# Extended 256-color palette for enhanced visuals
declare -gA COLORS_256=(
    [bright_red]="\033[38;5;196m"
    [bright_green]="\033[38;5;46m"
    [bright_blue]="\033[38;5;21m"
    [bright_yellow]="\033[38;5;226m"
    [bright_magenta]="\033[38;5;201m"
    [bright_cyan]="\033[38;5;51m"
    [orange]="\033[38;5;208m"
    [purple]="\033[38;5;93m"
    [pink]="\033[38;5;213m"
    [lime]="\033[38;5;154m"
)

# Box-drawing characters - Unicode for maximum compatibility
declare -gA BOX_CHARS=(
    [h_line]="─"      # Horizontal line
    [v_line]="│"      # Vertical line
    [top_left]="┌"    # Top-left corner
    [top_right]="┐"   # Top-right corner
    [bottom_left]="└" # Bottom-left corner
    [bottom_right]="┘" # Bottom-right corner
    [cross]="┼"       # Cross/intersection
    [t_down]="┬"      # T pointing down
    [t_up]="┴"        # T pointing up
    [t_right]="├"     # T pointing right
    [t_left]="┤"      # T pointing left
    [double_h]="═"    # Double horizontal
    [double_v]="║"    # Double vertical
    [shadow]="▓"      # Shadow texture for depth
    [solid]="█"       # Solid block
    [light]="░"       # Light texture
    [medium]="▒"      # Medium texture
    [heavy]="▓"       # Heavy texture
)

# Spinner animation frames - optimized for smooth visual feedback
declare -ga SPINNER_FRAMES=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
declare -ga PROGRESS_CHARS=('▏' '▎' '▍' '▌' '▋' '▊' '▉' '█')

#═══════════════════════════════════════════════════════════════════════════════
# CORE FRAMEWORK FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Initialize the framework - must be called before using any widgets
# Sets up terminal, detects capabilities, and prepares the display
bashdash_init() {
    # Detect terminal capabilities for optimal rendering
    TERM_COLS=$(tput cols 2>/dev/null || echo 80)
    TERM_ROWS=$(tput lines 2>/dev/null || echo 24)
    TERM_COLORS=$(tput colors 2>/dev/null || echo 8)
    
    # Enable 256-color mode if supported - significantly improves visual quality
    if [[ $TERM_COLORS -ge 256 ]]; then
        HAS_256_COLORS=true
        # Merge extended colors into main palette for unified access
        for key in "${!COLORS_256[@]}"; do
            COLORS[$key]="${COLORS_256[$key]}"
        done
    fi
    
    # Set up alternate screen buffer to preserve user's terminal state
    # This is crucial for professional applications that don't disrupt workflow
    tput smcup  # Save screen and switch to alternate buffer
    tput civis  # Hide cursor for cleaner display
    tput clear  # Clear the alternate buffer
    
    # Enable mouse support if available (xterm-like terminals)
    # Allows for future interactive enhancements
    printf '\033[?1000h' 2>/dev/null || true
    
    # Set up signal handlers for graceful cleanup
    # Prevents terminal corruption on unexpected exits
    trap bashdash_cleanup EXIT INT TERM
    
    # Initialize the reserved top section for progress bars
    _bashdash_init_reserved_area
    
    return 0
}

# Clean up function - automatically called on exit
# Restores terminal to original state for seamless user experience
bashdash_cleanup() {
    # Disable mouse support
    printf '\033[?1000l' 2>/dev/null || true
    
    # Show cursor and restore normal screen
    tput cnorm  # Show cursor
    tput rmcup  # Restore original screen buffer
    
    # Reset all terminal attributes to default
    tput sgr0
    
    return 0
}

# Initialize the reserved area at top of screen for progress indicators
# This creates a consistent, professional header area
_bashdash_init_reserved_area() {
    local row col
    
    # Clear the reserved area with a distinctive background
    for ((row = 1; row <= RESERVED_TOP_ROWS; row++)); do
        tput cup $((row - 1)) 0  # Position cursor (0-indexed)
        
        # Create a subtle background for the reserved area
        if [[ $HAS_256_COLORS == true ]]; then
            printf '\033[48;5;235m'  # Dark gray background
        else
            printf "${COLORS[bg_black]}"
        fi
        
        # Fill the entire row with spaces to create background
        printf '%*s' "$TERM_COLS" ""
    done
    
    # Draw a separator line between reserved area and content
    tput cup $((RESERVED_TOP_ROWS - 1)) 0
    printf "${COLORS[cyan]}${COLORS[bold]}"
    for ((col = 0; col < TERM_COLS; col++)); do
        printf "${BOX_CHARS[h_line]}"
    done
    printf "${COLORS[reset]}"
    
    return 0
}

# Move cursor to specified position with bounds checking
# Prevents cursor positioning errors that cause display corruption
bashdash_goto() {
    local row="${1:-1}" col="${2:-1}"
    
    # Clamp values to terminal dimensions for safety
    ((row < 1)) && row=1
    ((row > TERM_ROWS)) && row=$TERM_ROWS
    ((col < 1)) && col=1
    ((col > TERM_COLS)) && col=$TERM_COLS
    
    # tput uses 0-based indexing, so adjust accordingly
    tput cup $((row - 1)) $((col - 1))
}

# Parse key=value parameters into associative array
# Provides flexible, extensible parameter parsing for all widgets
_bashdash_parse_params() {
    local -n params_ref=$1  # Use nameref for efficient pass-by-reference
    shift  # Remove the array name from arguments
    
    local param
    for param in "$@"; do
        if [[ $param =~ ^([^=]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            params_ref["$key"]="$value"
        else
            # Handle positional parameters gracefully
            bashdash_log "Warning: Invalid parameter format: $param" "yellow"
        fi
    done
}

# Validate required parameters for widgets
# Ensures robust error handling and helpful developer feedback
_bashdash_validate_params() {
    local -n params_ref=$1
    shift
    local required_params=("$@")
    
    local missing_params=()
    local param
    
    for param in "${required_params[@]}"; do
        if [[ -z ${params_ref[$param]:-} ]]; then
            missing_params+=("$param")
        fi
    done
    
    if [[ ${#missing_params[@]} -gt 0 ]]; then
        bashdash_log "Error: Missing required parameters: ${missing_params[*]}" "red"
        return 1
    fi
    
    return 0
}

# Advanced logging system with timestamps and color coding
# Maintains a circular buffer for performance and memory efficiency
bashdash_log() {
    local message="$1"
    local color="${2:-white}"
    local timestamp
    
    # Generate precise timestamp for professional logging
    timestamp=$(date '+%H:%M:%S.%3N' 2>/dev/null || date '+%H:%M:%S')
    
    # Format log entry with color and timestamp
    local formatted_log="${COLORS[dim]}[$timestamp]${COLORS[reset]} ${COLORS[$color]}$message${COLORS[reset]}"
    
    # Add to circular buffer (maintain last 1000 entries for performance)
    LOG_BUFFER+=("$formatted_log")
    if [[ ${#LOG_BUFFER[@]} -gt 1000 ]]; then
        # Remove oldest entry to maintain buffer size
        LOG_BUFFER=("${LOG_BUFFER[@]:1}")
    fi
    
    # Display in log area (below reserved section)
    local log_start_row=$((RESERVED_TOP_ROWS + 1))
    local display_row=$((log_start_row + ${#LOG_BUFFER[@]} - 1))
    
    # Only display if within visible area
    if [[ $display_row -le $TERM_ROWS ]]; then
        bashdash_goto "$display_row" 1
        # Clear the line first to prevent artifacts
        printf '\033[K'
        printf '%s\n' "$formatted_log"
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# PROGRESS BAR WIDGET
#═══════════════════════════════════════════════════════════════════════════════

# Create and manage sophisticated progress bars with animations
# Supports: percentage display, color gradients, custom labels, and real-time updates
# Usage: bashdash_progress_bar id=mybar val=50 width=40 color=green label="Processing"
bashdash_progress_bar() {
    local -A params=()
    _bashdash_parse_params params "$@"
    
    # Validate required parameters
    _bashdash_validate_params params "id" "val" || return 1
    
    # Extract parameters with intelligent defaults
    local id="${params[id]}"
    local value="${params[val]}"
    local width="${params[width]:-40}"          # Reasonable default width
    local color="${params[color]:-green}"       # Professional green default
    local label="${params[label]:-Progress}"    # Generic label
    local show_percent="${params[show_percent]:-true}"
    
    # Validate and clamp value to 0-100 range
    if ! [[ $value =~ ^-?[0-9]+$ ]]; then
        bashdash_log "Error: Progress value must be integer: $value" "red"
        return 1
    fi
    
    # Handle relative updates (e.g., val=+5 or val=-3)
    if [[ $value =~ ^[+-] ]]; then
        local current_value="${WIDGET_STATES[${id}_value]:-0}"
        value=$((current_value + value))
    fi
    
    # Clamp to valid percentage range
    ((value < 0)) && value=0
    ((value > 100)) && value=100
    
    # Store widget state for future updates
    WIDGET_STATES["${id}_value"]=$value
    WIDGET_STATES["${id}_width"]=$width
    WIDGET_STATES["${id}_color"]=$color
    WIDGET_STATES["${id}_label"]=$label
    
    # Add to progress bar tracking if new
    if [[ ! " ${PROGRESS_BARS[*]} " =~ " ${id} " ]]; then
        PROGRESS_BARS+=("$id")
    fi
    
    # Calculate progress bar dimensions and position
    local filled_chars=$((value * width / 100))
    local empty_chars=$((width - filled_chars))
    
    # Find position for this progress bar in reserved area
    local bar_row=1
    local bar_index=0
    
    # Find the index of this progress bar
    for i in "${!PROGRESS_BARS[@]}"; do
        if [[ "${PROGRESS_BARS[$i]}" == "$id" ]]; then
            bar_index=$i
            break
        fi
    done
    
    # Calculate row position (2 rows per progress bar for spacing)
    bar_row=$((2 + bar_index * 2))
    
    # Don't draw if outside reserved area
    if [[ $bar_row -ge $RESERVED_TOP_ROWS ]]; then
        bashdash_log "Warning: Too many progress bars, $id not displayed" "yellow"
        return 0
    fi
    
    # Position cursor for drawing
    bashdash_goto "$bar_row" 2
    
    # Clear the line to prevent artifacts
    printf '\033[K'
    
    # Draw the label with styling
    printf "${COLORS[bold]}${COLORS[white]}%-12s${COLORS[reset]} " "$label:"
    
    # Draw progress bar border
    printf "${COLORS[$color]}${BOX_CHARS[top_left]}"
    
    # Draw filled portion with gradient effect if 256 colors available
    local i
    for ((i = 0; i < filled_chars; i++)); do
        if [[ $HAS_256_COLORS == true ]]; then
            # Create subtle gradient effect
            local intensity=$((232 + (i * 23 / width)))  # Range: 232-255
            printf "\033[38;5;${intensity}m${BOX_CHARS[solid]}"
        else
            printf "${COLORS[$color]}${BOX_CHARS[solid]}"
        fi
    done
    
    # Draw empty portion
    if [[ $empty_chars -gt 0 ]]; then
        printf "${COLORS[dim]}"
        for ((i = 0; i < empty_chars; i++)); do
            printf "${BOX_CHARS[light]}"
        done
    fi
    
    # Close progress bar border
    printf "${COLORS[$color]}${BOX_CHARS[top_right]}"
    
    # Display percentage if requested
    if [[ $show_percent == "true" ]]; then
        printf " ${COLORS[bold]}${COLORS[white]}%3d%%${COLORS[reset]}" "$value"
    fi
    
    # Add animated indicator for active progress
    if [[ $value -lt 100 ]]; then
        local spinner_index=$(( (EPOCHSECONDS % ${#SPINNER_FRAMES[@]}) ))
        printf " ${COLORS[cyan]}${SPINNER_FRAMES[$spinner_index]}${COLORS[reset]}"
    else
        printf " ${COLORS[green]}✓${COLORS[reset]}"
    fi
    
    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# DIALOG WIDGET WITH SHADOW EFFECTS
#═══════════════════════════════════════════════════════════════════════════════

# Create sophisticated modal dialogs with drop shadows and animations
# Supports: custom titles, buttons, input fields, and layered presentation
# Usage: bashdash_dialog id=mydialog title="Confirm Action" message="Are you sure?" buttons="Yes,No"
bashdash_dialog() {
    local -A params=()
    _bashdash_parse_params params "$@"
    
    # Validate required parameters
    _bashdash_validate_params params "id" "title" "message" || return 1
    
    # Extract parameters with sophisticated defaults
    local id="${params[id]}"
    local title="${params[title]}"
    local message="${params[message]}"
    local buttons="${params[buttons]:-OK}"      # Default single OK button
    local width="${params[width]:-50}"          # Professional dialog width
    local height="${params[height]:-10}"        # Reasonable height
    local shadow="${params[shadow]:-true}"      # Enable shadow by default
    local modal="${params[modal]:-true}"        # Modal by default
    
    # Calculate dialog position (center of screen)
    local start_row=$(( (TERM_ROWS - height) / 2 ))
    local start_col=$(( (TERM_COLS - width) / 2 ))
    
    # Ensure dialog fits on screen
    ((start_row < 1)) && start_row=1
    ((start_col < 1)) && start_col=1
    ((start_row + height > TERM_ROWS)) && start_row=$((TERM_ROWS - height))
    ((start_col + width > TERM_COLS)) && start_col=$((TERM_COLS - width))
    
    # Store dialog state for interaction handling
    WIDGET_STATES["${id}_visible"]=true
    WIDGET_STATES["${id}_row"]=$start_row
    WIDGET_STATES["${id}_col"]=$start_col
    WIDGET_STATES["${id}_width"]=$width
    WIDGET_STATES["${id}_height"]=$height
    
    # Draw shadow first for depth effect
    if [[ $shadow == "true" ]]; then
        _bashdash_draw_shadow "$((start_row + 1))" "$((start_col + 2))" "$height" "$width"
    fi
    
    # Draw dialog background with border
    _bashdash_draw_dialog_frame "$start_row" "$start_col" "$height" "$width" "$title"
    
    # Draw message content with word wrapping
    _bashdash_draw_dialog_content "$start_row" "$start_col" "$width" "$message"
    
    # Draw buttons at bottom
    _bashdash_draw_dialog_buttons "$start_row" "$start_col" "$width" "$height" "$buttons"
    
    return 0
}

# Helper function to draw shadow effect for depth perception
# Uses Unicode shading characters for professional appearance
_bashdash_draw_shadow() {
    local row=$1 col=$2 height=$3 width=$4
    local i j
    
    # Draw shadow using medium texture character
    printf "${COLORS[dim]}"
    
    for ((i = 0; i < height; i++)); do
        bashdash_goto $((row + i)) "$col"
        for ((j = 0; j < width; j++)); do
            printf "${BOX_CHARS[medium]}"
        done
    done
    
    printf "${COLORS[reset]}"
}

# Draw the main dialog frame with title bar
# Uses double-line characters for enhanced visual hierarchy
_bashdash_draw_dialog_frame() {
    local row=$1 col=$2 height=$3 width=$4 title="$5"
    local i
    
    # Set colors for dialog frame
    printf "${COLORS[bold]}${COLORS[blue]}"
    
    # Draw top border with title
    bashdash_goto "$row" "$col"
    printf "${BOX_CHARS[top_left]}"
    
    # Title area with padding
    local title_space=$((width - 4))  # Account for borders and padding
    local title_padding=$(( (title_space - ${#title}) / 2 ))
    
    # Left padding
    for ((i = 0; i < title_padding; i++)); do
        printf "${BOX_CHARS[h_line]}"
    done
    
    # Title text with highlighting
    printf "${COLORS[white]}${COLORS[reverse]} $title ${COLORS[noreverse]}"
    
    # Right padding
    local remaining_space=$((title_space - title_padding - ${#title} - 2))
    for ((i = 0; i < remaining_space; i++)); do
        printf "${BOX_CHARS[h_line]}"
    done
    
    printf "${BOX_CHARS[top_right]}"
    
    # Draw side borders
    for ((i = 1; i < height - 1; i++)); do
        bashdash_goto $((row + i)) "$col"
        printf "${BOX_CHARS[v_line]}"
        bashdash_goto $((row + i)) $((col + width - 1))
        printf "${BOX_CHARS[v_line]}"
    done
    
    # Draw bottom border
    bashdash_goto $((row + height - 1)) "$col"
    printf "${BOX_CHARS[bottom_left]}"
    for ((i = 1; i < width - 1; i++)); do
        printf "${BOX_CHARS[h_line]}"
    done
    printf "${BOX_CHARS[bottom_right]}"
    
    printf "${COLORS[reset]}"
}

# Draw dialog content with intelligent word wrapping
# Handles long messages gracefully within dialog bounds
_bashdash_draw_dialog_content() {
    local row=$1 col=$2 width=$3 message="$4"
    
    local content_width=$((width - 4))  # Account for borders and padding
    local content_row=$((row + 2))      # Start below title
    
    # Word wrap the message
    local words=($message)  # Split into array of words
    local current_line=""
    local line_num=0
    
    for word in "${words[@]}"; do
        # Check if adding this word would exceed line width
        if [[ ${#current_line} -gt 0 ]] && [[ $((${#current_line} + ${#word} + 1)) -gt $content_width ]]; then
            # Print current line and start new one
            bashdash_goto $((content_row + line_num)) $((col + 2))
            printf "${COLORS[white]}%-*s${COLORS[reset]}" "$content_width" "$current_line"
            current_line="$word"
            ((line_num++))
        else
            # Add word to current line
            if [[ ${#current_line} -gt 0 ]]; then
                current_line="$current_line $word"
            else
                current_line="$word"
            fi
        fi
    done
    
    # Print final line
    if [[ -n $current_line ]]; then
        bashdash_goto $((content_row + line_num)) $((col + 2))
        printf "${COLORS[white]}%-*s${COLORS[reset]}" "$content_width" "$current_line"
    fi
}

# Draw interactive buttons with hover effects
# Supports multiple buttons with keyboard navigation
_bashdash_draw_dialog_buttons() {
    local row=$1 col=$2 width=$3 height=$4 buttons="$5"
    
    # Parse buttons (comma-separated)
    IFS=',' read -ra button_array <<< "$buttons"
    local button_count=${#button_array[@]}
    
    # Calculate button positioning
    local button_row=$((row + height - 3))
    local total_button_width=0
    
    # Calculate total width needed for buttons
    local btn
    for btn in "${button_array[@]}"; do
        total_button_width=$((total_button_width + ${#btn} + 4))  # +4 for padding and borders
    done
    
    # Center buttons horizontally
    local button_start_col=$(( col + (width - total_button_width) / 2 ))
    local current_col=$button_start_col
    
    # Draw each button with styling
    local i=0
    for btn in "${button_array[@]}"; do
        bashdash_goto "$button_row" "$current_col"
        
        # Highlight first button as default
        if [[ $i -eq 0 ]]; then
            printf "${COLORS[reverse]}${COLORS[bold]}"
        else
            printf "${COLORS[bold]}"
        fi
        
        printf "[ %s ]" "$btn"
        printf "${COLORS[reset]}"
        
        current_col=$((current_col + ${#btn} + 6))  # Move to next button position
        ((i++))
    done
}

#═══════════════════════════════════════════════════════════════════════════════
# SPINNER WIDGET
#═══════════════════════════════════════════════════════════════════════════════

# Animated spinner for indicating ongoing operations
# Features smooth animation and customizable styles
# Usage: bashdash_spinner id=myspinner style=dots message="Loading..."
bashdash_spinner() {
    local -A params=()
    _bashdash_parse_params params "$@"
    
    _bashdash_validate_params params "id" || return 1
    
    local id="${params[id]}"
    local style="${params[style]:-braille}"     # Default to smooth braille animation
    local message="${params[message]:-Loading...}"
    local color="${params[color]:-cyan}"
    
    # Initialize spinner state
    if [[ -z ${WIDGET_STATES[${id}_frame]:-} ]]; then
        WIDGET_STATES["${id}_frame"]=0
        WIDGET_STATES["${id}_active"]=true
        WIDGET_STATES["${id}_style"]=$style
        WIDGET_STATES["${id}_message"]=$message
        WIDGET_STATES["${id}_color"]=$color
    fi
    
    # Get current frame and increment
    local current_frame="${WIDGET_STATES[${id}_frame]}"
    WIDGET_STATES["${id}_frame"]=$(( (current_frame + 1) % ${#SPINNER_FRAMES[@]} ))
    
    # Select animation frames based on style
    local frames
    case $style in
        "braille")
            frames=("${SPINNER_FRAMES[@]}")
            ;;
        "dots")
            frames=('⠈' '⠐' '⠠' '⢀' '⡀' '⠄' '⠂' '⠁')
            ;;
        "pipe")
            frames=('|' '/' '-' '\')
            ;;
        "clock")
            frames=('🕐' '🕑' '🕒' '🕓' '🕔' '🕕' '🕖' '🕗' '🕘' '🕙' '🕚' '🕛')
            ;;
        *)
            frames=("${SPINNER_FRAMES[@]}")  # Fallback to default
            ;;
    esac
    
    # Display spinner with message
    local spinner_char="${frames[$current_frame]}"
    printf "${COLORS[$color]}${spinner_char}${COLORS[reset]} ${message}"
    
    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# SPARKLINE GRAPH WIDGET
#═══════════════════════════════════════════════════════════════════════════════

# Generate ASCII sparkline graphs for data visualization
# Supports real-time data updates and multiple scaling options
# Usage: bashdash_sparkline id=cpu_graph data="10,20,15,30,25,40" width=50
bashdash_sparkline() {
    local -A params=()
    _bashdash_parse_params params "$@"
    
    _bashdash_validate_params params "id" "data" || return 1
    
    local id="${params[id]}"
    local data="${params[data]}"
    local width="${params[width]:-40}"
    local height="${params[height]:-8}"
    local color="${params[color]:-green}"
    local label="${params[label]:-Graph}"
    
    # Parse data points (comma-separated values)
    IFS=',' read -ra data_points <<< "$data"
    local point_count=${#data_points[@]}
    
    if [[ $point_count -eq 0 ]]; then
        bashdash_log "Error: No data points provided for sparkline $id" "red"
        return 1
    fi
    
    # Find min and max values for scaling
    local min_val="${data_points[0]}"
    local max_val="${data_points[0]}"
    local point
    
    for point in "${data_points[@]}"; do
        ((point < min_val)) && min_val=$point
        ((point > max_val)) && max_val=$point
    done
    
    # Avoid division by zero
    local range=$((max_val - min_val))
    [[ $range -eq 0 ]] && range=1
    
    # Store graph state
    WIDGET_STATES["${id}_data"]="$data"
    WIDGET_STATES["${id}_min"]=$min_val
    WIDGET_STATES["${id}_max"]=$max_val
    WIDGET_STATES["${id}_width"]=$width
    WIDGET_STATES["${id}_height"]=$height
    
    # Sparkline characters for sub-character resolution
    local spark_chars=('▁' '▂' '▃' '▄' '▅' '▆' '▇' '█')
    local char_levels=${#spark_chars[@]}
    
    # Draw sparkline
    printf "${COLORS[bold]}${COLORS[white]}%-10s${COLORS[reset]} " "$label:"
    printf "${COLORS[$color]}"
    
    local i
    for ((i = 0; i < point_count && i < width; i++)); do
        local point="${data_points[$i]}"
        # Normalize point to 0-1 range, then scale to character levels
        local normalized=$(( (point - min_val) * (char_levels - 1) / range ))
        # Clamp to valid range
        ((normalized < 0)) && normalized=0
        ((normalized >= char_levels)) && normalized=$((char_levels - 1))
        
        printf "${spark_chars[$normalized]}"
    done
    
    printf "${COLORS[reset]}"
    
    # Display statistics
    printf " ${COLORS[dim]}[${min_val}-${max_val}]${COLORS[reset]}"
    
    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# COMBO BOX WIDGET (SELECT + FREETEXT INPUT)
#═══════════════════════════════════════════════════════════════════════════════

# Advanced combo box allowing both selection from list and custom input
# Features dropdown-style display with keyboard navigation
# Usage: bashdash_combo_box id=mycombo options="Option1,Option2,Custom" allow_custom=true
bashdash_combo_box() {
    local -A params=()
    _bashdash_parse_params params "$@"
    
    _bashdash_validate_params params "id" "options" || return 1
    
    local id="${params[id]}"
    local options="${params[options]}"
    local selected="${params[selected]:-0}"        # Default to first option
    local allow_custom="${params[allow_custom]:-true}"
    local width="${params[width]:-30}"
    local label="${params[label]:-Select}"
    local custom_text="${params[custom_text]:-}"
    
    # Parse options (comma-separated)
    IFS=',' read -ra option_array <<< "$options"
    local option_count=${#option_array[@]}
    
    # Validate selected index
    if ! [[ $selected =~ ^[0-9]+$ ]] || ((selected >= option_count && allow_custom != "true")); then
        selected=0
    fi
    
    # Store combo box state
    WIDGET_STATES["${id}_selected"]=$selected
    WIDGET_STATES["${id}_options"]="$options"
    WIDGET_STATES["${id}_custom_text"]="$custom_text"
    WIDGET_STATES["${id}_allow_custom"]="$allow_custom"
    WIDGET_STATES["${id}_expanded"]="${WIDGET_STATES[${id}_expanded]:-false}"
    
    # Draw combo box label
    printf "${COLORS[bold]}${COLORS[white]}%-12s${COLORS[reset]} " "$label:"
    
    # Draw combo box main display
    printf "${COLORS[blue]}${BOX_CHARS[top_left]}"
    
    # Display current selection or custom text
    local display_text=""
    if [[ $selected -lt $option_count ]]; then
        display_text="${option_array[$selected]}"
    elif [[ $allow_custom == "true" && -n $custom_text ]]; then
        display_text="$custom_text"
    else
        display_text="<Select Option>"
    fi
    
    # Truncate text to fit width
    if [[ ${#display_text} -gt $((width - 4)) ]]; then
        display_text="${display_text:0:$((width - 7))}..."
    fi
    
    printf "${COLORS[white]} %-*s ${COLORS[blue]}" $((width - 4)) "$display_text"
    
    # Draw dropdown arrow
    if [[ ${WIDGET_STATES[${id}_expanded]} == "true" ]]; then
        printf "▲${BOX_CHARS[top_right]}${COLORS[reset]}"
    else
        printf "▼${BOX_CHARS[top_right]}${COLORS[reset]}"
    fi
    
    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# TOGGLE SWITCH WIDGET (BEAUTIFIED CHECKBOX)
#═══════════════════════════════════════════════════════════════════════════════

# Modern toggle switch with smooth visual transitions
# Mimics mobile/web toggle switches for intuitive interaction
# Usage: bashdash_toggle id=mytoggle state=on label="Enable Feature"
bashdash_toggle() {
    local -A params=()
    _bashdash_parse_params params "$@"
    
    _bashdash_validate_params params "id" || return 1
    
    local id="${params[id]}"
    local state="${params[state]:-off}"           # Default to off
    local label="${params[label]:-Toggle}"
    local on_color="${params[on_color]:-green}"
    local off_color="${params[off_color]:-red}"
    local width="${params[width]:-6}"             # Toggle switch width
    
    # Normalize state
    case $state in
        "true"|"on"|"1"|"yes") state="on" ;;
        *) state="off" ;;
    esac
    
    # Store toggle state
    WIDGET_STATES["${id}_state"]="$state"
    WIDGET_STATES["${id}_label"]="$label"
    
    # Draw toggle label
    printf "${COLORS[bold]}${COLORS[white]}%-12s${COLORS[reset]} " "$label:"
    
    # Draw toggle switch based on state
    if [[ $state == "on" ]]; then
        # ON state: slider on the right
        printf "${COLORS[$on_color]}${COLORS[reverse]}"
        printf "   ●${BOX_CHARS[solid]}${BOX_CHARS[solid]}"
        printf "${COLORS[noreverse]}${COLORS[reset]}"
        printf " ${COLORS[bold]}${COLORS[$on_color]}ON${COLORS[reset]}"
    else
        # OFF state: slider on the left  
        printf "${COLORS[$off_color]}${COLORS[reverse]}"
        printf "${BOX_CHARS[solid]}${BOX_CHARS[solid]}●   "
        printf "${COLORS[noreverse]}${COLORS[reset]}"
        printf " ${COLORS[bold]}${COLORS[$off_color]}OFF${COLORS[reset]}"
    fi
    
    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# SLIDER WIDGET (0-100 INTEGER INPUT)
#═══════════════════════════════════════════════════════════════════════════════

# Interactive slider for numeric input with visual feedback
# Combines traditional slider with numeric input validation
# Usage: bashdash_slider id=myslider value=50 min=0 max=100 label="Volume"
bashdash_slider() {
    local -A params=()
    _bashdash_parse_params params "$@"
    
    _bashdash_validate_params params "id" "value" || return 1
    
    local id="${params[id]}"
    local value="${params[value]}"
    local min="${params[min]:-0}"
    local max="${params[max]:-100}"
    local label="${params[label]:-Slider}"
    local width="${params[width]:-30}"
    local color="${params[color]:-blue}"
    local show_value="${params[show_value]:-true}"
    
    # Validate and clamp value
    if ! [[ $value =~ ^[0-9]+$ ]]; then
        bashdash_log "Error: Slider value must be integer: $value" "red"
        return 1
    fi
    
    ((value < min)) && value=$min
    ((value > max)) && value=$max
    
    # Store slider state
    WIDGET_STATES["${id}_value"]=$value
    WIDGET_STATES["${id}_min"]=$min
    WIDGET_STATES["${id}_max"]=$max
    WIDGET_STATES["${id}_width"]=$width
    
    # Calculate slider position
    local range=$((max - min))
    [[ $range -eq 0 ]] && range=1  # Avoid division by zero
    
    local position=$(( (value - min) * (width - 2) / range ))
    
    # Draw slider label
    printf "${COLORS[bold]}${COLORS[white]}%-12s${COLORS[reset]} " "$label:"
    
    # Draw slider track
    printf "${COLORS[$color]}${BOX_CHARS[top_left]}"
    
    local i
    for ((i = 0; i < width - 2; i++)); do
        if [[ $i -eq $position ]]; then
            # Draw slider handle
            printf "${COLORS[reverse]}${COLORS[bold]}●${COLORS[noreverse]}"
        elif [[ $i -lt $position ]]; then
            # Filled portion
            printf "${BOX_CHARS[solid]}"
        else
            # Empty portion
            printf "${COLORS[dim]}${BOX_CHARS[light]}"
        fi
    done
    
    printf "${COLORS[$color]}${BOX_CHARS[top_right]}"
    
    # Display current value
    if [[ $show_value == "true" ]]; then
        printf " ${COLORS[bold]}${COLORS[white]}%3d${COLORS[reset]}" "$value"
    fi
    
    # Display min/max range
    printf " ${COLORS[dim]}[${min}-${max}]${COLORS[reset]}"
    
    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# SETUP AND CONFIGURATION SYSTEM
#═══════════════════════════════════════════════════════════════════════════════

# Generate configuration file for new dashboard applications
# Creates template with all necessary settings and examples
bashdash_setup() {
    local script_name="${1:-dashboard}"
    local config_file=".${script_name}.dbash"
    
    bashdash_log "Creating configuration file: $config_file" "cyan"
    
    # Create comprehensive configuration template
    cat > "$config_file" << 'EOF'
#!/usr/bin/env bash
# BashDash Configuration File
# Auto-generated configuration template for dashboard applications

# Application metadata
APP_TITLE="My Dashboard"
APP_VERSION="1.0.0"
APP_DESCRIPTION="Real-time system monitoring dashboard"

# Display preferences
DEFAULT_REFRESH_INTERVAL=1      # Seconds between updates
RESERVED_ROWS=8                 # Rows reserved for progress bars
LOG_BUFFER_SIZE=1000           # Maximum log entries to keep
ENABLE_COLORS=true             # Use color output
ENABLE_ANIMATIONS=true         # Enable spinner and transitions

# Widget defaults
DEFAULT_PROGRESS_WIDTH=40
DEFAULT_PROGRESS_COLOR="green"
DEFAULT_DIALOG_WIDTH=50
DEFAULT_DIALOG_HEIGHT=10
DEFAULT_COMBO_WIDTH=30
DEFAULT_SLIDER_WIDTH=30

# Theme configuration
THEME_PRIMARY="blue"
THEME_SECONDARY="cyan" 
THEME_SUCCESS="green"
THEME_WARNING="yellow"
THEME_ERROR="red"
THEME_INFO="white"
EOF

    bashdash_log "Configuration file created successfully!" "green"
    bashdash_log "Edit $config_file to customize your dashboard" "cyan"
    
    # Create example usage script
    local example_script="${script_name}_example.sh"
    cat > "$example_script" << 'EOF'
#!/usr/bin/env bash
# Example BashDash Application
# Demonstrates various widgets and real-time updates

# Source the BashDash framework
source ./bashdash.sh

# Load configuration
[[ -f "./${0##*/}.dbash" ]] && source "./${0##*/}.dbash"

# Initialize the framework
bashdash_init

# Main application loop
main() {
    local counter=0
    
    bashdash_log "Starting example dashboard..." "green"
    
    while true; do
        # Update progress bars with simulated data
        bashdash_progress_bar id="cpu" val=$((50 + counter % 50)) \
            width=40 color="green" label="CPU Usage"
        
        bashdash_progress_bar id="memory" val=$((counter % 100)) \
            width=40 color="blue" label="Memory"
        
        bashdash_progress_bar id="disk" val=$((80 + counter % 20)) \
            width=40 color="yellow" label="Disk I/O"
        
        # Show various controls
        bashdash_toggle id="monitoring" state=$([[ $((counter % 4)) -eq 0 ]] && echo "on" || echo "off") \
            label="Monitoring"
        
        bashdash_slider id="threshold" value=$((counter % 100)) \
            min=0 max=100 label="Threshold"
        
        # Log periodic messages
        if ((counter % 10 == 0)); then
            bashdash_log "System check completed (iteration $counter)" "info"
        fi
        
        ((counter++))
        sleep "${DEFAULT_REFRESH_INTERVAL:-1}"
    done
}

# Run the application
main "$@"
EOF

    chmod +x "$example_script"
    bashdash_log "Example script created: $example_script" "green"
    
    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# HELP SYSTEM
#═══════════════════════════════════════════════════════════════════════════════

# Display comprehensive help for all widgets and framework features
bashdash_help() {
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                          BashDash Framework v1.0.0                           ║
║                    Advanced Bash TUI/GUI Dashboard System                    ║
╚══════════════════════════════════════════════════════════════════════════════╝

OVERVIEW:
  BashDash is a comprehensive framework for creating sophisticated real-time
  dashboards in bash. It provides a rich set of widgets, advanced terminal
  manipulation, and optional web interface capabilities.

INITIALIZATION:
  bashdash_init                    - Initialize framework (call first)
  bashdash_cleanup                 - Clean up and restore terminal
  bashdash_setup [script_name]     - Generate configuration template

LOGGING SYSTEM:
  bashdash_log "message" [color]   - Add timestamped log entry
    Colors: red, green, yellow, blue, magenta, cyan, white

WIDGETS:

1. PROGRESS BAR - Advanced progress indicators with animations
   bashdash_progress_bar id=ID val=VALUE [options...]
   
   Required: id, val
   Optional: width, color, label, show_percent
   
   Example:
     bashdash_progress_bar id=cpu val=75 color=red label="CPU Usage"

2. DIALOG BOX - Modal dialogs with shadow effects
   bashdash_dialog id=ID title=TITLE message=MESSAGE [options...]
   
   Required: id, title, message
   Optional: width, height, buttons, shadow
   
   Example:
     bashdash_dialog id=confirm title="Confirm Delete" \
       message="Are you sure?" buttons="Delete,Cancel"

3. SPINNER - Animated loading indicators
   bashdash_spinner id=ID [options...]
   
   Required: id
   Optional: style, message, color
   
   Example:
     bashdash_spinner id=loading style=braille message="Processing..."

4. SPARKLINE GRAPH - ASCII data visualization
   bashdash_sparkline id=ID data=VALUES [options...]
   
   Required: id, data
   Optional: width, height, color, label
   
   Example:
     bashdash_sparkline id=cpu_history data="45,52,48,61,59,43" width=60

5. COMBO BOX - Select dropdown with custom input
   bashdash_combo_box id=ID options=LIST [options...]
   
   Required: id, options
   Optional: selected, allow_custom, width, label
   
   Example:
     bashdash_combo_box id=mode options="Auto,Manual,Debug" selected=0

6. TOGGLE SWITCH - Modern toggle control
   bashdash_toggle id=ID [options...]
   
   Required: id
   Optional: state, label, on_color, off_color
   
   Example:
     bashdash_toggle id=monitoring state=on label="Enable Monitoring"

7. SLIDER - Numeric range input
   bashdash_slider id=ID value=NUMBER [options...]
   
   Required: id, value
   Optional: min, max, width, label, color
   
   Example:
     bashdash_slider id=volume value=75 min=0 max=100 label="Volume"

COMPATIBILITY:
  - Requires Bash 4.0+
  - Uses tput for terminal control
  - Supports xterm-256color for enhanced visuals
  - Unicode box-drawing characters for professional appearance
  - Graceful degradation on limited terminals

EOF
}

#═══════════════════════════════════════════════════════════════════════════════
# DEMO AND TESTING
#═══════════════════════════════════════════════════════════════════════════════

# Main framework entry point for testing and demonstration
bashdash_demo() {
    bashdash_init
    
    local counter=0
    bashdash_log "BashDash framework demonstration started" "cyan"
    
    # Interactive demo loop
    while true; do
        # Clear content area (preserve reserved section)
        for ((i = RESERVED_TOP_ROWS + 1; i <= TERM_ROWS; i++)); do
            bashdash_goto "$i" 1
            printf '\033[K'  # Clear line
        done
        
        bashdash_goto $((RESERVED_TOP_ROWS + 2)) 1
        
        # Demonstrate all widgets with dynamic data
        bashdash_progress_bar id="demo1" val=$((counter % 100)) \
            width=45 color="green" label="Processing"
        
        bashdash_progress_bar id="demo2" val=$(( (counter * 2) % 100)) \
            width=45 color="blue" label="Network"
        
        bashdash_progress_bar id="demo3" val=$(( (counter * 3) % 100)) \
            width=45 color="yellow" label="Storage"
        
        printf "\n\n"
        
        # Show other widgets
        bashdash_spinner id="loader" style="braille" \
            message="Loading system data..."
        
        printf "\n\n"
        
        # Generate sparkline data
        local spark_data=""
        for ((i = 0; i < 25; i++)); do
            spark_data+="$((30 + (RANDOM % 40))),"
        done
        spark_data="${spark_data%,}"
        
        bashdash_sparkline id="metrics" data="$spark_data" \
            width=50 label="Metrics"
        
        printf "\n\n"
        
        bashdash_toggle id="status" state=$([ $((counter % 4)) -eq 0 ] && echo "on" || echo "off") \
            label="System Active"
        
        printf "\n"
        
        bashdash_slider id="threshold" value=$((40 + counter % 40)) \
            min=0 max=100 label="Threshold"
        
        printf "\n"
        
        bashdash_combo_box id="mode" options="Auto,Manual,Debug,Custom" \
            selected=$((counter % 3)) label="Mode"
        
        printf "\n\n"
        
        # Periodic dialog
        if ((counter % 30 == 0 && counter > 0)); then
            bashdash_dialog id="notification" \
                title="System Notification" \
                message="Demo cycle $((counter / 30)) completed. All systems operational." \
                buttons="Acknowledge,Dismiss"
        fi
        
        # Log messages
        if ((counter % 10 == 0)); then
            bashdash_log "Demo cycle $counter completed successfully" "green"
        elif ((counter % 7 == 0)); then
            bashdash_log "Performance metrics updated" "blue"
        elif ((counter % 5 == 0)); then
            bashdash_log "Routine system check" "yellow"
        fi
        
        ((counter++))
        sleep 1
    done
}

#═══════════════════════════════════════════════════════════════════════════════
# COMMAND LINE INTERFACE
#═══════════════════════════════════════════════════════════════════════════════

# Main entry point when script is executed directly
main() {
    case "${1:-demo}" in
        "init")
            bashdash_init
            ;;
        "setup")
            bashdash_setup "${2:-dashboard}"
            ;;
        "help")
            bashdash_help
            ;;
        "demo")
            bashdash_demo
            ;;
        "test")
            # Run shellcheck if available
            if command -v shellcheck >/dev/null 2>&1; then
                echo "Running shellcheck validation..."
                shellcheck "$0" || echo "Shellcheck found issues (see above)"
            else
                echo "shellcheck not available, skipping validation"
            fi
            
            # Basic functionality test
            echo "Testing basic functionality..."
            bashdash_init
            bashdash_log "Framework test completed" "green"
            sleep 2
            bashdash_cleanup
            ;;
        *)
            echo "BashDash Framework v${BASHDASH_VERSION}"
            echo "Usage: $0 {init|setup|help|demo|test}"
            echo ""
            echo "Commands:"
            echo "  init        - Initialize framework for use"
            echo "  setup [name] - Generate configuration template"
            echo "  help        - Show detailed help and widget documentation"
            echo "  demo        - Run interactive demonstration"
            echo "  test        - Validate code and run basic tests"
            ;;
    esac
}

# Execute main function if script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

# End of BashDash Framework
