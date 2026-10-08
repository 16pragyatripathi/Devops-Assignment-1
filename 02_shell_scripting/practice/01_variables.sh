#!/bin/bash
# Variables: plain values, command substitution and environment variables

greeting="Hello, DevOps!"
name="Pragya Tripathi"
roll_no="24BCS10032"
course="DevOps"

echo "$greeting"
echo "My name is $name"
echo "My roll number is $roll_no"
echo "Course: ${course} - session 3 (shell scripting)"

# store the output of a command inside a variable
today=$(date +%d-%m-%Y)
files_here=$(ls | wc -l)
echo "Today is $today and this folder has $files_here files"

# variables the shell already knows
echo "Logged in as $(whoami), home is $HOME, bash version is $BASH_VERSION"

# arithmetic
a=12
b=5
echo "a + b = $((a + b))"
echo "a * b = $((a * b))"
echo "a / b = $((a / b)) (integer division)"
