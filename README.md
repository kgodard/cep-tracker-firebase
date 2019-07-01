# cep-tracker-firebase

## Installation
* `git clone git@github.comverge.com:kgodard/cep-tracker-firebase.git`
* `cd cep-tracker-firebase`
* `./ctf-setup.sh`
* follow instructions

## Usage
Easy-style: Type `ctf`. Follow the prompts.

If you want to specify some or all of these options rather than being
prompted, you can. Run `ctf -h` for details.

To specify a timestamp other than __now__, use the `-d` option. Example:

`ctf -t 123456789 -d '2016-03-17 16:20:00'`

## How to use
We want to track the time between the start of development and the start of QA testing.
So generally the flow is:
* drag the story to the **Development** column
* write the code
* create the PR
* merge
* drag the story to the **Ready for Demo** column
* do the stakeholder demo
* drag the story to the **QA** column

So that's when we want to register the __finish__ event -- when we actually drag the story to the QA column.

### Stopping/starting events
If your story gets _blocked_ for some reason, you want to register a __block__ event. When it becomes un-blocked, register a __resume__ event.

If you need to _stop_ your story for some reason (i.e. you need to put it down because another story just became a super-high priority), register a __stop__ event.
When you begin on it again, register a __resume__.

(Stop is meant to be a generic event for when we're not _blocked_, but we still have to stop working on the story for some reason.)

### Reject events
Reject events are not meant for the time between start and finish. When you've finished a story, but it gets _rejected_ by QA, you want to register a __reject__ event for it.
This allows us to track our "rejection rate".

If you _re-start_ a rejected story, register a __restart__ event for it.

## Feedback
If you have questions, comments, concerns, let me know -- this thing is really an experiment, and it's definitely a work in progress.

## Contributions 
Feel free to add enhancements and/or fix bugs in __CTF__ -- just let everyone know if you want to add a feature so that we can generally agree on it,
and let everyone know when you've pushed up changes to the master branch so we can `git pull`!

## Smoke tests
- start: can only register a start for first event, cannot do following any event
- assigns points from ADS to event if start
- start, stop, resume, block, resume, finish, reject, restart, finish
- find, since, -z, comment, open
- sprint end with/without filters

