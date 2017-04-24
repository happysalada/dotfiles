#!/bin/sh
#
# ruby
#
# This installs a default version of ruby for you

# Check for Ruby already installed
ruby_version=2.3.3

if [ ! -d "$HOME/.rbenv/versions/$ruby_version" ]; then
  echo "› rbenv install $ruby_version"
  rbenv install "$ruby_version"
  echo "› rbenv global $ruby_version"
  rbenv global "$ruby_version"
else
  echo "› ruby $ruby_version already installed."
fi

exit 0
