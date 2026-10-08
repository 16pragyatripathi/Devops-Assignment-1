#!/bin/bash
# if / elif / else with numbers, strings and files

read -p "Enter your age: " age

# a non-number would break the -lt test, so check it first
if ! [[ $age =~ ^-?[0-9]+$ ]]; then
    echo "'$age' is not a number."
    exit 1
fi

if [ "$age" -lt 0 ]; then
    echo "Invalid age. Please enter a valid age."
elif [ "$age" -lt 13 ]; then
    echo "You are a child."
elif [ "$age" -lt 20 ]; then
    echo "You are a teenager."
else
    echo "You are an adult."
fi

# string comparison
user=$(whoami)
if [ "$user" == "root" ]; then
    echo "Running as root"
else
    echo "Running as a normal user ($user)"
fi

# file tests
if [ -f /etc/os-release ]; then
    echo "/etc/os-release exists (it is a regular file)"
fi
if [ -d /work ]; then
    echo "/work is a directory"
fi
if [ ! -e /tmp/does-not-exist.txt ]; then
    echo "/tmp/does-not-exist.txt does not exist"
fi
