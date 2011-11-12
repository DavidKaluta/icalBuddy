

------------

## Q: How do I install/uninstall icalBuddy?

The distribution archive (i.e. the `zip` package) comes with scripts for installing and uninstalling (called `install.command` and `uninstall.command`, respectively). You can run these by double-clicking on them in the Finder, or in the normal fashion from the Terminal (they're scripts).


## Q: I don't want to install icalBuddy under `/usr/local`. How do I install it somewhere else?

When you run the `install.command` script, choose the `c` option ("change installation path") and then type in the new *prefix*. (If you don't get this choice in the installer, download the latest release of icalBuddy and try that.)

This __prefix__ is the path under which the icalBuddy executable and its manual pages are installed. The executable is installed in a folder called `bin` and the manual pages under `share/man/man1`. The default prefix is `/usr/local`.

If you want to install icalBuddy __under your home folder__, I suggest setting the prefix to `~/local`. With this prefix, the executable would be `~/local/bin/icalBuddy` and the manual pages would be located in `~/local/share/man/man1`.

After installation into a custom location you should make sure that these locations are included in your `PATH` and `MANPATH` environment variables. You can add them there by adding lines such as the following into your [shell configuration file][wp-bashstartup] (e.g. `~/.bashrc`):

    export PATH=${PATH}:/Users/username/local/bin
    export MANPATH=${MANPATH}:/Users/username/local/share/man


## Q: Does icalBuddy have a manual? If so, where is it?

Yes indeed: icalBuddy, like most other Unix-type command line applications, has something called a [man page][wp-manpages]. You can read it by typing `man icalBuddy` into the terminal or by opening the PDF file that was included in the distribution archive you downloaded. The man page for the *latest version* of icalBuddy is also [available online][manpageonline].


## Q: The output of my calendar items is garbled! What gives?

icalBuddy uses unicode (UTF-8) string encoding by default in its output, so make sure that the application you're using to invoke it understands UTF-8. If there's a mismatch between the string encoding icalBuddy uses for its output and the string encoding an application uses to read that output, some special characters (like umlauts, chinese or arabic) might not display correctly.

You can turn on UTF-8 encoding in **Apple's Terminal.app** from *preferences > settings > (whichever style you're using) > advanced > international > character encoding*. In **iTerm** this can be done from *"Bookmarks" menu > manage profiles... > terminal profiles > (whichever profile you're using, probably "default") > encoding*. Older versions (before v.3) of **[GeekTool][geektool]** didn't understand UTF-8 by default, so you should update it if you're still using one of those.

You can also use the `--strEncoding` argument to make icalBuddy output using some other string encoding. Run `icalBuddy strEncodings` to see all the possible values you can use for that argument.


## Q: I can't seem to be able to call icalBuddy (either via the terminal on some other program, like GeekTool). What should I do?

The most common problem is that the directory where icalBuddy resides (`/usr/local/bin` by default) is not in your `PATH` [environment variable][wp-envvars]. There are two ways to solve this:

 1. Call icalBuddy using the absolute path, like this: `/usr/local/bin/icalBuddy <arguments>`
 2. Add icalBuddy's location permanently into your shell configuration file. The default shell on OS X is Bash &mdash; see [Wikipedia's Bash entry][wp-bashstartup] for info on where to find these configuration files and when they are used. The command you need to add to one of these files is something like this (this example adds `/usr/local/bin` to the `PATH` environment variable): `export PATH=$PATH:/usr/local/bin`

It's important to note that *GeekTool doesn't run these shell configuration files at all* so in order to use icalBuddy there you'll need to either **use the absolute path** (as described in step #1 above) or **execute the shell configuration file yourself** in your GeekTool command, like this:

    source ~/.bashrc;
    icalBuddy <arguments>


## Q: How can I hide URLs (or any other fields/properties) for events or tasks?

You can use any of the following arguments:

	-eep (or --excludeEventProps): Exclude specified event properties
	-etp (or --excludeTaskProps):  Exclude specified task properties
	-iep (or --includeEventProps): Include only specified event properties
	-itp (or --includeTaskProps):  Include only specified task properties

See the [manual](man.html) for more information on these arguments.

If you only want to **exclude one field/property, like URLs**, use `-eep` or `-etp`. So for example, to exclude URLs:

	icalBuddy -eep url eventsToday+2


## Q: How can I get icalBuddy to display times according to a 12-hour clock?

Since version 1.7.9, icalBuddy uses the system standard date and time formats (unless custom formats are specified like in the examples below). If you're using an older version and the date and time formats in your System Preferences are set to your liking, you can simply update icalBuddy.

You can use the `-tf` (or `--timeFormat`) argument to specify the format in which to display times. For example, `icalBuddy -tf "%1I:%M %p" eventsToday` would display times such as `5:00 PM`. See [Apple's documentation][datetimeformats] for all the possible values you can use for date and time formatting (there's also the `-df` (or `--dateFormat`) argument for date formatting, which works similarly to this one.)


## Q: I would like icalBuddy to speak my language instead of just english. Can it be localized?

As of version 1.5.0, it can be. There are some ready-made localization files under the `exampleLocalizationFiles` directory in the distribution archive. You can take them into use by __copying them under your home folder with the name `.icalBuddyLocalization.plist`__. So for example:

    $ cd path/where/i/unzipped/the/archive
    $ cp exampleLocalizationFiles/french-icalBuddyLocalization.plist ~/.icalBuddyLocalization.plist

If you want to translate icalBuddy into your language, read the [localization man page][l10nmanpageonline] for documentation on how to do this. If you think you have managed to write a nice general localization file for your language, please [contact me][hassegcontact] and I'll include it into the distribution package so that others who'd like to use a localized icalBuddy in your language wouldn't have to redo that work.


## Q: How can I change the bullet points used in the output? We don't like them asterisks/bullet point symbols around these here parts.

You can use the `-b` (or `--bullet`) argument to change the normal bullet point value (`"• "` by default) and `-ab` (or `--alertBullet`) to change the alert bullet point value (`"! "` by default, used for tasks that are late from their due date.) See [the manual page][manpageonline] for more info.


## Q: Newlines (`"\n"`) and/or other escape sequences I'm adding to argument values don't seem to be interpreted correctly. How do I fix this?

Versions of icalBuddy earlier than 1.6.19 don't interpret escape sequences such as `\n` in the argument values. The easiest way to fix this is to __update icalBuddy__, but if you for some reason don't want to do that, in the (I assume most common) case of the newline you simply need to input an *actual newline* into the argument value, like this:

    icalBuddy -b "
    - " <other_arguments>


## Q: How can I keep all (or some) event/task properties on the same line?

You can use the `-ps` (or `--propertySeparators`) argument to specify the strings to use between the properties that get printed out. An example:

    $ icalBuddy eventsToday+2
    • An Event (Work)
        location: Meeting room A
        tomorrow at 13:00 - 14:15
    $
    $ icalBuddy -ps "| / | -- |" eventsToday+2
    • An Event (Work) / location: Meeting room A -- tomorrow at 13:00 - 14:15


## Q: How can I keep all of the events/tasks in a section (e.g. a single day if separating by date, or a single calendar if separating by calendar) on the same line?

icalBuddy doesn't support this out of the box, but it's possible to do with some shell trickery and regular expression magic.

First you need to make sure that the properties of events/tasks are kept on the same line (see the previous question). Then we'll just specify a reasonably unique custom bullet point and use a small Perl script to replace all occurrences of a newline followed by an arbitrary number of ANSI escape sequences and our custom bullet point with whatever separator we want to show between different events/tasks (in the following example the separator is the bullet point symbol `•`):

    $ icalBuddy -sd -ps "|, |" -ss "\n-------------------------\n" -b "••BULLET•• " eventsToday+20 | perl -e 'while($s = <STDIN>) { $x .= $s; }; $x =~ s/\n((?:\e\[[0-9;]*m)*)••BULLET••/$1 •/sg; print $x;'
    
    tomorrow:
    -------------------------
     • LOST Premiere (Movie premieres etc.), notes: Kickass! • Archery practice (Hobbies), location: Anchorage, 14:00 • Cooking class (Hobbies), location: Amsterdam, 19:30
    
    day after tomorrow:
    -------------------------
     • Knitting practice (Hobbies), location: Paris, 14:00 • Cooking class (Hobbies), location: Boston, 11:30

Here is another example of a more terse listing where we only show the titles of events (as you can see, this requires some more regex magic and icalBuddy argument trickery as well as stripping of empty lines with grep):

    $ icalBuddy -sd -iep "title" -nc -ss "••SECTION••" -b "••BULLET••" eventsToday+20 | perl -e 'while($s = <STDIN>) { $x .= $s; }; $x =~ s/••SECTION••\n((?:\e\[[0-9;]*m)*)••BULLET••/$1 /sg; $x =~ s/\n((?:\e\[[0-9;]*m)*)••BULLET••/$1, /sg; print $x;' | grep -v "^[[:space:]]*$"
    
    tomorrow: LOST Premiere, Archery practice, Cooking class
    day after tomorrow: Knitting practice, Cooking class



## Q: Can I get the output in CSV/(La)TeX/XML/whatever format?

Not really &mdash; this is not supported. If you want to get events or tasks from your calendars and format them in some custom way, I suggest you take a look at [CalStoreHelper][calstorehelper], a Python class that lets you easily get events/tasks from the calendar store, and write a small script that performs the formatting you want (take a look at the example script provided with the class).



## Q: How can I automatically get events for a single day (or any date/time range, for that matter) that is *relative to the current date* (e.g. yesterday, tomorrow or the day after tomorrow)?

As of version 1.7.13 you can specify relative dates such as these in the arguments. The following relative dates are supported: `day before yesterday`, `yesterday`, `today`, `now`, `tomorrow` and `day after tomorrow`. You can also specify a 'day shift' (i.e. number of days to add to or remove from) for these relative dates by adding `+NUM` or `-NUM` to the end.

Example: get events for tomorrow:

    icalBuddy eventsFrom:tomorrow to:tomorrow

Example: get events for tomorrow and the day after tomorrow:

    icalBuddy eventsFrom:tomorrow to:'day after tomorrow'

If your requirements are more specific (for example, you want more accuracy than a single day), you can specify dates accurately by using the `YYYY-MM-DD HH:MM:SS ±HHMM` format (and icalBuddy shouldn't mess with them if they are specified that way). This means that you can write little scripts to determine relative datetimes yourself and then pass them to icalBuddy in the above format. Below is an example that should be a good starting point:

    #!/bin/bash
    # 
    # Prints events from (now) to (12h from now) via icalBuddy
    # 
    
    minute_in_seconds=60
    hour_in_seconds=3600
    
    # Get current seconds since the epoch:
    sec_now=`date +%s`
    
    # Calculate seconds since the epoch for our desired start and
    # end datetimes:
    sec_start="${sec_now}"
    sec_end=$(echo "${sec_now} + (${hour_in_seconds} * 12)" | bc)
    
    # Convert our start and end datetimes into the format required
    # by icalBuddy:
    start_dt=$(date -r ${sec_start} +'%Y-%m-%d %H:%M:%S %z')
    end_dt=$(date -r ${sec_end} +'%Y-%m-%d %H:%M:%S %z')
    
    # Use the -d argument to see how icalBuddy has interpreted the input.
    # When you have verified that this script is working correctly, you
    # can remove the argument.
    /usr/local/bin/icalBuddy -d eventsFrom:"${start_dt}" to:"${end_dt}"


## Q: For some of my calendar items the bullet point is displayed on the right side of the line instead of on the left side, like it's supposed to. Why is this?

The calendar items in question probably have text in a language that's written from right to left? The Mac OS X text layout system sees this and automatically "flips" the line, putting the bullet point (which was supposed to be at the far left side of the line) to the far right. There are two workarounds I've come up with, depending on the application you're using to invoke icalBuddy:

 1. If the application you're using to call icalBuddy allows you to set the "writing direction" for the printed output, set that to something other than "natural" (in Geektool 3 this setting is called *right to left text direction*).
 2. If the application you're using to call icalBuddy *does not* allow you to set the "writing direction", you can try to "trick" the layout system to keep the bullets on the left side by adding a letter from the latin alphabet as a part of the bullet point. Unfortunately this is not very pretty, though. :( So for example: `icalBuddy -b "I- "`. You can also omit the bullet points completely by running: `icalBuddy -b "" -ab ""`, but this won't keep the lines from being "flipped".


## Q: Why doesn't icalBuddy display events from calendars I see under the "Delegates" heading in iCal's calendar list?

icalBuddy uses OS X's CalendarStore API to access the calendar data. The CalDAV accounts (which is what a lot of people use to sync their Google Calendar account with iCal) are a feature of the iCal application, not the operating system itself, which is why the CalendarStore API won't return information about those calendars to icalBuddy. Nevertheless, I will try to see if I could get this feature working in the future using some other way.

**Current workaround:** Note that as opposed to delegate calendars, *subscribed calendars are visible to icalBuddy*, so if you want events from your Google Calendar calendars to be visible in icalBuddy, one trick to do it is to add a subscription to that calendar's feed into iCal (please refer to [Google's documentation][gcal-feeds] for help on how to do it). If you're using CalDAV to sync your Google Calendar account with iCal and also add subscriptions to some of those calendars in order to get them to show up in icalBuddy's output, remember to uncheck the visibility checkboxes of these subscription calendars in iCal &mdash; otherwise their events would be shown twice there (once for the CalDAV "delegate" calendar entry and once for the calendar subscription). Also remember to set the *auto-refresh* value sufficiently high for the subscribed calendars.

**My personal suggestion:** I use BusyMac's [BusyCal][busycal] application to synchronize my local Mac calendar with Google Calendar, and thus don't suffer from this problem at all. I am happy to recommend BusyCal to everyone; I prefer it to iCal.


## Q: The question I had in mind is not answered here. What should I do?

You should look through icalBuddy's [manual page][manpageonline] and see if what you're looking for is documented there. Just type `man icalBuddy` into the terminal to see it. If what you're looking for is not in the manual, you can [contact the me, the author][hassegcontact].





[wp-manpages]:          http://en.wikipedia.org/wiki/Manual_page_(Unix)
[wp-envvars]:           http://en.wikipedia.org/wiki/Environment_variable
[wp-bashstartup]:       http://en.wikipedia.org/wiki/Bash_(Unix_shell)#Startup_scripts
[manpageonline]:        http://hasseg.org/icalBuddy/man.html
[l10nmanpageonline]:    http://hasseg.org/icalBuddy/localization-man.html
[geektool]:             http://projects.tynsoe.org/en/geektool
[custom-geektool]:      http://hasseg.org/blog/?p=350
[datetimeformats]:      http://developer.apple.com/mac/library/documentation/Cocoa/Conceptual/DataFormatting/Articles/df100103.html#//apple_ref/doc/uid/TP40007972-SW10
[hassegcontact]:        http://hasseg.org/
[links]:                http://links.sourceforge.net/
[gcal-feeds]:           http://www.google.com/support/calendar/bin/answer.py?hl=en&answer=37648
[busycal]:              http://busymac.com/
[calstorehelper]:    http://hasseg.org/calStoreHelper/


