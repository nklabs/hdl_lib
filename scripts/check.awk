# Simple awk script that passed input to output, but sets
# execution return value to true if any of the data contains
# the phrase "Test passed".
BEGIN { err = 1 }
/Test passed/ { err = 0 }
// { print }
END { exit err }
