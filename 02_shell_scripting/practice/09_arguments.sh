#!/bin/bash
# positional arguments and exit status

echo "Script name : $0"
echo "First arg   : $1"
echo "Second arg  : $2"
echo "Number of args: $#"
echo "All args    : $@"

if [ $# -lt 2 ]; then
    echo "Usage: $0 <name> <roll_no>"
    exit 2
fi

echo "Hello $1 ($2)"
exit 0
