#!/bin/bash
# create a directory and a file, then compare > and >>

mkdir -p data1
cd data1 || exit 1

echo "This is a log file." > app.log
echo "--- after first > ---"
cat app.log

echo "This is my file" > app.log
echo "--- after second > (old line is gone) ---"
cat app.log

echo "this is line 2" >> app.log
echo "this is line 3" >> app.log
echo "--- after two >> (lines are added) ---"
cat app.log

# 2> sends errors to a separate file
ls /no/such/folder 2> error.log
echo "--- error.log ---"
cat error.log

# date and process list into one file
date > process.log
ps >> process.log
echo "--- process.log ---"
cat process.log
