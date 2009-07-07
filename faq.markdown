
icalBuddy FAQ
=====================

------------

### Q: Does icalBuddy have a manual? If so, where is it?

Yes indeed: icalBuddy, like most other Unix-type command line applications, has something called a [man page][wp-manpages]. You can read it by typing `man icalBuddy` into the terminal, and the man page for the latest version of icalBuddy is also [available online][manpageonline]. If you'd prefer to use a dedicated application for reading manual pages in normal GUI windows, see the TUAW post ["Here comes your man (viewer)"][tuawmanviewers].


### Q: The output of my calendar items is garbled! What gives?

icalBuddy uses unicode (UTF-8) string encoding by default in its output, so make sure that the application you're using to invoke it understands UTF-8. If there's a mismatch between the string encoding icalBuddy uses for its output and the string encoding an application uses to read that output, some special characters (like umlauts, chinese or arabic) might not display correctly.

You can turn on UTF-8 encoding in **Apple's Terminal.app** from *preferences > settings > (whichever style you're using) > advanced > international > character encoding*. In **iTerm** this can be done from *"Bookmarks" menu > manage profiles... > terminal profiles > (whichever profile you're using, probably "default") > encoding*. **[GeekTool][geektool]** doesn't understand UTF-8 by default, but you can install [my custom build of it][custom-geektool] that does.

You can also use the `--strEncoding` argument to make icalBuddy output using some other string encoding. Run `icalBuddy strEncodings` to see all the possible values you can use for that argument.


### Q: I can't seem to be able to call icalBuddy (either via the terminal on some other program, like GeekTool). What should I do?

The most common problem is that the directory where icalBuddy resides (`/usr/local/bin` by default) is not in your `PATH` [environment variable][wp-envvars]. There are two ways to solve this:

 1. Call icalBuddy using the absolute path, like this: `/usr/local/bin/icalBuddy <arguments>`
 2. Add icalBuddy's location permanently into your shell configuration file. The default shell on OS X is Bash &mdash; see [Wikipedia's Bash entry][wp-bashstartup] for info on where to find these configuration files and when they are used. The command you need to add to one of these files is something like this (this example adds `/usr/local/bin` to the `PATH` environment variable): `export PATH=$PATH:/usr/local/bin`

It's important to note that *GeekTool doesn't run these shell configuration files at all* so in order to use icalBuddy there you'll need to either **use the absolute path** (as described in step #1 above) or **execute the shell configuration file yourself** in your GeekTool command, like this:

    source ~/.bashrc;
    icalBuddy <arguments>


### Q: How can I get icalBuddy to display times according to a 12-hour clock?

You can use the `-tf` (or `--timeFormat`) argument to specify the format in which to display times. For example, `icalBuddy -tf "%1I:%M %p" eventsToday` would display times such as `5:00 PM`. See [Apple's documentation][datetimeformats] for all the possible values you can use for date and time formatting (there's also the `-df` (or `--dateFormat`) argument for date formatting, which works similarly to this one.)


### Q: I would like icalBuddy to speak my language instead of just english. Can it be localized?

As of version 1.5.0, it can be. Read the [localization man page][l10nmanpageonline] for documentation on how to do this. If you think you have managed to write a nice general localization file for your language, please [contact me][hassegcontact] and I'll include it into the distribution package so that others who'd like to use a localized icalBuddy in your language wouldn't have to redo that work.


### Q: How can I change the bullet points used in the output? We don't like them asterisks around these here parts.

You can use the `-b` (or `--bullet`) argument to change the normal bullet point value (`"* "` by default) and `-ab` (or `--alertBullet`) to change the alert bullet point value (`"! "` by default, used for tasks that are late from their due date.) Also note that you can change indenting for non-bulleted lines with the `-i` (or `--indent`) argument. See [the manual page][manpageonline] for more info.


### Q: How can I keep all (or some) event/task properties on the same line?

You can use the `-ps` (or `--propertySeparators`) argument to specify the strings to use between the properties that get printed out. An example:

    $ icalBuddy eventsToday+2
    * An Event (Work)
        location: Meeting room A
        tomorrow at 13:00 - 14:15
    $
    $ icalBuddy -ps "| / | -- |" eventsToday+2
    * An Event (Work) / Meeting room A -- tomorrow at 13:00 - 14:15


### Q: Can I get the output in CSV format?

Not really &mdash; this is not supported. If you'd still like to try, you could achieve some kind of a result with something like this:

    $ icalBuddy eventsToday+2
    * An Event (Work)
        location: Meeting room A
        13:00 - 14:15
    * Second Event (Work)
        location: Meeting room B
        tomorrow at 11:00 - 12:00
    $
    $ icalBuddy -cf "" -b '"' -ab '"' -ps '|","|' eventsToday+20 | sed -e "s/$/\"/"
    "An Event (Work)","location: Meeting room A","13:00 - 14:15"
    "Second Event (Work)","location: Meeting room B","tomorrow at 11:00 - 12:00"

When trying this out, note that properties that have no value are not printed out by icalBuddy, so *the column order will not be consistent* in this CSV output unless all printed items have values for all of the same printed properties. Also, double quotes (`"`) in property values will mess things up completely.


### Q: How can I automatically get events for a single day (or any date/time range, for that matter) that is *relative to the current date* (e.g. yesterday, tomorrow or the day after tomorrow)?

You should write a shell script that dynamically determines the start and end date-times and call that. Here's an example of a bash script that will get you events only from tomorrow:

    #!/bin/bash
    # 
    # Prints tomorrow's events using icalBuddy
    # 
    
    day_in_seconds=86400
    
    # get current seconds since the epoch
    sec=`date +%s`
    
    # get tomorrows date as seconds since the epoch
    sec_tomorrow=`expr ${sec} + ${day_in_seconds}`
    
    # 'start' date/time, in the format required by icalBuddy
    start_dt="`date -r ${sec_tomorrow} +'%Y-%m-%d 00:00:00 %z'`"
    
    # 'end' date/time, in the format required by icalBuddy
    end_dt="`date -r ${sec_tomorrow} +'%Y-%m-%d 23:59:59 %z'`"
    
    icalBuddy eventsFrom:"${start_dt}" to:"${end_dt}"


### Q: When I try to go through the automatic update procedure via the command line, after selecting the "a" option when icalBuddy tries to download a list of changes from the server, I get a "connection refused" message. What might be the problem?

icalBuddy uses the text-based [links][links] web browser to download the list of changes from the server and format them to a nice text representation. This problem might occur if you're using a HTTP proxy that links doesn't know about. Do the following to configure the correct proxies for links:

 1. Open links (just type `links` into the Terminal)
 2. Press *esc*. This will bring up the menu at the top
 3. Using the arrow keys, navigate to the *Setup > Network options* menu item and press enter
 4. Move the cursor over to the *HTTP proxy* and *FTP proxy* fields and enter your proxies there
 5. Move the cursor to the *Ok* button and press enter
 6. Press *esc* to bring up the menu again
 7. Navigate to the *Setup > Save options* menu item and press enter
 8. Press *Q* to quit and *enter* to confirm

After doing this, links is configured to use your proxies and you may try `icalBuddy -u` again.


### Q: For some of my calendar items the bullet point is displayed on the right side of the line instead of on the left side, like it's supposed to. Why is this?

The calendar items in question probably have text in a language that's written from right to left? The Mac OS X text layout system sees this and automatically "flips" the line, putting the bullet point (which was supposed to be at the far left side of the line) to the far right. There are two workarounds I've come up with, depending on the application you're using to invoke icalBuddy:

 1. If the application you're using to call icalBuddy allows you to set the "writing direction" for the printed output, set that to something other than "natural". GeekTool doesn't support this by default, but you can instead use [my custom build of it][custom-geektool] that does.
 2. If the application you're using to call icalBuddy <em>does not</em> allow you to set the "writing direction", you can try to "trick" the layout system to keep the bullets on the left side by adding a letter from the latin alphabet as a part of the bullet point. Unfortunately this is not very pretty, though. :( So for example: `icalBuddy -b "I- "`. You can also omit the bullet points completely by running: `icalBuddy -b "" -ab ""`, but this won't keep the lines from being "flipped".


### Q: Why doesn't icalBuddy display events from calendars I see under the "Delegates" heading in iCal's calendar list?

icalBuddy uses OS X's CalendarStore API to access the calendar data. The CalDAV accounts (which is what a lot of people use to sync their Google Calendar account with iCal) are a feature of the iCal application, not the operating system itself, which is why the CalendarStore API won't return information about those calendars to icalBuddy. Nevertheless, I will try to see if I could get this feature working in the future using some other way.

**Current workaround:** Note that as opposed to delegate calendars, *subscribed calendars are visible to icalBuddy*, so if you want events from your Google Calendar calendars to be visible in icalBuddy, one trick to do it is to add a subscription to that calendar's feed into iCal (please refer to [Google's documentation][gcal-feeds] for help on how to do it). If you're using CalDAV to sync your Google Calendar account with iCal and also add subscriptions to some of those calendars in order to get them to show up in icalBuddy's output, remember to uncheck the visibility checkboxes of these subscription calendars in iCal &mdash; otherwise their events would be shown twice there (once for the CalDAV "delegate" calendar entry and once for the calendar subscription). Also remember to set the *auto-refresh* value sufficiently high for the subscribed calendars.


### Q: The question I had in mind is not answered here. What should I do?

You should look through icalBuddy's [manual page][manpageonline] and see if what you're looking for is documented there. Just type `man icalBuddy` into the terminal to see it. If what you're looking for is not in the manual, you can [contact the me, the author][hassegcontact].





[wp-manpages]:          http://en.wikipedia.org/wiki/Manual_page_(Unix)
[wp-envvars]:           http://en.wikipedia.org/wiki/Environment_variable
[wp-bashstartup]:       http://en.wikipedia.org/wiki/Bash#Startup_scripts
[manpageonline]:        http://hasseg.org/icalBuddy/man.html
[tuawmanviewers]:       http://www.tuaw.com/2008/03/07/here-comes-your-man-viewer/
[l10nmanpageonline]:    http://hasseg.org/icalBuddy/localization-man.html
[geektool]:             http://projects.tynsoe.org/en/geektool
[custom-geektool]:      http://hasseg.org/blog/?p=350
[datetimeformats]:      http://developer.apple.com/documentation/Cocoa/Conceptual/DataFormatting/Articles/df100103.html#//apple_ref/doc/uid/TP40007972-SW9
[hassegcontact]:        http://hasseg.org/
[links]:                http://links.sourceforge.net/
[gcal-feeds]:           http://www.google.com/support/calendar/bin/answer.py?hl=en&answer=37648

