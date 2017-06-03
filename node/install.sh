if test ! $(which spoof)
then
  sudo npm install spoof -g
fi

if test ! $(which babel)
then
  sudo npm install babel-cli -g
fi