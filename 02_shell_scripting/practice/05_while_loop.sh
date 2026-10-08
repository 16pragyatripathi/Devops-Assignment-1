#!/bin/bash
# while loop with a counter

count=0
while [ $count -lt 5 ]
do
  echo "This is iteration number $count"
  ((count++))
done
echo "Loop ended, count is now $count"
