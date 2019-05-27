#!/bin/bash

echo
echo checking for CTF_DIR environment var...
echo

if [[ $(echo $CTF_DIR) ]]; then
  echo ">> CTF_DIR exists."
else
  echo ERROR: We need to add this line to your ~/.bash_profile:
  echo
  echo "export CTF_DIR=$PWD"
  echo
  read -n 1 -s -r -p "Press any key to continue"
  echo "export CTF_DIR=$PWD" >> ~/.bash_profile
  echo
  echo Env var added. Reloading profile...
  source ~/.bash_profile
fi

echo
echo checking for rbenv...
echo

if [[ $(which rbenv) ]]; then
  echo ">> rbenv is installed!"
else
  echo ERROR: CTF requires rbenv in order to support required ruby version
  echo "(brew install rbenv)"
  exit 1
fi

echo
echo checking for ruby 2.5.5...
echo

if [[ $(rbenv versions | grep 2.5.5) ]]; then
  echo ">> Ruby version 2.5.5 available."
else
  echo ERROR: CTF requires ruby version 2.5.5.
  echo Please use rbenv to install it and re-run this script.
  echo "(rbenv install 2.5.5)"
  exit 1
fi

echo
echo checking bundler installation...
echo

cd $CTF_DIR

if [[ $(gem list bundler | grep bundler) ]]; then
  echo ">> Bundler installed."
else
  echo Installing bundler...
  gem install bundler -v2.0.1
fi

echo
echo Installing gems...
echo

cd $CTF_DIR && bundle install

echo
echo Checking for ctf_settings.yml...
echo

if [ -f "$CTF_DIR/ctf_settings.yml" ]; then
  echo ">> ctf_settings.yml exists."
  echo
  echo Your settings:
  cat $CTF_DIR/ctf_settings.yml
else
  echo "ctf_settings.yml was not found. You will need to fill in required values."
  echo
  read -n 1 -s -r -p "Press any key to continue"
  cp $CTF_DIR/ctf_settings.yml{.example,}
  $EDITOR $CTF_DIR/ctf_settings.yml
fi

echo
echo Checking for ctf launcher file...
echo

if [ -f "/usr/local/bin/ctf" ]; then
  echo ">> /usr/local/bin/ctf exists, you're all set!"
  echo
  echo ">> type 'ctf -h' for options"
  echo
else
  echo Copying the ctf launcher to /usr/local/bin...
  cp $CTF_DIR/bin/ctf /usr/local/bin
  echo
  echo Done! Please enjoy ctf tracker responsibly.
  echo
  echo ">> type 'ctf -h' for options"
  echo
fi
