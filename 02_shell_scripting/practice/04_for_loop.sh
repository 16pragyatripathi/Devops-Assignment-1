#!/bin/bash
# for loops: over a range, over a list and over files

for i in {1..5}
do
  echo "This is iteration number $i"
done

for tool in git docker kubectl terraform
do
  echo "Tool to learn: $tool"
done

# C style loop
for (( n=2; n<=10; n+=4 ))
do
  echo "n = $n"
done

# loop over the scripts in this folder
for file in *.sh
do
  echo "$file has $(wc -l < "$file") lines"
done
