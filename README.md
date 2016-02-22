# cep-tracker-firebase

## Installation
* `bundle install`
* `cp my_settings.yml.example my_settings.yml`
* Add your name to the `my_settings.yml`
* `chmod +x ctf.rb`
* `bundle exec rake ctf_symlink`
* `ctf -h` for options

## Usage
Type `ctf`. You will be prompted for the tracker story Id, the type of
event you wish to save, and a 'reason' (if needed).

If you want to specify some or all of these options rather than being
prompted, you can. Run `ctf -h` for details.

To specify a timestamp other than __now__, use the `-d` option. Example:

`ctf -t 123456789 -d '2016-03-17 16:20:00'`
