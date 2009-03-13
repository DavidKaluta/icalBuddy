
icalBuddy FAQ
=====================



### Q: Does icalBuddy have a manual? If so, where is it?

Yes indeed: icalBuddy, like most other Unix-type command line applications, has a [man page][wikipediamanpages]. You can read it by typing `man icalBuddy` into the terminal.


### Q: The output of my calendar items is garbled! What gives?

icalBuddy uses unicode (UTF-8) string encoding by default in its output, so make sure that the application you're using to invoke it understands UTF-8. If there's a mismatch between the string encoding icalBuddy uses for its output and the string encoding an application uses to read that output, some special characters (like umlauts, chinese or arabic) might not display correctly. [GeekTool][geektool] doesn't understand UTF-8 by default, but you can get a custom build that does from [Xu Lian's page here][xulian]. You can also use the `--strEncoding` argument to make icalBuddy output using some other string encoding. Run `icalBuddy strEncodings` to see all the possible values you can use for that argument.


### Q: How can I get icalBuddy to display times according to a 12-hour clock?

You can use the `-tf` (or `--timeFormat`) argument to specify the format in which to display times. For example, `icalBuddy -tf "%1I:%M %p" eventsToday` would display times such as `5:00 PM`. See [Apple's documentation][datetimeformats] for all the possible values you can use for date and time formatting (there's also the `-df` (or `--dateFormat`) argument for date formatting, which works similarly to this one.)


### Q: How can I change the bullet points used in the output? We don't like them asterisks around these here parts.

You can use the `-b` (or `--bullet`) argument to change the normal bullet point value (`"* "` by default) and `-ab` (or `--alertBullet`) to change the alert bullet point value (`"! "` by default, used for tasks that are late from their due date.) Also note that you can change indenting for non-bulleted lines with the `-i` (or `--indent`) argument.


### Q: The question I had in mind is not answered here. What should I do?

You should look through icalBuddy's manual page and see if what you're looking for is documented there. Just type `man icalBuddy` into the terminal to see it. If what you're looking for is not in the manual, you can [contact the author][hassegcontact].



[wikipediamanpages]: http://en.wikipedia.org/wiki/Manual_page_(Unix)
[geektool]: http://projects.tynsoe.org/en/geektool
[xulian]: http://sites.google.com/site/lianxukeefo/Home/research/geektool-utf8
[datetimeformats]: http://developer.apple.com/documentation/Cocoa/Conceptual/DataFormatting/Articles/df100103.html#//apple_ref/doc/uid/TP40007972-SW9
[hassegcontact]: http://hasseg.org/blog/?page_id=2

