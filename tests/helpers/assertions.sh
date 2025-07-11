#!/usr/bin/env bash
# Assertion library for dotfiles testing framework
# Provides various assertion functions for test validation

set -euo pipefail

# Source test utilities
source "$(dirname "${BASH_SOURCE[0]}")/test-utils.sh"

# Basic assertions

# Assert that condition is true
assert_true() {
    local condition="$1"
    local message="${2:-Assertion failed: expected true}"
    
    if ! eval "$condition"; then
        test_error "$message"
        test_debug "Condition: $condition"
        return 1
    fi
    return 0
}

# Assert that condition is false
assert_false() {
    local condition="$1"
    local message="${2:-Assertion failed: expected false}"
    
    if eval "$condition"; then
        test_error "$message"
        test_debug "Condition: $condition"
        return 1
    fi
    return 0
}

# String assertions

# Assert that two strings are equal
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed: strings not equal}"
    
    if [[ "$expected" != "$actual" ]]; then
        test_error "$message"
        test_debug "Expected: '$expected'"
        test_debug "Actual:   '$actual'"
        return 1
    fi
    return 0
}

# Assert that two strings are not equal
assert_not_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed: strings are equal}"
    
    if [[ "$expected" == "$actual" ]]; then
        test_error "$message"
        test_debug "Both values: '$expected'"
        return 1
    fi
    return 0
}

# Assert that string contains substring
assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-Assertion failed: string does not contain substring}"
    
    if [[ "$haystack" != *"$needle"* ]]; then
        test_error "$message"
        test_debug "String:    '$haystack'"
        test_debug "Substring: '$needle'"
        return 1
    fi
    return 0
}

# Assert that string does not contain substring
assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-Assertion failed: string contains substring}"
    
    if [[ "$haystack" == *"$needle"* ]]; then
        test_error "$message"
        test_debug "String:    '$haystack'"
        test_debug "Substring: '$needle'"
        return 1
    fi
    return 0
}

# Assert that string matches regex
assert_matches() {
    local string="$1"
    local pattern="$2"
    local message="${3:-Assertion failed: string does not match pattern}"
    
    if [[ ! "$string" =~ $pattern ]]; then
        test_error "$message"
        test_debug "String:  '$string'"
        test_debug "Pattern: '$pattern'"
        return 1
    fi
    return 0
}

# Assert that string does not match regex
assert_not_matches() {
    local string="$1"
    local pattern="$2"
    local message="${3:-Assertion failed: string matches pattern}"
    
    if [[ "$string" =~ $pattern ]]; then
        test_error "$message"
        test_debug "String:  '$string'"
        test_debug "Pattern: '$pattern'"
        return 1
    fi
    return 0
}

# Numeric assertions

# Assert that two numbers are equal
assert_numeric_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed: numbers not equal}"
    
    if [[ "$expected" -ne "$actual" ]]; then
        test_error "$message"
        test_debug "Expected: $expected"
        test_debug "Actual:   $actual"
        return 1
    fi
    return 0
}

# Assert that actual is greater than expected
assert_greater_than() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed: number not greater than expected}"
    
    if [[ "$actual" -le "$expected" ]]; then
        test_error "$message"
        test_debug "Expected > $expected"
        test_debug "Actual:    $actual"
        return 1
    fi
    return 0
}

# Assert that actual is less than expected
assert_less_than() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed: number not less than expected}"
    
    if [[ "$actual" -ge "$expected" ]]; then
        test_error "$message"
        test_debug "Expected < $expected"
        test_debug "Actual:    $actual"
        return 1
    fi
    return 0
}

# File system assertions

# Assert that file exists
assert_file_exists() {
    local file="$1"
    local message="${2:-Assertion failed: file does not exist}"
    
    if [[ ! -f "$file" ]]; then
        test_error "$message"
        test_debug "File: $file"
        return 1
    fi
    return 0
}

# Assert that file does not exist
assert_file_not_exists() {
    local file="$1"
    local message="${2:-Assertion failed: file exists}"
    
    if [[ -f "$file" ]]; then
        test_error "$message"
        test_debug "File: $file"
        return 1
    fi
    return 0
}

# Assert that directory exists
assert_dir_exists() {
    local dir="$1"
    local message="${2:-Assertion failed: directory does not exist}"
    
    if [[ ! -d "$dir" ]]; then
        test_error "$message"
        test_debug "Directory: $dir"
        return 1
    fi
    return 0
}

# Assert that directory does not exist
assert_dir_not_exists() {
    local dir="$1"
    local message="${2:-Assertion failed: directory exists}"
    
    if [[ -d "$dir" ]]; then
        test_error "$message"
        test_debug "Directory: $dir"
        return 1
    fi
    return 0
}

# Assert that path is a symbolic link
assert_symlink() {
    local path="$1"
    local message="${2:-Assertion failed: path is not a symbolic link}"
    
    if [[ ! -L "$path" ]]; then
        test_error "$message"
        test_debug "Path: $path"
        return 1
    fi
    return 0
}

# Assert that path is not a symbolic link
assert_not_symlink() {
    local path="$1"
    local message="${2:-Assertion failed: path is a symbolic link}"
    
    if [[ -L "$path" ]]; then
        test_error "$message"
        test_debug "Path: $path"
        return 1
    fi
    return 0
}

# Assert that symbolic link target is correct
assert_symlink_target() {
    local link="$1"
    local expected_target="$2"
    local message="${3:-Assertion failed: symbolic link target mismatch}"
    
    if [[ ! -L "$link" ]]; then
        test_error "Not a symbolic link: $link"
        return 1
    fi
    
    local actual_target
    actual_target=$(readlink "$link")
    
    if [[ "$actual_target" != "$expected_target" ]]; then
        test_error "$message"
        test_debug "Link:     $link"
        test_debug "Expected: $expected_target"
        test_debug "Actual:   $actual_target"
        return 1
    fi
    return 0
}

# Assert that file contains text
assert_file_contains() {
    local file="$1"
    local text="$2"
    local message="${3:-Assertion failed: file does not contain text}"
    
    if [[ ! -f "$file" ]]; then
        test_error "File does not exist: $file"
        return 1
    fi
    
    if ! grep -q "$text" "$file"; then
        test_error "$message"
        test_debug "File: $file"
        test_debug "Text: $text"
        return 1
    fi
    return 0
}

# Assert that file does not contain text
assert_file_not_contains() {
    local file="$1"
    local text="$2"
    local message="${3:-Assertion failed: file contains text}"
    
    if [[ ! -f "$file" ]]; then
        test_error "File does not exist: $file"
        return 1
    fi
    
    if grep -q "$text" "$file"; then
        test_error "$message"
        test_debug "File: $file"
        test_debug "Text: $text"
        return 1
    fi
    return 0
}

# Assert that file is executable
assert_executable() {
    local file="$1"
    local message="${2:-Assertion failed: file is not executable}"
    
    if [[ ! -x "$file" ]]; then
        test_error "$message"
        test_debug "File: $file"
        return 1
    fi
    return 0
}

# Command execution assertions

# Assert that command succeeds
assert_command_success() {
    local cmd=("$@")
    local message="Assertion failed: command failed"
    
    # Extract message if last argument starts with --message= or looks like a test message
    if [[ "${!#}" == --message=* ]]; then
        message="${!##--message=}"
        set -- "${@:1:$(($#-1))}"
    elif [[ $# -gt 1 && ("${!#}" == Should* || "${!#}" == *should* || "${!#}" == Test* || "${!#}" == *test*) ]]; then
        # If last argument looks like a test message
        message="${!#}"
        set -- "${@:1:$(($#-1))}"
    fi
    
    cmd=("$@")
    if ! "${cmd[@]}" >/dev/null 2>&1; then
        test_error "$message"
        test_debug "Command: ${cmd[*]}"
        return 1
    fi
    return 0
}

# Assert that command fails
assert_command_failure() {
    local cmd=("$@")
    local message="Assertion failed: command succeeded"
    
    # Extract message if last argument starts with --message= or looks like a test message
    if [[ "${!#}" == --message=* ]]; then
        message="${!##--message=}"
        set -- "${@:1:$(($#-1))}"
    elif [[ $# -gt 1 && ("${!#}" == Should* || "${!#}" == *should* || "${!#}" == Test* || "${!#}" == *test*) ]]; then
        # If last argument looks like a test message
        message="${!#}"
        set -- "${@:1:$(($#-1))}"
    fi
    
    cmd=("$@")
    if "${cmd[@]}" >/dev/null 2>&1; then
        test_error "$message"
        test_debug "Command: ${cmd[*]}"
        return 1
    fi
    return 0
}

# Assert that command output contains text
assert_command_output_contains() {
    local text="$1"
    shift
    local cmd=("$@")
    local message="Assertion failed: command output does not contain text"
    
    # Extract message if last argument starts with --message=
    if [[ "${!#}" == --message=* ]]; then
        message="${!##--message=}"
        set -- "${@:1:$(($#-1))}"
        cmd=("${@:2}")
    fi
    
    local output
    output=$("${cmd[@]}" 2>&1)
    
    if [[ "$output" != *"$text"* ]]; then
        test_error "$message"
        test_debug "Command: ${cmd[*]}"
        test_debug "Expected text: $text"
        test_debug "Output: $output"
        return 1
    fi
    return 0
}

# Process assertions

# Assert that process is running
assert_process_running() {
    local process_name="$1"
    local message="${2:-Assertion failed: process is not running}"
    
    if ! pgrep -f "$process_name" >/dev/null; then
        test_error "$message"
        test_debug "Process: $process_name"
        return 1
    fi
    return 0
}

# Assert that process is not running
assert_process_not_running() {
    local process_name="$1"
    local message="${2:-Assertion failed: process is running}"
    
    if pgrep -f "$process_name" >/dev/null; then
        test_error "$message"
        test_debug "Process: $process_name"
        return 1
    fi
    return 0
}

# Environment assertions

# Assert that environment variable is set
assert_env_set() {
    local var_name="$1"
    local message="${2:-Assertion failed: environment variable is not set}"
    
    if [[ -z "${!var_name:-}" ]]; then
        test_error "$message"
        test_debug "Variable: $var_name"
        return 1
    fi
    return 0
}

# Assert that environment variable is not set
assert_env_not_set() {
    local var_name="$1"
    local message="${2:-Assertion failed: environment variable is set}"
    
    if [[ -n "${!var_name:-}" ]]; then
        test_error "$message"
        test_debug "Variable: $var_name"
        test_debug "Value: ${!var_name}"
        return 1
    fi
    return 0
}

# Assert that environment variable has specific value
assert_env_equals() {
    local var_name="$1"
    local expected="$2"
    local message="${3:-Assertion failed: environment variable value mismatch}"
    
    local actual="${!var_name:-}"
    if [[ "$actual" != "$expected" ]]; then
        test_error "$message"
        test_debug "Variable: $var_name"
        test_debug "Expected: $expected"
        test_debug "Actual:   $actual"
        return 1
    fi
    return 0
} 