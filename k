#   -*-  grammar-ext: sh  -*-

echo "killing all hvac(1&2) apps"
kill $(pgrep -f "hvac") 2> /dev/null
