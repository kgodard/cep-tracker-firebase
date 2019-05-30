#!/bin/bash

echo
echo checking for CTF_DIR environment var...
echo

if [[ -z "$CTF_DIR" ]]; then
  echo We need to add this line to your ~/.bash_profile:
  echo
  echo "export CTF_DIR=$PWD"
  echo
  read -p "Type 'y' to append the line to your ~/.bash_profile " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]
  then
    echo
    echo Please add the export line above to your preferred login profile script,
    echo launch a new terminal window or source your updated script,
    echo and re-run ./ctf-setup.sh
    exit 1
  fi
  echo "export CTF_DIR=$PWD" >> ${HOME}/.bash_profile
  echo
  echo ">> CTF_DIR env var was added to your .bash_profile."
else
  echo ">> CTF_DIR is set"
fi

export CTF_DIR=$PWD

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
echo Copying ctf launcher file...
echo

if [[ $(echo $PATH | grep /usr/local/bin) ]]; then
  cp $CTF_DIR/bin/ctf /usr/local/bin
  echo Done! Please enjoy ctf tracker responsibly.
  echo
  echo ">> type 'ctf -h' for options"
else
  echo "You don't seem to have /usr/local/bin in your path."
  echo "You will need to copy /bin/ctf to a directory in your"
  echo "PATH manually before using ctf."
fi
echo
echo NOTE: If this is your first time running setup,
echo you may need to: source ~/.bash_profile or
echo launch a new terminal window.
echo
