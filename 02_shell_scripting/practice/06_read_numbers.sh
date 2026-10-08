#!/bin/bash
# keep reading numbers until the user types q (break and continue)

total=0
while true; do
    read -p "Enter a number (or 'q' to quit): " input

    if [[ $input == "q" ]]; then
        echo "Exiting the loop."
        break
    elif ! [[ $input =~ ^[0-9]+$ ]]; then
        echo "Invalid input. Please enter a valid number."
        continue
    fi

    echo "You entered: $input"
    total=$((total + input))
done
echo "Sum of the valid numbers: $total"
