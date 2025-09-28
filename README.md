# BashDash Framework

## 🎯 Key Features

### Sophisticated Widget System

- Progress Bars: 

Animated with gradients

shadows

real-time updates

- Dialogs: 

Modal windows with drop shadows and professional styling

- Spinners:

Multiple animation styles (braille, dots, pipe, clock)

- Sparkline Graphs: 

ASCII data visualization with scaling

- Combo Boxes: 

Select dropdowns with custom text input capability

- Toggle Switches: 

Modern on/off controls with smooth animations

- Sliders: 

Interactive range inputs with visual feedback


### Advanced Architecture

- State Management: 

Associative arrays for O(1) widget lookups

- Transportable Widgets: 

Self-contained functions with isolated state

- Parameter Parsing: 

Flexible key=value parameter system

- Error Handling: 

Robust validation and graceful degradation

- Memory Efficient: 

Circular buffers and optimized data structures

### Professional Documentation

- Extensive Comments: 

Every function thoroughly documented

- Usage Examples: 

Clear examples for each widget

- Help System: 

Comprehensive built-in help with bashdash_help

- Configuration: 



Auto-generated config files with bashdash_setup

### Web Interface 🌐

- Modern Design: 

Glass-morphism styling with Bootstrap 5

- Progressive Web App: 

Offline capability and mobile-responsive

- Canvas Graphics: 

Smooth animations and real-time charts

- Professional UI: 

Apple-inspired design language


## 🚀 Usage Examples


```
#!/usr/bin/env bash
source ./bashdash.sh

bashdash_init

# Create progress bars
bashdash_progress_bar id=cpu val=75 color=green label="CPU Usage"
bashdash_progress_bar id=memory val=+5 width=50  # Relative update

# Show interactive dialog
bashdash_dialog id=confirm title="System Alert" \
    message="High CPU usage detected. Restart service?" \
    buttons="Restart,Ignore,Details"

# Display data visualization
bashdash_sparkline id=network data="10,25,30,45,60,55,40" \
    width=60 label="Network Traffic"

# Modern controls
bashdash_toggle id=monitoring state=on label="Auto Monitor"
bashdash_slider id=threshold value=80 min=0 max=100 label="Alert Level"

# Logging with colors
bashdash_log "System initialization complete" "green"
```


## 🛠️ Setup and Configuration


```
# Generate config template and example
./bashdash.sh setup my_dashboard

# Start web interface
./bashdash.sh web 8080

# Run interactive demo
./bashdash.sh demo

# Show comprehensive help
./bashdash.sh help
```


## 💻 Shell Compatibility


### The framework passes shellcheck validation and includes:

- Bash 4.0+ compatibility

- Strict error handling (set -euo pipefail)

- Terminal capability detection

- Graceful fallbacks for limited terminals

- Unicode support with ASCII alternatives


### 🎨 Advanced Features

- 256-color support with automatic detection

- Box-drawing characters for professional appearance

- Reserved screen areas for organized layouts

- Real-time updates without screen flicker

- Signal handling for clean exits

- Performance optimization with caching

This framework represents a significant advancement in bash TUI development, combining the power of modern terminal capabilities with professional software engineering practices. It's designed to be both a powerful tool and an educational resource for advanced bash scripting techniques.
tHE Web interface provides a stunning alternative with modern web technologies, making it suitable for both terminal enthusiasts and users who prefer web-based dashboards.RetryClaude can make mistakes. Please double-check responses.
