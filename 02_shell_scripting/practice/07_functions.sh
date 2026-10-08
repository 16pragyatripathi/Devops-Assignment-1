#!/bin/bash
# functions: no arguments, with arguments, local variables and return codes

show_info() {
  echo "This is a function"
  echo "This is a function to show information"
}

greet() {
  local person=$1
  local session=$2
  echo "Hello $person, welcome to session $session"
}

add() {
  echo $(( $1 + $2 ))
}

is_even() {
  if (( $1 % 2 == 0 )); then
    return 0
  else
    return 1
  fi
}

show_info                    # call it by name, without ()
greet "Pragya" 3
result=$(add 7 8)
echo "add 7 8 returned $result"

for num in 4 7; do
  if is_even "$num"; then
    echo "$num is even"
  else
    echo "$num is odd"
  fi
done
