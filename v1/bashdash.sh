#!/usr/bin/env bash
: <<DOCXX

Description: A reusable Bash terminal dashboard framework
Author     : morgan@morganism.dev
Date       : Sun 28 Sep 2025 15:46:24 BST

#-----------------------------------------------------------------------------
# bashdash.sh — BashDash framework
#-----------------------------------------------------------------------------
#
# PURPOSE:
#  - A reusable Bash terminal dashboard framework for installer/deploy scripts.
#  - Keeps an area at the top of the terminal for status/progress badges and
#    a log area beneath it. Background tasks update status via files so the
#    main dashboard loop (in the parent shell) can read and render live.
#
# USAGE:
#  - Interactive setup (creates config):  ./bashdash.sh setup
#  - Show help:                            ./bashdash.sh help
#  - Source in a project script:
#       source ./bashdash.sh
#       tui_init
#       tui_register_task "Download"
#       tui_start_task "Download" download_func
#       tui_loop
#       tui_cleanup
#
# NOTE:
#  - This file is written for Bash (arrays, parameter expansion).
#  - Many lines below include inline comments explaining "what", "why" and
#    "how" the variables are set and how they change at runtime.
#
#-----------------------------------------------------------------------------
DOCXX




#-----------------------------------------------------------------------------
# ----------------------------
# =  DEFAULT CONFIG VALUES  =
# ----------------------------
# BASHDASH_CONFIG_FILE: path where interactive setup writes config.
#   Default: ./bashdash.conf (project-local config by default).
#   This can be overridden by exporting BASHDASH_CONFIG_FILE before sourcing.

BASHDASH_CONFIG_FILE="./bashdash.conf"

# DASH_ROWS_RESERVED: how many terminal lines at top are reserved for dashboard.
#   Default: 10 lines. This determines where log output begins.
#   Value can be changed by tui_setup() or by the config file.

DASH_ROWS_RESERVED=10

# DASH_REFRESH_INTERVAL: how often the dashboard redraws (seconds).
#   Default: 0.1 (i.e. 10 FPS-ish). Smaller is more responsive, larger lowers CPU.
#   Derived from default or overwritten by config produced by tui_setup().

DASH_REFRESH_INTERVAL=0.1

#-----------------------------------------------------------------------------




#-----------------------------------------------------------------------------
# ----------------------------
# =  LOAD CONFIG IF PRESENT  =
# ----------------------------
# If a config file exists at BASHDASH_CONFIG_FILE, source it so the user
# can override the defaults above. The config file (written by tui_setup)
# should define variables such as DASH_REFRESH_INTERVAL and DASH_ROWS_RESERVED,
# as well as project-level variables (e.g., DOWNLOAD_URL).
#
# We check for existence here so that when this file is sourced by another
# script, configuration is automatically applied.
if [[ -f "$BASHDASH_CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$BASHDASH_CONFIG_FILE"
    # After sourcing, DASH_REFRESH_INTERVAL / DASH_ROWS_RESERVED / other
    # project-specific variables are available in this shell.
fi
#-----------------------------------------------------------------------------




#-----------------------------------------------------------------------------
# ----------------------------
# =    UI / COLOR SETUP     =
# ----------------------------
# reset: ANSI escape to clear styles (used after colored output).
# colors[]: array of ANSI background color sequences.
#   Index mapping used later:
#     0 -> red (failure)
#     1 -> amber (running)
#     2 -> green (success)
#     6 -> grey (not started)
reset="\e[0m"
colors=(
  "\e[41m"  # 0 : red (failure)
  "\e[43m"  # 1 : amber (running)
  "\e[42m"  # 2 : green (success)
  "\e[44m"  # 3 : blue (unused default)
  "\e[47m"  # 4 : bright white (unused default)
  "\e[37m"  # 5 : white (unused default)
  "\e[90m"  # 6 : grey (not started)
)
#-----------------------------------------------------------------------------




#-----------------------------------------------------------------------------
# ----------------------------
# =   TASK STATE (IN-MEM)   =
# ----------------------------
# We maintain associative arrays in-memory for convenience, but note:
#   - Background subshells cannot update these arrays in the parent shell.
#   - Therefore we also use file-backed state for progress/status that is
#     written by background tasks and read by the dashboard loop.
declare -A tui_task_status    # quick in-memory map: name -> last-known status
declare -A tui_task_progress  # quick in-memory map: name -> last-known progress
declare -A tui_task_file      # name -> path of progress file (on disk)
declare -A tui_status_file    # name -> path of status file (on disk)
tui_task_list=()              # ordered array (preserves registration order)
#-----------------------------------------------------------------------------




#-----------------------------------------------------------------------------
# ----------------------------
# =    SETUP / CONFIG UI    =
# ----------------------------
# tui_setup: interactive helper to collect config values and write them to the
# config file specified by $BASHDASH_CONFIG_FILE (defaults above).
# - Prompts for dashboard behavior and project-specific values.
# - Writes a shell-compatible config file that will be sourced when bashdash.sh loads.
tui_setup() {
    # show a friendly intro so the user knows what's happening
    echo "=== BashDash Setup ==="
    echo "This creates (or overwrites) the config file: $BASHDASH_CONFIG_FILE"
    echo

    # Prompt for refresh interval; if user inputs nothing we keep current value.
    # We read into a temporary local so we don't clobber the global until confirmed.
    read -r -p "Dashboard refresh interval in seconds [${DASH_REFRESH_INTERVAL}]: " _interval
    if [[ -n "${_interval}" ]]; then
        # Validate numeric-ish input; if invalid, keep the previous value.
        if [[ "${_interval}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
            DASH_REFRESH_INTERVAL="${_interval}"
        else
            echo "Invalid number; keeping ${DASH_REFRESH_INTERVAL}"
        fi
    fi

    # Prompt for how many rows to reserve for the dashboard.
    read -r -p "Rows reserved for dashboard above logs [${DASH_ROWS_RESERVED}]: " _rows
    if [[ -n "${_rows}" ]]; then
        if [[ "${_rows}" =~ ^[0-9]+$ ]]; then
            DASH_ROWS_RESERVED="${_rows}"
        else
            echo "Invalid integer; keeping ${DASH_ROWS_RESERVED}"
        fi
    fi

    # Project-specific variables (these are examples; you can expand them).
    # DOWNLOAD_URL: Where an installer might download an artifact from.
    read -r -p "Download URL [https://example.com/file.tar.gz]: " _dl
    if [[ -z "${_dl}" ]]; then
        DOWNLOAD_URL="https://example.com/file.tar.gz"
    else
        DOWNLOAD_URL="${_dl}"
    fi

    # TARGET_PATH: path to inspect for disk usage (used by example)
    read -r -p "Target path for disk check [/]: " _tp
    TARGET_PATH="${_tp:-/}"

    # SERVICE_NAME: service to monitor in the example
    read -r -p "Service name to check [sshd]: " _svc
    SERVICE_NAME="${_svc:-sshd}"

    # Write collected config to BASHDASH_CONFIG_FILE as a shell fragment.
    # This makes it easy to source from other scripts.
    cat > "$BASHDASH_CONFIG_FILE" <<EOF
# bashdash.conf — generated by tui_setup on $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# Values below override the defaults in bashdash.sh when sourced.
DASH_REFRESH_INTERVAL=${DASH_REFRESH_INTERVAL}
DASH_ROWS_RESERVED=${DASH_ROWS_RESERVED}
DOWNLOAD_URL="${DOWNLOAD_URL}"
TARGET_PATH="${TARGET_PATH}"
SERVICE_NAME="${SERVICE_NAME}"
EOF

    echo "Config written to $BASHDASH_CONFIG_FILE"
    echo "You can edit that file to tweak values or re-run './bashdash.sh setup' to regenerate it."
}
#-----------------------------------------------------------------------------




#-----------------------------------------------------------------------------
# ----------------------------
# =    INITIALIZATION       =
# ----------------------------
# tui_init: prepare the terminal and internal state for dashboard use.
#  - Clears the screen
#  - Hides the cursor
#  - Sets where log lines begin (tui_log_line) based on DASH_ROWS_RESERVED
#  - Ensures /tmp/tui exists to hold per-task state files
tui_init() {
    # Clear the visible screen so our dashboard starts at top-left.
    clear
    # Hide the cursor so updates look cleaner.
    tput civis
    # Where logs will begin printing (line number; top-left is 0).
    # Derived directly from configured value DASH_ROWS_RESERVED (config file or default).
    tui_log_line=$DASH_ROWS_RESERVED
    # Ensure a temporary directory exists to hold progress/status files.
    # Using /tmp/tui so files are per-machine and not committed to project.
    mkdir -p /tmp/tui
}
#-----------------------------------------------------------------------------




#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------
# tui_cleanup: restore terminal state when done.
tui_cleanup() {
    # Show the cursor again to leave terminal in normal state.
    tput cnorm
    # Print a trailing newline to move the shell prompt below dashboard/logs.
    echo
}
#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------




#-----------------------------------------------------------------------------
# ----------------------------
# =    TASK REGISTRATION    =
# ----------------------------
# tui_register_task(NAME)
#   - Register a task to be tracked by the dashboard.
#   - Creates per-task backing files used by background tasks to communicate
#     progress & status back to the parent shell.
tui_register_task() {
    # Parameter: task name (string; may include spaces)
    local name="$1"
    # Append to the ordered list so display appears in registration order.
    tui_task_list+=("$name")
    # Initialize in-memory maps (convenience; actual real-time state is file-backed).
    tui_task_status["$name"]=0
    tui_task_progress["$name"]=0
    # Derive filenames used to store state on disk.
    # Replace spaces with underscores to create safe filenames:
    #   e.g., "Download File" -> /tmp/tui/Download_File.progress
    tui_task_file["$name"]="/tmp/tui/${name// /_}.progress"
    tui_status_file["$name"]="/tmp/tui/${name// /_}.status"
    # Seed the files with "0" (not started / 0%).
    echo 0 > "${tui_task_file[$name]}"
    echo 0 > "${tui_status_file[$name]}"
}
#-----------------------------------------------------------------------------




#-----------------------------------------------------------------------------
# ----------------------------
# =     TASK STARTER        =
# ----------------------------
# tui_start_task(NAME, FUNC_NAME)
#   - Runs the function FUNC_NAME in a background subshell and marks status=1.
#   - The function receives the task NAME as an argument; it's expected to
#     write progress and status to the corresponding files (see example below).
tui_start_task() {
    local name="$1"
    local func="$2"
    # Run in a subshell so caller can continue; writing "1" marks "running".
    (
        # Write "1" (running) to the status file for this task.
        echo 1 > "${tui_status_file[$name]}"
        # Call the user-supplied function, passing the task name so it can find file paths.
        # The child process will write progress to the files; the parent reads them.
        "$func" "$name"
    ) &  # background the subshell so multiple tasks can run concurrently
}
#-----------------------------------------------------------------------------




#-----------------------------------------------------------------------------
# ----------------------------
# =     DASHBOARD DRAW      =
# ----------------------------
# tui_draw_dashboard()
#   - Reads the file-backed state for each registered task and prints the
#     dashboard area (reserved lines at top). Uses ANSI color sequences.
tui_draw_dashboard() {
    # Move cursor to row 0, column 0 so we always overwrite the reserved area.
    # This prevents the dashboard and logs from colliding and causing jitter.
    tput cup 0 0

    # Header line
    echo "---- Deployment Dashboard ----"

    # Iterate over tasks in registration order so ordering is stable.
    for name in "${tui_task_list[@]}"; do
        # Read latest progress (written by background task) from its file.
        # This file-based exchange is why background tasks can run in subshells —
        # they write to the file; parent reads it to render.
        local progress
        # Protect against empty files by defaulting to 0 via parameter expansion
        progress="$(cat "${tui_task_file[$name]}" 2>/dev/null || echo 0)"
        # Read numeric status (0=not started,1=running,2=success,3=fail)
        local status
        status="$(cat "${tui_status_file[$name]}" 2>/dev/null || echo 0)"

        # Choose color (ANSI sequence) based on status. Colors array defined earlier.
        local color
        case "$status" in
            0) color="${colors[6]}" ;;  # grey   -> not started
            1) color="${colors[1]}" ;;  # amber  -> running
            2) color="${colors[2]}" ;;  # green  -> success
            3) color="${colors[0]}" ;;  # red    -> fail
            *) color="${colors[6]}" ;;  # fallback to grey for unknown values
        esac

        # Print a single dashboard row: colored badge, padded name and progress.
        # "%b" interprets the ANSI escape sequences stored in $color & $reset.
        # %-20s left-aligns the name to 20 characters so columns line up.
        printf "%b %-20s %b [%3d%%]\n" "$color" "$name" "$reset" "$progress"
    done

    # Footer line and start-of-log marker (static)
    echo "------------------------------"
    echo "Log output below:"
}
#-----------------------------------------------------------------------------




#-----------------------------------------------------------------------------
# ----------------------------
# =        LOGGING          =
# ----------------------------
# tui_log(MSG)
#   - Prints MSG on the current log line and increments the log line pointer.
#   - Ensures logs are printed below the reserved dashboard area and never mix.
tui_log() {
    local msg="$1"
    # Place cursor at the current log line (column 0).
    tput cup "$tui_log_line" 0
    # Print the message; -e interprets escapes if present (useful if messages contain \n).
    echo -e "$msg"
    # Move pointer down for next message so logs append vertically.
    ((tui_log_line++))
}
#-----------------------------------------------------------------------------




#-----------------------------------------------------------------------------
# ----------------------------
# =       MAIN LOOP         =
# ----------------------------
# tui_loop()
#   - Keeps redrawing the dashboard until no tasks have status "running"
#   - Reads the file-backed status values to determine whether to continue
tui_loop() {
    # main refresh loop
    while :; do
        tui_draw_dashboard             # redraw reserved dashboard area
        # sleep for configured interval (config file or defaults)
        sleep "$DASH_REFRESH_INTERVAL"

        # determine whether any registered task is still in "running" state
        local still_running=false
        for name in "${tui_task_list[@]}"; do
            # read status file (file-backed) to include updates from child processes
            local status
            status="$(cat "${tui_status_file[$name]}" 2>/dev/null || echo 0)"
            if [[ "$status" == "1" ]]; then
                still_running=true
                break
            fi
        done

        # if no tasks are running, break out of the loop and finish
        $still_running || break
    done
}
#-----------------------------------------------------------------------------




#-----------------------------------------------------------------------------
# ----------------------------
# =         HELP TEXT       =
# ----------------------------
# tui_help(): comprehensive usage instructions so users can read this
# file and run tui_setup to generate a config and use BashDash in projects.
tui_help() {
    cat <<EOF
BashDash Framework — comprehensive help

How to use (interactive setup + example workflow):

1) Generate a config (interactive):
   ./bashdash.sh setup
   - This writes a shell fragment to $BASHDASH_CONFIG_FILE (default ./bashdash.conf)
   - Config contains: DASH_REFRESH_INTERVAL and DASH_ROWS_RESERVED plus sample
     project values such as DOWNLOAD_URL, TARGET_PATH, SERVICE_NAME.

2) Source bashdash.sh in your installer script:
   source ./bashdash.sh

3) Initialize dashboard in your script:
   tui_init      # prepares terminal and internal temp dir

4) Register tasks (order matters for display):
   tui_register_task "Download"
   tui_register_task "Disk Check"
   tui_register_task "Service Status"

   Each registered task will create a pair of files in /tmp/tui:
     - /tmp/tui/TaskName.progress  (contains a number 0-100)
     - /tmp/tui/TaskName.status    (contains the status integer)

5) Implement task functions that accept the task NAME argument:
   Example skeleton:
     my_task() {
       local name="\$1"
       # mark running
       echo 1 > "\${tui_status_file[\$name]}"
       for i in {1..100}; do
         echo \$i > "\${tui_task_file[\$name]}"   # update progress
         sleep 0.05
       done
       # final status: 2 = success, 3 = fail
       echo 2 > "\${tui_status_file[\$name]}"
     }

6) Start tasks concurrently from your script:
   tui_start_task "Download" my_task
   tui_start_task "Disk Check" disk_task

   Note: tui_start_task runs the function in a background subshell.
   The function must write progress/status to the files so the parent loop can see updates.

7) Run the dashboard main loop:
   tui_loop      # updates the UI until all tasks finish

8) Cleanup:
   tui_cleanup   # restores cursor and prints newline

Important internal flow summary:
 - Registration creates file paths mapping (tui_task_file, tui_status_file).
 - Child task functions WRITE to those files (so they work across subshells).
 - tui_loop reads the files and redraws the dashboard (file-backed state is authoritative).
 - Logs printed with tui_log() are placed below the reserved dashboard region.

EOF
}
#-----------------------------------------------------------------------------




#-----------------------------------------------------------------------------
# ----------------------------
# =    SHELL DIRECT RUN CMD  =
# ----------------------------
# If this script is invoked directly (not sourced), allow simple commands:
#   ./bashdash.sh setup   -> interactive setup
#   ./bashdash.sh help    -> usage text
# This block does nothing when the file is sourced into another script.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "$1" in
        setup) tui_setup ;;
        help|--help|-h) tui_help ;;
        *) echo "Usage: $0 {setup|help}";;
    esac
fi
#-----------------------------------------------------------------------------




#-----------------------------------------------------------------------------
# End of bashdash.sh
