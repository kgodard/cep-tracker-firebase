#!/bin/bash

export CTF_DIR=$PWD

echo
echo checking for CTF_DIR environment var...
echo

if [[ $(grep CTF_DIR ${HOME}/.bash_profile) ]]; then
  echo ">> CTF_DIR is set in .bash_profile"
else
  echo We need to add this line to your ~/.bash_profile:
  echo
  echo "export CTF_DIR=$PWD"
  echo
  read -n 1 -s -r -p "Press any key to add it..."
  echo "export CTF_DIR=$PWD" >> ${HOME}/.bash_profile
  echo
  echo ">> CTF_DIR env var was added to your .bash_profile."
fi

echo
echo checking for ruby 2.6.3...
echo

cd $CTF_DIR

if [[ $(ruby -v | grep 2.6.3) ]]; then
  echo ">> Ruby version 2.6.3 available."
else
  echo ERROR: CTF requires ruby version 2.6.3.
  echo Please use your preferred version manager to install it and re-run this script.
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
  echo "First, fill in your name."
  echo "Next, fill in the firebase_uri and the firebase_secret."
  echo "Those values can be found here: https://github.comverge.com/software/env-dev/tree/master/cep-tracker-firebase"
  echo
  read -n 1 -s -r -p "Press any key to edit your ctf_settings.yml file"
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
