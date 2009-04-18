//  icalBuddy.m
//
//  Created by Ali Rantakari on 17 June 2008
//  http://hasseg.org
//

/*
The MIT License

Copyright (c) 2008-2009 Ali Rantakari

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/


#import <Foundation/Foundation.h>
#import <CalendarStore/CalendarStore.h>
#import <AppKit/AppKit.h>
#import <AddressBook/AddressBook.h>
#import "ANSIEscapeHelper.h"


#define kAppSiteURLPrefix 		@"http://hasseg.org/icalBuddy/"
#define kVersionCheckURL 		[NSURL URLWithString:@"http://hasseg.org/icalBuddy/?versioncheck=y"]
#define kVersionCheckTimeout 	10.0
#define kVersionCheckHeaderName	@"Orghassegsoftwarelatestversion"


#define kInternalErrorDomain @"org.hasseg.icalBuddy"

#define kPropertyListEditorAppName @"Property List Editor"

// custom date-formatting specifier ("relative week")
#define kRelativeWeekFormatSpecifier @"%RW"

// keys for the "sections" dictionary (see printItemSections())
#define kSectionDictKey_title 				@"sectionTitle"
#define kSectionDictKey_items 				@"sectionItems"
#define kSectionDictKey_eventsContextDay 	@"eventsContextDay"


// property names
#define kPropName_title 	@"title"
#define kPropName_location 	@"location"
#define kPropName_notes 	@"notes"
#define kPropName_url 		@"url"
#define kPropName_datetime 	@"datetime"
#define kPropName_priority 	@"priority"

// human-readable priority values
#define kPriorityStr_high 	@"high"
#define kPriorityStr_medium @"medium"
#define kPriorityStr_low 	@"low"

// default item property order + list of allowed property names (i.e. these must be in
// the default order and include all of the allowed property names)
#define kDefaultPropertyOrder [NSArray arrayWithObjects:kPropName_title, kPropName_location, kPropName_notes, kPropName_url, kPropName_datetime, kPropName_priority, nil]

#define kDefaultPropertySeparators [NSArray arrayWithObjects:@"\n    ", nil]

// localization configuration file path
#define kL10nFilePath @"~/.icalBuddyLocalization.plist"

// general configuration file path
#define kConfigFilePath @"~/.icalBuddyConfig.plist"

// contents for a new configuration file "stub"
#define kConfigFileStub [NSDictionary dictionaryWithObjectsAndKeys:\
						 [NSDictionary dictionary], @"formatting",\
						 nil\
						]

// helper macros for dealing with NSMutableAttributedStrings
#define kEmptyMutableAttributedString 	[[[NSMutableAttributedString alloc] init] autorelease]
#define MUTABLE_ATTR_STR(x)				[[[NSMutableAttributedString alloc] initWithString:(x)] autorelease]


const int VERSION_MAJOR = 1;
const int VERSION_MINOR = 6;
const int VERSION_BUILD = 1;







// printOptions for calendar item printing functions
enum calItemPrintOption
{
	PRINT_OPTION_NONE = 				0,
	PRINT_OPTION_SINGLE_DAY = 			(1 << 0),	// in the contex of a single day (for events) (i.e. don't print out full dates)
	PRINT_OPTION_CALENDAR_AGNOSTIC = 	(1 << 1)	// calendar-agnostic (i.e. don't print out the calendar name)
} CalItemPrintOption;









// the string encoding to use for output
NSStringEncoding outputStrEncoding = NSUTF8StringEncoding; // default

// the order of properties in the output
NSArray *propertyOrder;

// the separator strings between properties in the output
NSArray *propertySeparators = nil;

// the prefix strings
NSString *prefixStrBullet = 			@"* ";
NSString *prefixStrBulletAlert = 		@"! ";
NSString *prefixStrIndent = 			@"    ";
NSString *sectionSeparatorStr = 		@"\n------------------------";

NSString *timeFormatStr = 				@"%H:%M";
NSString *dateFormatStr = 				@"%Y-%m-%d";
NSString *dateTimeSeparatorStr = 		@" at ";
NSSet *includedEventProperties = 		nil;
NSSet *excludedEventProperties = 		nil;
NSSet *includedTaskProperties = 		nil;
NSSet *excludedTaskProperties = 		nil;
NSInteger notesNewlinesIndentModifier =	0;

BOOL displayRelativeDates = YES;
NSUInteger maxPrintedItems = 0; // 0 = no limit
NSUInteger printedItems = 0;


NSCalendarDate *now;
NSCalendarDate *today;


// dictionary for configuration values
NSMutableDictionary *configDict;

// default version of the formatting styles dictionary
// that normally is under the "formatting" key in
// configDict (if the user has defined it in the
// configuration file.)
NSDictionary *defaultFormattingConfigDict;

// dictionary for localization values
NSDictionary *L10nStringsDict;

// default version of L10nStringsDict
NSDictionary *defaultStringsDict;

// the output buffer string where we add everything we
// want to print out, and right before terminating
// convert to an ANSI-escaped string and push it to
// the standard output. this way we can easily modify
// the formatting of the output right up until the
// last minute.
NSMutableAttributedString *stdoutBuffer;

ANSIEscapeHelper *ansiEscapeHelper;





//-------------------------------------------------------------------
//-------------------------------------------------------------------
// BEGIN: Misc. helper functions


NSString* versionNumber()
{
	return [NSString stringWithFormat:@"%d.%d.%d", VERSION_MAJOR, VERSION_MINOR, VERSION_BUILD];
}



// adds the specified attributed string to the output buffer.
void addToOutputBuffer(NSAttributedString *aStr)
{
	[stdoutBuffer appendAttributedString:aStr];
}



// helper methods for printing to stdout and stderr
// 		from: http://www.sveinbjorn.org/objectivec_stdout
// 		(modified to use non-deprecated version of writeToFile:...
//       and allow for using the "string format" syntax)
void NSPrint(NSString *aStr, ...)
{
	va_list argList;
	va_start(argList, aStr);
	NSString *str = [
		[[NSString alloc]
			initWithFormat:aStr
			locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]
			arguments:argList
		] autorelease
		];
	va_end(argList);
	
	[str writeToFile:@"/dev/stdout" atomically:NO encoding:outputStrEncoding error:NULL];
}

void NSPrintErr(NSString *aStr, ...)
{
	va_list argList;
	va_start(argList, aStr);
	NSString *str = [
		[[NSString alloc]
			initWithFormat:aStr
			locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]
			arguments:argList
		] autorelease
		];
	va_end(argList);
	
	[str writeToFile:@"/dev/stderr" atomically:NO encoding:outputStrEncoding error:NULL];
}





// helper method: compare three-part version number strings (e.g. "1.12.3")
NSComparisonResult versionNumberCompare(NSString *first, NSString *second)
{
	if (first != nil && second != nil)
	{
		int i;
		
		NSMutableArray *firstComponents = [NSMutableArray arrayWithCapacity:3];
		[firstComponents addObjectsFromArray:[first componentsSeparatedByString:@"."]];
		
		NSMutableArray *secondComponents = [NSMutableArray arrayWithCapacity:3];
		[secondComponents addObjectsFromArray:[second componentsSeparatedByString:@"."]];
		
		if ([firstComponents count] != [secondComponents count])
		{
			NSMutableArray *shorter;
			NSMutableArray *longer;
			if ([firstComponents count] > [secondComponents count])
			{
				shorter = secondComponents;
				longer = firstComponents;
			}
			else
			{
				shorter = firstComponents;
				longer = secondComponents;
			}
			
			NSUInteger countDiff = [longer count] - [shorter count];
			
			for (i = 0; i < countDiff; i++)
				[shorter addObject:@"0"];
		}
		
		for (i = 0; i < [firstComponents count]; i++)
		{
			int firstComponentIntVal = [[firstComponents objectAtIndex:i] intValue];
			int secondComponentIntVal = [[secondComponents objectAtIndex:i] intValue];
			if (firstComponentIntVal < secondComponentIntVal)
				return NSOrderedAscending;
			else if (firstComponentIntVal > secondComponentIntVal)
				return NSOrderedDescending;
		}
		return NSOrderedSame;
	}
	else
		return NSOrderedSame;
}



// convenience function: concatenates strings (yes, I hate the
// verbosity of -stringByAppendingString:.)
// NOTE: MUST SEND nil AS THE LAST ARGUMENT
NSString* strConcat(NSString *firstStr, ...)
{
	if (firstStr)
	{
		va_list argList;
		NSString *retVal = [NSString stringWithString:firstStr];
		NSString *str;
		va_start(argList, firstStr);
		while((str = va_arg(argList, NSString*)))
			retVal = [retVal stringByAppendingString:str];
		va_end(argList);
		return retVal;
	}
	return nil;
}



// returns localized, human-readable string corresponding to the
// specified localization dictionary key
NSString* localizedStr(NSString *str)
{
	if (str == nil)
		return nil;
	
	if (L10nStringsDict != nil)
	{
		NSString *localizedStr = [L10nStringsDict objectForKey:str];
		if (localizedStr != nil)
			return localizedStr;
	}
	
	NSString *defaultStr = [defaultStringsDict objectForKey:str];
	NSCAssert((defaultStr != nil), @"defaultStr is nil");
	return defaultStr;
}




// create an NSSet from a comma-separated string,
// trimming whitespace from around each string component
NSSet* setFromCommaSeparatedStringTrimmingWhitespace(NSString *str)
{
	if (str != nil)
	{
		NSMutableSet *set = [NSMutableSet setWithCapacity:10];
		NSArray *arr = [str componentsSeparatedByString:@","];
		NSString *component;
		for (component in arr)
			[set addObject:[component stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
		return set;
	}
	return [NSSet set];
}


// create an NSArray from a comma-separated string,
// trimming whitespace from around each string component
NSArray* arrayFromCommaSeparatedStringTrimmingWhitespace(NSString *str)
{
	if (str != nil)
	{
		NSMutableArray *retArr = [NSMutableArray arrayWithCapacity:10];
		NSArray *arr = [str componentsSeparatedByString:@","];
		NSString *component;
		for (component in arr)
			[retArr addObject:[component stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
		return retArr;
	}
	return [NSArray array];
}


// create an NSArray from a string where components are
// separated by an arbitrary character and this separator character
// must be present as both the first and the last character
// in the given string (e.g.: @"/first/second/third/")
NSArray* arrayFromArbitrarilySeparatedString(NSString *str, NSError **error)
{
	if (str == nil)
	{
		if (error != NULL)
			*error = [NSError
				errorWithDomain:kInternalErrorDomain
				code:0
				userInfo:[NSDictionary
					dictionaryWithObject:@"Given string is null"
					forKey:NSLocalizedDescriptionKey
					]
				];
		return nil;
	}
	if ([str length] < 2)
	{
		if (error != NULL)
			*error = [NSError
				errorWithDomain:kInternalErrorDomain
				code:0
				userInfo:[NSDictionary
					dictionaryWithObject:@"Given string has less than two characters"
					forKey:NSLocalizedDescriptionKey
					]
				];
		return nil;
	}
	
	NSString *separatorChar = nil;
	
	NSString *firstChar = [str substringToIndex:1];
	NSString *lastChar = [str substringFromIndex:[str length]-1];
	if ([firstChar isEqualToString:lastChar])
		separatorChar = firstChar;
	
	if (separatorChar != nil)
	{
		NSString *trimmedStr = [str substringWithRange:NSMakeRange(1,([str length]-2))];
		return [trimmedStr componentsSeparatedByString:separatorChar];
	}
	
	return [NSArray array];
}



// sort function for sorting tasks:
// - sort numerically by priority except treat CalPriorityNone (0) as a special case
// - if priorities match, sort tasks that are late from their due date to be first and then
//   order alphabetically by title
NSInteger prioritySort(id task1, id task2, void *context)
{
    if ([task1 priority] < [task2 priority])
	{
		if ([task1 priority] == CalPriorityNone)
			return NSOrderedDescending;
		else
			return NSOrderedAscending;
	}
    else if ([task1 priority] > [task2 priority])
		if ([task2 priority] == CalPriorityNone)
			return NSOrderedAscending;
		else
			return NSOrderedDescending;
    else
	{
		// check if one task is late and the other is not
		BOOL task1late = NO;
		BOOL task2late = NO;
		if ([task1 dueDate] != nil)
			if ([now compare:[task1 dueDate]] == NSOrderedDescending)
				task1late = YES;
		if ([task2 dueDate] != nil)
			if ([now compare:[task2 dueDate]] == NSOrderedDescending)
				task2late = YES;
		
		if (task1late && !task2late)
			return NSOrderedAscending;
		else if (task2late && !task1late)
			return NSOrderedDescending;
		
		// neither task is, or both tasks are late -> order alphabetically by title
        return [[task1 title] compare:[task2 title]];
	}
}





// whether the two specified dates represent the same calendar day
BOOL datesRepresentSameDay(NSCalendarDate *date1, NSCalendarDate *date2)
{
	return ([date1 yearOfCommonEra] == [date2 yearOfCommonEra] &&
			[date1 monthOfYear] == [date2 monthOfYear] &&
			[date1 dayOfMonth] == [date2 dayOfMonth]
			);
}






// returns the total number of ISO weeks in a given year
NSInteger getNumWeeksInYear(NSInteger year)
{
	// have to check both December 31 and December 24 (a week before the 31st)
	// because the 31st may have week n:o 1 (of the following year) and the 24th
	// may have week n:o (max-1) -- we want whichever is higher
	
	NSDateComponents *lastDayOfYearComponents = [[[NSDateComponents alloc] init] autorelease];
	[lastDayOfYearComponents setYear:year];
	[lastDayOfYearComponents setMonth:12];
	[lastDayOfYearComponents setDay:31];
	NSDate *lastDayOfYear = [[NSCalendar currentCalendar] dateFromComponents:lastDayOfYearComponents];
	
	NSInteger lastDayWeek = [[[NSCalendar currentCalendar]
		components:NSWeekCalendarUnit
		fromDate:lastDayOfYear
		] week];
	
	NSDateComponents *weekBeforeLastDayOfYearComponents = [[[NSDateComponents alloc] init] autorelease];
	[weekBeforeLastDayOfYearComponents setYear:year];
	[weekBeforeLastDayOfYearComponents setMonth:12];
	[weekBeforeLastDayOfYearComponents setDay:24];
	NSDate *weekBeforeLastDayOfYear = [[NSCalendar currentCalendar] dateFromComponents:weekBeforeLastDayOfYearComponents];
	
	NSInteger weekBeforeLastDayWeek = [[[NSCalendar currentCalendar]
		components:NSWeekCalendarUnit
		fromDate:weekBeforeLastDayOfYear
		] week];
	
	return (lastDayWeek > weekBeforeLastDayWeek) ? lastDayWeek : weekBeforeLastDayWeek;
}


// get number representing the absolute value of the
// difference between two dates in logical weeks (e.g. would
// return 1 if given this sunday and next week's monday,
// assuming (for the sake of this example) that the week
// starts on monday)
NSInteger getWeekDiff(NSDate *date1, NSDate *date2)
{
	if (date1 == nil || date2 == nil)
		return 0;
	
	NSDateComponents *components1 = [[NSCalendar currentCalendar]
		components:NSWeekCalendarUnit|NSYearCalendarUnit
		fromDate:date1
		];
	NSDateComponents *components2 = [[NSCalendar currentCalendar]
		components:NSWeekCalendarUnit|NSYearCalendarUnit
		fromDate:date2
		];
	
	NSInteger week1 = [components1 week];
	NSInteger week2 = [components2 week];
	NSInteger year1 = [components1 year];
	NSInteger year2 = [components2 year];
	
	NSInteger earlierDateYear;
	NSInteger earlierDateWeek;
	NSInteger laterDateYear;
	NSInteger laterDateWeek;
	if (year1 < year2)
	{
		earlierDateYear = year1;
		earlierDateWeek = week1;
		laterDateYear = year2;
		laterDateWeek = week2;
	}
	else
	{
		earlierDateYear = year2;
		earlierDateWeek = week2;
		laterDateYear = year1;
		laterDateWeek = week1;
	}
	
	// check if week numbers are from the same year (the week number
	// of the last days in a year is often week #1 of the next
	// year) -- if so, they are directly comparable
	if ((year1 == year2) ||
		(abs(year1-year2)==1 && earlierDateWeek==1))
		return abs(week2-week1);
	
	// if there is more than one year between the dates, get the
	// total number of weeks in the years between
	NSInteger numWeeksInYearsBetween = 0;
	if (abs(year1-year2) > 1)
	{
		NSInteger i;
		for (i = earlierDateYear+1; i < laterDateYear; i++)
		{
			numWeeksInYearsBetween += getNumWeeksInYear(i);
		}
	}
	
	NSInteger numWeeksInEarlierDatesYear = getNumWeeksInYear(earlierDateYear);
	
	return (laterDateWeek+(numWeeksInEarlierDatesYear-earlierDateWeek))+numWeeksInYearsBetween;
}










// whether propertyName is ok to be printed, based on a set of property
// names to be included and a set of property names to be excluded
BOOL shouldPrintProperty(NSString *propertyName, NSSet *inclusionsSet, NSSet *exclusionsSet)
{
	if (propertyName == nil || (inclusionsSet == nil && exclusionsSet == nil))
		return YES;
	
	BOOL retVal = YES;
	
	if (inclusionsSet != nil)
		if (![inclusionsSet containsObject:propertyName])
			retVal = NO;
	
	if (retVal == YES && exclusionsSet != nil)
		if ([exclusionsSet containsObject:propertyName] || [exclusionsSet containsObject:@"*"])
			retVal = NO;
	
	return retVal;
}






// returns a formatted date+time
NSString* dateStr(NSDate *date, BOOL includeDate, BOOL includeTime)
{
	if (date == nil || (!includeDate && !includeTime))
		return @"";
	
	NSCalendarDate *calDate = [date dateWithCalendarFormat:nil timeZone:nil];
	
	NSString *outputDate = nil;
	NSString *outputTime = nil;
	
	if (includeDate)
	{
		if (displayRelativeDates &&
			datesRepresentSameDay(calDate, now))
			outputDate = localizedStr(@"today");
		else if (displayRelativeDates &&
				datesRepresentSameDay(calDate, [now dateByAddingYears:0 months:0 days:1 hours:0 minutes:0 seconds:0]))
			outputDate = localizedStr(@"tomorrow");
		else if (displayRelativeDates &&
				datesRepresentSameDay(calDate, [now dateByAddingYears:0 months:0 days:2 hours:0 minutes:0 seconds:0]))
			outputDate = localizedStr(@"dayAfterTomorrow");
		else if (displayRelativeDates &&
				datesRepresentSameDay(calDate, [now dateByAddingYears:0 months:0 days:-1 hours:0 minutes:0 seconds:0]))
			outputDate = localizedStr(@"yesterday");
		else if (displayRelativeDates &&
				datesRepresentSameDay(calDate, [now dateByAddingYears:0 months:0 days:-2 hours:0 minutes:0 seconds:0]))
			outputDate = localizedStr(@"dayBeforeYesterday");
		else
		{
			NSString *useDateFormatStr = dateFormatStr;
			
			// implement the "relative week" date format specifier
			NSRange relativeWeekFormatSpecifierRange = [useDateFormatStr rangeOfString:kRelativeWeekFormatSpecifier];
			if (relativeWeekFormatSpecifierRange.location != NSNotFound)
			{
				NSInteger weekDiff = getWeekDiff(now, date);
				if ([now compare:date] == NSOrderedDescending)
					weekDiff *= -1; // in the past
				
				NSString *weekDiffStr = nil;
				if (weekDiff < -1)
					weekDiffStr = [NSString stringWithFormat:localizedStr(@"xWeeksAgo"), abs(weekDiff)];
				else if (weekDiff == -1)
					weekDiffStr = localizedStr(@"lastWeek");
				else if (weekDiff == 0)
					weekDiffStr = localizedStr(@"thisWeek");
				else if (weekDiff == 1)
					weekDiffStr = localizedStr(@"nextWeek");
				else if (weekDiff > 1)
					weekDiffStr = [NSString stringWithFormat:localizedStr(@"xWeeksFromNow"), weekDiff];
				
				if (weekDiffStr != nil)
					useDateFormatStr = [useDateFormatStr
						stringByReplacingCharactersInRange:relativeWeekFormatSpecifierRange
						withString:weekDiffStr
						];
			}
			
			outputDate = [date
				descriptionWithCalendarFormat:useDateFormatStr
				timeZone:nil
				locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]
				];
		}
	}
	
	if (includeTime)
		outputTime = [date
			descriptionWithCalendarFormat:timeFormatStr
			timeZone:nil
			locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]
			];
	
	if (outputDate != nil && outputTime == nil)
		return outputDate;
	else if (outputDate == nil && outputTime != nil)
		return outputTime;
	else
		return strConcat(outputDate, dateTimeSeparatorStr, outputTime, nil);
}



NSMutableAttributedString* mutableAttrStrWithAttrs(NSString *string, NSDictionary *attrs)
{
	return [[[NSMutableAttributedString alloc] initWithString:string attributes:attrs] autorelease];
}





//-------------------------------------------------------------------
//-------------------------------------------------------------------
// BEGIN: Functions for formatting the output


// returns a dictionary of attribute name (key) - attribute value (value)
// pairs (suitable for using directly with NSMutableAttributedString's
// attribute setter methods) based on a user-defined formatting specification
// (from the config file, like: "red,bg:blue,bold")
NSMutableDictionary* formattingConfigToStringAttributes(NSString *formattingConfig)
{
	NSMutableDictionary *returnAttributes = [NSMutableDictionary dictionary];
	
	NSArray *parts = [formattingConfig componentsSeparatedByString:@","];
	NSString *part;
	for (part in parts)
	{
		part = [[part stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] lowercaseString];
		
		NSString *thisAttrName = nil;
		NSObject *thisAttrValue = nil;
		
		BOOL isColorAttribute = NO;
		BOOL isBackgroundColor = NO;
		if ([part hasPrefix:@"fg:"] ||
			[part isEqualToString:@"black"] ||
			[part isEqualToString:@"red"] ||
			[part isEqualToString:@"green"] ||
			[part isEqualToString:@"yellow"] ||
			[part isEqualToString:@"blue"] ||
			[part isEqualToString:@"magenta"] ||
			[part isEqualToString:@"white"] ||
			[part isEqualToString:@"cyan"]
			)
		{
			thisAttrName = NSForegroundColorAttributeName;
			isColorAttribute = YES;
		}
		else if ([part hasPrefix:@"bg:"])
		{
			thisAttrName = NSBackgroundColorAttributeName;
			isColorAttribute = YES;
			isBackgroundColor = YES;
		}
		else if ([part isEqualToString:@"bold"])
		{
			thisAttrName = NSFontAttributeName;
			thisAttrValue = [[NSFontManager sharedFontManager] convertFont:[ansiEscapeHelper font] toHaveTrait:NSBoldFontMask];
		}
		else if ([part hasSuffix:@"underlined"])
		{
			thisAttrName = NSUnderlineStyleAttributeName;
			if ([part hasPrefix:@"double-"])
				thisAttrValue = [NSNumber numberWithInteger:NSUnderlineStyleDouble];
			else
				thisAttrValue = [NSNumber numberWithInteger:NSUnderlineStyleSingle];
		}
		
		if (isColorAttribute)
		{
			enum sgrCode thisColorSGRCode = SGRCodeNoneOrInvalid;
			if ([part hasSuffix:@"black"])
				thisColorSGRCode = SGRCodeFgBlack;
			else if ([part hasSuffix:@"red"])
				thisColorSGRCode = SGRCodeFgRed;
			else if ([part hasSuffix:@"green"])
				thisColorSGRCode = SGRCodeFgGreen;
			else if ([part hasSuffix:@"yellow"])
				thisColorSGRCode = SGRCodeFgYellow;
			else if ([part hasSuffix:@"blue"])
				thisColorSGRCode = SGRCodeFgBlue;
			else if ([part hasSuffix:@"magenta"])
				thisColorSGRCode = SGRCodeFgMagenta;
			else if ([part hasSuffix:@"white"])
				thisColorSGRCode = SGRCodeFgWhite;
			else if ([part hasSuffix:@"cyan"])
				thisColorSGRCode = SGRCodeFgCyan;
			
			if (thisColorSGRCode != SGRCodeNoneOrInvalid)
			{
				if (isBackgroundColor)
					thisColorSGRCode += 10;
				thisAttrValue = [ansiEscapeHelper colorForSGRCode:thisColorSGRCode];
			}
		}
		
		if (thisAttrName != nil && thisAttrValue != nil)
			[returnAttributes setValue:thisAttrValue forKey:thisAttrName];
	}
	
	return returnAttributes;
}



// return formatting string attributes for specified key
NSDictionary* getStringAttributesForKey(NSString *key)
{
	if (key == nil)
		return [NSDictionary dictionary];
	
	NSString *formattingConfig = nil;
	
	if (configDict != nil)
	{
		NSDictionary *formattingConfigDict = [configDict objectForKey:@"formatting"];
		if (formattingConfigDict != nil)
			formattingConfig = [formattingConfigDict objectForKey:key];
	}
	
	if (formattingConfig == nil)
		formattingConfig = [defaultFormattingConfigDict objectForKey:key];
	
	if (formattingConfig != nil)
		return formattingConfigToStringAttributes(formattingConfig);
	
	return [NSDictionary dictionary];
}



// return string attributes for formatting a section title
NSDictionary* getSectionTitleStringAttributes(NSString *sectionTitle)
{
	return getStringAttributesForKey(@"sectionTitle");
}


// return string attributes for formatting the first printed
// line for a calendar item
NSDictionary* getFirstLineStringAttributes()
{
	return getStringAttributesForKey(@"firstItemLine");
}



// return string attributes for formatting a bullet point
NSDictionary* getBulletStringAttributes(BOOL isAlertBullet)
{
	return getStringAttributesForKey((isAlertBullet)?@"alertBullet":@"bullet");
}



// return string attributes for formatting a property name
NSDictionary* getPropNameStringAttributes(NSString *propName)
{
	if (propName == nil)
		return [NSDictionary dictionary];
	
	NSString *formattingConfigKey = [propName stringByAppendingString:@"Name"];
	return getStringAttributesForKey(formattingConfigKey);
}


// return string attributes for formatting a property value
NSDictionary* getPropValueStringAttributes(NSString *propName, NSString *propValue)
{
	if (propName == nil)
		return [NSDictionary dictionary];
	
	NSString *formattingConfigKey = [propName stringByAppendingString:@"Value"];
	if (propName == kPropName_priority)
	{
		if (propValue != nil)
		{
			if ([propValue isEqual:localizedStr(kPriorityStr_high)])
				formattingConfigKey = @"priorityValueHigh";
			else if ([propValue isEqual:localizedStr(kPriorityStr_medium)])
				formattingConfigKey = @"priorityValueMedium";
			else if ([propValue isEqual:localizedStr(kPriorityStr_low)])
				formattingConfigKey = @"priorityValueLow";
		}
	}
	return getStringAttributesForKey(formattingConfigKey);
}


// return separator string to prefix a printed property with, based on the
// number of the property (as in: is it the first to be printed (1), the second
// (2) and so on.)
NSString* getPropSeparatorStr(NSUInteger propertyNumber)
{
	NSCAssert((propertySeparators != nil), @"propertySeparators is nil");
	NSCAssert(([propertySeparators count] > 0), @"propertySeparators is empty");
	
	// we subtract two here because the first printed property is always
	// prefixed with a bullet (so we only have propertySeparator prefix
	// strings for properties thereafter -- thus -1) and we want a zero-based
	// index to use for the array access (thus the other -1)
	NSUInteger indexToGet = (propertyNumber >= 2) ? (propertyNumber-2) : 0;
	NSUInteger lastIndex = [propertySeparators count]-1;
	if (indexToGet > lastIndex)
		indexToGet = lastIndex;
	
	return [propertySeparators objectAtIndex:indexToGet];
}








//-------------------------------------------------------------------
//-------------------------------------------------------------------
// BEGIN: Functions for pretty-printing data


// returns a pretty-printed string representation of the specified event property
NSMutableAttributedString* getEventPropStr(NSString *propName, CalEvent *event, int printOptions, NSCalendarDate *contextDay)
{
	if (event != nil)
	{
		NSString *thisPropOutputName = nil;
		NSString *thisPropOutputValue = nil;
		
		if ([propName isEqualToString:kPropName_title])
		{
			if ([[[event calendar] type] isEqualToString:CalCalendarTypeBirthday])
			{
				// special case for events in the Birthdays calendar (they don't seem to have titles
				// so we have to use the URI to find the ABPerson from the Address Book
				// and print their name from there)
				
				NSString *personId = [[NSString stringWithFormat:@"%@", [event url]] stringByReplacingOccurrencesOfString:@"addressbook://" withString:@""];
				ABRecord *person = [[ABAddressBook sharedAddressBook] recordForUniqueId:personId];
				
				if (person != nil)
				{
					if ([person isMemberOfClass: [ABPerson class]])
					{
						NSString *thisTitle;
						if ([person isEqual:[[ABAddressBook sharedAddressBook] me]])
							thisTitle = localizedStr(@"myBirthday");
						else
						{
							NSString *contactFullName = strConcat(
								[person valueForProperty:kABFirstNameProperty],
								@" ",
								[person valueForProperty:kABLastNameProperty],
								nil
								);
							thisTitle = [NSString stringWithFormat:localizedStr(@"someonesBirthday"), contactFullName];
						}
						if (printOptions & PRINT_OPTION_CALENDAR_AGNOSTIC)
							thisPropOutputValue = thisTitle;
						else
							thisPropOutputValue = [NSString stringWithFormat: @"%@ (%@)", thisTitle, [[event calendar] title]];
					}
				}
			}
			else
			{
				if (printOptions & PRINT_OPTION_CALENDAR_AGNOSTIC)
					thisPropOutputValue = [event title];
				else
					thisPropOutputValue = [NSString stringWithFormat: @"%@ (%@)", [event title], [[event calendar] title]];
			}
		}
		else if ([propName isEqualToString:kPropName_location])
		{
			thisPropOutputName = strConcat(localizedStr(@"location"), @":", nil);
			
			if ([event location] != nil && ![[[event location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] isEqualToString:@""])
				thisPropOutputValue = [event location];
		}
		else if ([propName isEqualToString:kPropName_notes])
		{
			thisPropOutputName = strConcat(localizedStr(@"notes"), @":", nil);
			
			if ([event notes] != nil && ![[[event notes] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] isEqualToString:@""])
			{
				NSInteger thisNewlinesIndentModifier = [thisPropOutputName length]+1+notesNewlinesIndentModifier;
				thisPropOutputValue = [
					[event notes]
					stringByReplacingOccurrencesOfString:@"\n"
					withString:[
						NSString
						stringWithFormat:@"\n%@%@",
							prefixStrIndent,
							[@""
								stringByPaddingToLength:MAX(0, thisNewlinesIndentModifier)
								withString:@" "
								startingAtIndex:0
							]
					]
					];
			}
		}
		else if ([propName isEqualToString:kPropName_url])
		{
			thisPropOutputName = strConcat(localizedStr(@"url"), @":", nil);
			
			if ([event url] != nil &&
				![[[event calendar] type] isEqualToString:CalCalendarTypeBirthday])
				thisPropOutputValue = [NSString stringWithFormat: @"%@", [event url]];
		}
		else if ([propName isEqualToString:kPropName_datetime])
		{
			if ([[[event calendar] type] isEqualToString:CalCalendarTypeBirthday])
			{
				if (!(printOptions & PRINT_OPTION_SINGLE_DAY))
					thisPropOutputValue = dateStr([event startDate], true, false);
			}
			else
			{
				BOOL singleDayContext = (printOptions & PRINT_OPTION_SINGLE_DAY);
				
				if ( !singleDayContext || (singleDayContext && ![event isAllDay]) )
				{
					if ([[event startDate] isEqualToDate:[event endDate]])
						thisPropOutputValue = dateStr([event startDate], (!(printOptions & PRINT_OPTION_SINGLE_DAY)), true);
					else
					{
						if (printOptions & PRINT_OPTION_SINGLE_DAY)
						{
							BOOL startsOnContextDay = datesRepresentSameDay(contextDay, [[event startDate] dateWithCalendarFormat:nil timeZone:nil]);
							BOOL endsOnContextDay = datesRepresentSameDay(contextDay, [[event endDate] dateWithCalendarFormat:nil timeZone:nil]);
							if (startsOnContextDay && endsOnContextDay)
								thisPropOutputValue = [NSString
									stringWithFormat: @"%@ - %@",
										dateStr([event startDate], false, true),
										dateStr([event endDate], false, true)
									];
							else if (startsOnContextDay)
								thisPropOutputValue = [NSString
									stringWithFormat: @"%@ - ...",
										dateStr([event startDate], false, true)
									];
							else if (endsOnContextDay)
								thisPropOutputValue = [NSString
									stringWithFormat: @"... - %@",
										dateStr([event endDate], false, true)
									];
						}
						else
						{
							if ([event isAllDay])
							{
								NSInteger daysDiff;
								[[[event endDate] dateWithCalendarFormat:nil timeZone:nil]
									years:NULL months:NULL days:&daysDiff hours:NULL minutes:NULL seconds:NULL
									sinceDate:[[event startDate] dateWithCalendarFormat:nil timeZone:nil]
									];
								
								if (daysDiff > 1)
								{
									// all-day events technically span from <start day> at 00:00 to <end day+1> at 00:00 even though
									// we want them displayed as only spanning from <start day> to <end day>
									NSCalendarDate *endDateMinusOneDay = [[[event endDate] dateWithCalendarFormat:nil timeZone:nil] dateByAddingYears:0 months:0 days:-1 hours:0 minutes:0 seconds:0];
									thisPropOutputValue = [NSString
										stringWithFormat: @"%@ - %@",
											dateStr([event startDate], true, false),
											dateStr(endDateMinusOneDay, true, false)
										];
								}
								else
									thisPropOutputValue = dateStr([event startDate], true, false);
							}
							else
							{
								NSString *startDateFormattedStr = dateStr([event startDate], true, true);
								NSString *endDateFormattedStr;
								if (datesRepresentSameDay([[event startDate] dateWithCalendarFormat:nil timeZone:nil], [[event endDate] dateWithCalendarFormat:nil timeZone:nil]))
									endDateFormattedStr = dateStr([event endDate], false, true);
								else
									endDateFormattedStr = dateStr([event endDate], true, true);
								thisPropOutputValue = [NSString stringWithFormat: @"%@ - %@", startDateFormattedStr, endDateFormattedStr];
							}
						}
					}
				}
			}
		}
		
		if (thisPropOutputValue != nil)
		{
			NSMutableAttributedString *thisPropOutputNameAttrStr = nil;
			NSMutableAttributedString *thisPropOutputValueAttrStr = nil;
			
			if (thisPropOutputName != nil)
				thisPropOutputNameAttrStr = mutableAttrStrWithAttrs(thisPropOutputName, getPropNameStringAttributes(propName));
			
			if (thisPropOutputValue != nil)
			{
				thisPropOutputValue = [thisPropOutputValue stringByReplacingOccurrencesOfString:@"%" withString:@"%%"];
				thisPropOutputValueAttrStr = mutableAttrStrWithAttrs(thisPropOutputValue, getPropValueStringAttributes(propName, thisPropOutputValue));
			}
			
			NSMutableAttributedString *retVal = kEmptyMutableAttributedString;
			
			if (thisPropOutputName != nil)
			{
				[thisPropOutputNameAttrStr appendAttributedString:MUTABLE_ATTR_STR(@" ")];
				[retVal appendAttributedString:thisPropOutputNameAttrStr];
			}
			
			[retVal appendAttributedString:thisPropOutputValueAttrStr];
			
			return retVal;
		}
	}
	return nil;
}




// pretty-prints out the specified event
void printCalEvent(CalEvent *event, int printOptions, NSCalendarDate *contextDay)
{
	if (maxPrintedItems > 0 && maxPrintedItems <= printedItems)
		return;
	
	if (event != nil)
	{
		NSUInteger printedProps = 0;
		
		for (NSString *thisProp in propertyOrder)
		{
			if (shouldPrintProperty(thisProp, includedEventProperties, excludedEventProperties))
			{
				NSMutableAttributedString *thisPropStr = getEventPropStr(thisProp, event, printOptions, contextDay);
				if (thisPropStr != nil && [thisPropStr length] > 0)
				{
					NSMutableAttributedString *prefixStr;
					if (printedProps == 0)
						prefixStr = mutableAttrStrWithAttrs(prefixStrBullet, getBulletStringAttributes(NO));
					else
						prefixStr = MUTABLE_ATTR_STR(getPropSeparatorStr(printedProps+1));
					
					NSMutableAttributedString *thisOutput = kEmptyMutableAttributedString;
					[thisOutput appendAttributedString:prefixStr];
					[thisOutput appendAttributedString:thisPropStr];
					
					if (printedProps == 0)
						[thisOutput addAttributes:getFirstLineStringAttributes() range:NSMakeRange(0,[[thisOutput string] length])];
					
					addToOutputBuffer(thisOutput);
					
					printedProps++;
				}
			}
		}
		
		addToOutputBuffer(MUTABLE_ATTR_STR(@"\n"));
		
		printedItems++;
	}
}










// returns a pretty-printed string representation of the specified task property
NSMutableAttributedString* getTaskPropStr(NSString *propName, CalTask *task, int printOptions)
{
	if (task != nil)
	{
		NSString *thisPropOutputName = nil;
		NSString *thisPropOutputValue = nil;
		
		if ([propName isEqualToString:kPropName_title])
		{
			if (printOptions & PRINT_OPTION_CALENDAR_AGNOSTIC)
				thisPropOutputValue = [task title];
			else
				thisPropOutputValue = [NSString stringWithFormat: @"%@ (%@)", [task title], [[task calendar] title]];
		}
		else if ([propName isEqualToString:kPropName_notes])
		{
			thisPropOutputName = strConcat(localizedStr(@"notes"), @":", nil);
			
			if ([task notes] != nil && ![[[task notes] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] isEqualToString:@""])
			{
				NSInteger thisNewlinesIndentModifier = [thisPropOutputName length]+1+notesNewlinesIndentModifier;
				thisPropOutputValue = [[task notes]
					stringByReplacingOccurrencesOfString:@"\n"
					withString:[NSString
						stringWithFormat:@"\n%@%@",
							prefixStrIndent,
							[@""
								stringByPaddingToLength:MAX(0, thisNewlinesIndentModifier)
								withString:@" "
								startingAtIndex:0
							]
					]
					];
			}
		}
		else if ([propName isEqualToString:kPropName_url])
		{
			thisPropOutputName = strConcat(localizedStr(@"url"), @":", nil);
			
			if ([task url] != nil)
				thisPropOutputValue = [NSString stringWithFormat:@"%@", [task url]];
		}
		else if ([propName isEqualToString:kPropName_datetime])
		{
			thisPropOutputName = strConcat(localizedStr(@"dueDate"), @":", nil);
			
			if ([task dueDate] != nil && !(printOptions & PRINT_OPTION_SINGLE_DAY))
				thisPropOutputValue = dateStr([task dueDate], true, false);
		}
		else if ([propName isEqualToString:kPropName_priority])
		{
			thisPropOutputName = strConcat(localizedStr(@"priority"), @":", nil);
			
			if ([task priority] != CalPriorityNone)
			{
				switch([task priority])
				{
					case CalPriorityHigh:
						thisPropOutputValue = localizedStr(kPriorityStr_high);
						break;
					case CalPriorityMedium:
						thisPropOutputValue = localizedStr(kPriorityStr_medium);
						break;
					case CalPriorityLow:
						thisPropOutputValue = localizedStr(kPriorityStr_low);
						break;
					default:
						thisPropOutputValue = [NSString stringWithFormat:@"%d", [task priority]];
						break;
				}
			}
		}
		
		if (thisPropOutputValue != nil)
		{
			NSMutableAttributedString *thisPropOutputNameAttrStr = nil;
			NSMutableAttributedString *thisPropOutputValueAttrStr = nil;
			
			if (thisPropOutputName != nil)
				thisPropOutputNameAttrStr = mutableAttrStrWithAttrs(thisPropOutputName, getPropNameStringAttributes(propName));
			
			if (thisPropOutputValue != nil)
			{
				thisPropOutputValue = [thisPropOutputValue stringByReplacingOccurrencesOfString:@"%" withString:@"%%"];
				thisPropOutputValueAttrStr = mutableAttrStrWithAttrs(thisPropOutputValue, getPropValueStringAttributes(propName, thisPropOutputValue));
			}
			
			NSMutableAttributedString *retVal = kEmptyMutableAttributedString;
			
			if (thisPropOutputName != nil)
			{
				[thisPropOutputNameAttrStr appendAttributedString:MUTABLE_ATTR_STR(@" ")];
				[retVal appendAttributedString:thisPropOutputNameAttrStr];
			}
			
			[retVal appendAttributedString:thisPropOutputValueAttrStr];
			
			return retVal;
		}
	}
	return nil;
}




// pretty-prints out the specified task
void printCalTask(CalTask *task, int printOptions)
{
	if (maxPrintedItems > 0 && maxPrintedItems <= printedItems)
		return;
	
	if (task != nil)
	{
		NSUInteger printedProps = 0;
		
		for (NSString *thisProp in propertyOrder)
		{
			if (shouldPrintProperty(thisProp, includedTaskProperties, excludedTaskProperties))
			{
				NSMutableAttributedString *thisPropStr = getTaskPropStr(thisProp, task, printOptions);
				
				if (thisPropStr != nil && [thisPropStr length] > 0)
				{
					NSMutableAttributedString *prefixStr;
					if (printedProps == 0)
					{
						BOOL useAlertBullet = 	([task dueDate] != nil &&
												 [now compare:[task dueDate]] == NSOrderedDescending);
						prefixStr = mutableAttrStrWithAttrs(((useAlertBullet)?prefixStrBulletAlert:prefixStrBullet), getBulletStringAttributes(useAlertBullet));
					}
					else
						prefixStr = MUTABLE_ATTR_STR(getPropSeparatorStr(printedProps+1));
					
					NSMutableAttributedString *thisOutput = kEmptyMutableAttributedString;
					[thisOutput appendAttributedString:prefixStr];
					[thisOutput appendAttributedString:thisPropStr];
					
					if (printedProps == 0)
						[thisOutput addAttributes:getFirstLineStringAttributes() range:NSMakeRange(0,[[thisOutput string] length])];
					
					addToOutputBuffer(thisOutput);
					
					printedProps++;
				}
			}
		}
		
		addToOutputBuffer(MUTABLE_ATTR_STR(@"\n"));
		
		printedItems++;
	}
}





// prints a bunch of sections each of which has a title and some calendar
// items.
// each object in the sections array must be an NSDictionary with keys
// sectionTitle (NSString) and sectionItems (NSArray of CalCalendarItems.)
void printItemSections(NSArray *sections, int printOptions)
{
	BOOL titlePrintedForCurrentSection;
	BOOL currentIsFirstPrintedSection = YES;
	
	NSDictionary *sectionDict;
	for (sectionDict in sections)
	{
		if (maxPrintedItems > 0 && maxPrintedItems <= printedItems)
			continue;
		
		titlePrintedForCurrentSection = NO;
		
		NSString *sectionTitle = [sectionDict objectForKey:kSectionDictKey_title];
		NSArray *sectionItems = [sectionDict objectForKey:kSectionDictKey_items];
		
		CalCalendarItem *item;
		for (item in sectionItems)
		{
			if (!titlePrintedForCurrentSection)
			{
				if (!currentIsFirstPrintedSection)
					addToOutputBuffer(MUTABLE_ATTR_STR(@"\n"));
				
				NSMutableAttributedString *thisOutput = MUTABLE_ATTR_STR(strConcat(sectionTitle, @":", sectionSeparatorStr, @"\n", nil));
				
				[thisOutput addAttributes:getSectionTitleStringAttributes(sectionTitle) range:NSMakeRange(0,[[thisOutput string] length])];
				
				addToOutputBuffer(thisOutput);
				
				titlePrintedForCurrentSection = YES;
				currentIsFirstPrintedSection = NO;
			}
			
			if ([item isKindOfClass:[CalEvent class]])
			{
				NSCalendarDate *contextDay = [sectionDict objectForKey:kSectionDictKey_eventsContextDay];
				if (contextDay == nil)
					contextDay = now;
				printCalEvent((CalEvent*)item, printOptions, contextDay);
			}
			else if ([item isKindOfClass:[CalTask class]])
				printCalTask((CalTask*)item, printOptions);
		}
	}
}








// returns latest version number (as string) if an update is found online,
// or nil if no update was found. on error, errorStr will be != NULL and
// contain an error message.
NSString* latestUpdateVersionOnServer(NSString** errorStr)
{
	NSURL *url = kVersionCheckURL;
	NSURLRequest *request = [NSURLRequest
		requestWithURL:url
		cachePolicy:NSURLRequestReloadIgnoringCacheData
		timeoutInterval:kVersionCheckTimeout
		];
	
	NSHTTPURLResponse *response;
	NSError *error;
	[NSURLConnection
		sendSynchronousRequest:request
		returningResponse:&response
		error:&error
		];
	
	if (error == nil && response != nil)
	{
		NSInteger statusCode = [response statusCode];
		if (statusCode >= 400)
		{
			if (errorStr != NULL)
				*errorStr = [
					NSString
					stringWithFormat:@"HTTP connection failed. Status code %d: \"%@\"",
						statusCode,
						[NSHTTPURLResponse localizedStringForStatusCode:statusCode]
					];
			return nil;
		}
		else
		{
			NSString *latestVersionString = [[response allHeaderFields] valueForKey:kVersionCheckHeaderName];
			NSString *currentVersionString = versionNumber();
			
			if (latestVersionString == nil)
			{
				if (errorStr != NULL)
					*errorStr = @"Error reading latest version number from HTTP header field.";
				return nil;
			}
			else
			{
				if (versionNumberCompare(currentVersionString, latestVersionString) == NSOrderedAscending)
					return latestVersionString;
			}
		}
	}
	else
	{
		if (errorStr != NULL)
			*errorStr = [
				NSString
				stringWithFormat:@"Connection failed. Error: - %@ %@",
					[error localizedDescription],
					[[error userInfo] objectForKey:NSErrorFailingURLStringKey]
				];
		return nil;
	}
	
	return nil;
}








int main(int argc, char *argv[])
{
	NSAutoreleasePool *autoReleasePool = [[NSAutoreleasePool alloc] init];
	
	
	stdoutBuffer = kEmptyMutableAttributedString;
	
	
	// set current datetime and day representations into globals
	now = [NSCalendarDate calendarDate];
	today = [NSCalendarDate
		dateWithYear:[now yearOfCommonEra]
		month:[now monthOfYear]
		day:[now dayOfMonth]
		hour:0 minute:0 second:0
		timeZone:[now timeZone]
		];
	
	
	ansiEscapeHelper = [[[ANSIEscapeHelper alloc] init] autorelease];
	
	
	// default localization strings (english)
	defaultStringsDict = [NSDictionary dictionaryWithObjectsAndKeys:
		@"title",			@"title",
		@"location",		@"location",
		@"notes", 			@"notes",
		@"url", 			@"url",
		@"due",		 		@"dueDate",
		@"no due date",		@"noDueDate",
		@"priority", 		@"priority",
		@"%@'s Birthday",	@"someonesBirthday",
		@"My Birthday",		@"myBirthday",
		@"today", 					@"today",
		@"tomorrow", 				@"tomorrow",
		@"yesterday", 				@"yesterday",
		@"day before yesterday",	@"dayBeforeYesterday",
		@"day after tomorrow",		@"dayAfterTomorrow",
		@"%d days ago",				@"xDaysAgo",
		@"%d days from now",		@"xDaysFromNow",
		@"this week",				@"thisWeek",
		@"last week",				@"lastWeek",
		@"next week",				@"nextWeek",
		@"%d weeks ago",			@"xWeeksAgo",
		@"%d weeks from now",		@"xWeeksFromNow",
		@"high",		@"high",
		@"medium",		@"medium",
		@"low",			@"low",
		nil
		];
	
	// default formatting for different output elements
	defaultFormattingConfigDict = [NSDictionary dictionaryWithObjectsAndKeys:
		@"cyan",		 		@"datetimeName",
		@"yellow",		 		@"datetimeValue",
		@"",		 	 		@"titleValue",
		@"cyan", 	 			@"notesName",
		@"", 		 			@"notesValue",
		@"cyan", 		 		@"urlName",
		@"", 			 		@"urlValue",
		@"cyan", 		 		@"locationName",
		@"", 		 			@"locationValue",
		@"cyan", 		 		@"dueDateName",
		@"", 			 		@"dueDateValue",
		@"cyan", 	 			@"priorityName",
		@"", 		 			@"priorityValue",
		@"red",		 			@"priorityValueHigh",
		@"yellow",	 			@"priorityValueMedium",
		@"green",				@"priorityValueLow",
		@"blue", 				@"sectionTitle",
		@"bold",				@"firstItemLine",
		@"", 					@"bullet",
		@"red,bold",			@"alertBullet",
		nil
		];
	
	
	// variables for arguments
	NSString *arg_output = nil;
	BOOL arg_separateByCalendar = NO;
	BOOL arg_separateByDate = NO;
	NSArray *arg_includeCals = nil;
	NSArray *arg_excludeCals = nil;
	BOOL arg_updatesCheck = NO;
	BOOL arg_printVersion = NO;
	BOOL arg_includeOnlyEventsFromNowOn = NO;
	BOOL arg_useFormatting = NO;
	BOOL arg_noCalendarNames = NO;
	NSString *arg_strEncoding = nil;
	NSString *arg_propertyOrderStr = nil;
	NSString *arg_propertySeparatorsStr = nil;
	
	BOOL arg_output_is_uncompletedTasks = NO;
	BOOL arg_output_is_eventsToday = NO;
	BOOL arg_output_is_eventsNow = NO;
	BOOL arg_output_is_eventsFromTo = NO;
	NSString *arg_eventsFrom = nil;
	NSString *arg_eventsTo = nil;
	
	
	
	NSString *configFilePath = nil;
	NSString *L10nFilePath = nil;
	
	// read user arguments for specifying paths to the config and
	// localization files before reading any other arguments (we
	// want to load the config first and then read the arguments
	// so that the arguments could override whatever is set in
	// the config. the localization stuff is just along for the
	// ride (it's good friends with the config stuff and I don't
	// have the heart to separate them))
	int i;
	for (i = 0; i < argc; i++)
	{
		if (((strcmp(argv[i], "-cf") == 0) || (strcmp(argv[i], "--configFile") == 0)) && (i+1 < argc))
		{
			configFilePath = [[NSString stringWithCString:argv[i+1] encoding:NSUTF8StringEncoding] stringByExpandingTildeInPath];
			if ([configFilePath length] > 0)
			{
				BOOL userSpecifiedConfigFileIsDir;
				BOOL userSpecifiedConfigFileExists = [[NSFileManager defaultManager] fileExistsAtPath:configFilePath isDirectory:&userSpecifiedConfigFileIsDir];
				if (!userSpecifiedConfigFileExists)
				{
					NSPrintErr(@"Error: specified configuration file doesn't exist: '%@'\n", configFilePath);
					configFilePath = nil;
				}
				else if (userSpecifiedConfigFileIsDir)
				{
					NSPrintErr(@"Error: specified configuration file is a directory: '%@'\n", configFilePath);
					configFilePath = nil;
				}
			}
		}
		else if (((strcmp(argv[i], "-lf") == 0) || (strcmp(argv[i], "--localizationFile") == 0)) && (i+1 < argc))
		{
			L10nFilePath = [[NSString stringWithCString:argv[i+1] encoding:NSUTF8StringEncoding] stringByExpandingTildeInPath];
			if ([L10nFilePath length] > 0)
			{
				BOOL userSpecifiedL10nFileIsDir;
				BOOL userSpecifiedL10nFileExists = [[NSFileManager defaultManager] fileExistsAtPath:L10nFilePath isDirectory:&userSpecifiedL10nFileIsDir];
				if (!userSpecifiedL10nFileExists)
				{
					NSPrintErr(@"Error: specified localization file doesn't exist: '%@'\n", L10nFilePath);
					L10nFilePath = nil;
				}
				else if (userSpecifiedL10nFileIsDir)
				{
					NSPrintErr(@"Error: specified localization file is a directory: '%@'\n", L10nFilePath);
					L10nFilePath = nil;
				}
			}
		}
	}
	
	
	
	// read and validate general configuration file
	
	configDict = nil;
	if (configFilePath == nil)
		configFilePath = [kConfigFilePath stringByExpandingTildeInPath];
	if (configFilePath != nil && [configFilePath length] > 0)
	{
		BOOL configFileIsDir;
		BOOL configFileExists = [[NSFileManager defaultManager] fileExistsAtPath:configFilePath isDirectory:&configFileIsDir];
		if (configFileExists && !configFileIsDir)
		{
			BOOL configFileIsValid = YES;
			
			configDict = [NSDictionary dictionaryWithContentsOfFile:configFilePath];
			
			if (configDict == nil)
			{
				NSPrintErr(@"* Error in configuration file \"%@\":\n  can not recognize file format -- must be a valid property list\n  with a structure specified in the icalBuddyConfig man page.\n", configFilePath);
				configFileIsValid = NO;
			}
			
			if (!configFileIsValid)
				NSPrintErr(@"\nTry running \"man icalBuddyConfig\" to read the relevant documentation\nand \"plutil '%@'\" to validate the\nfile's property list syntax.\n\n", configFilePath);
			else
			{
				NSDictionary *constArgsDict = [configDict objectForKey:@"constantArguments"];
				if (constArgsDict != nil)
				{
					NSArray *allArgKeys = [constArgsDict allKeys];
					if ([allArgKeys containsObject:@"bullet"])
						prefixStrBullet = [constArgsDict objectForKey:@"bullet"];
					if ([allArgKeys containsObject:@"alertBullet"])
						prefixStrBulletAlert = [constArgsDict objectForKey:@"alertBullet"];
					if ([allArgKeys containsObject:@"indent"])
						prefixStrIndent = [constArgsDict objectForKey:@"indent"];
					if ([allArgKeys containsObject:@"sectionSeparator"])
						sectionSeparatorStr = [constArgsDict objectForKey:@"sectionSeparator"];
					if ([allArgKeys containsObject:@"timeFormat"])
						timeFormatStr = [constArgsDict objectForKey:@"timeFormat"];
					if ([allArgKeys containsObject:@"dateFormat"])
						dateFormatStr = [constArgsDict objectForKey:@"dateFormat"];
					if ([allArgKeys containsObject:@"dateTimeSeparator"])
						dateTimeSeparatorStr = [constArgsDict objectForKey:@"dateTimeSeparator"];
					if ([allArgKeys containsObject:@"includeEventProps"])
						includedEventProperties = setFromCommaSeparatedStringTrimmingWhitespace([constArgsDict objectForKey:@"includeEventProps"]);
					if ([allArgKeys containsObject:@"excludeEventProps"])
						excludedEventProperties = setFromCommaSeparatedStringTrimmingWhitespace([constArgsDict objectForKey:@"excludeEventProps"]);
					if ([allArgKeys containsObject:@"includeTaskProps"])
						includedTaskProperties = setFromCommaSeparatedStringTrimmingWhitespace([constArgsDict objectForKey:@"includeTaskProps"]);
					if ([allArgKeys containsObject:@"excludeTaskProps"])
						excludedTaskProperties = setFromCommaSeparatedStringTrimmingWhitespace([constArgsDict objectForKey:@"excludeTaskProps"]);
					if ([allArgKeys containsObject:@"includeCals"])
						arg_includeCals = arrayFromCommaSeparatedStringTrimmingWhitespace([constArgsDict objectForKey:@"includeCals"]);
					if ([allArgKeys containsObject:@"excludeCals"])
						arg_excludeCals = arrayFromCommaSeparatedStringTrimmingWhitespace([constArgsDict objectForKey:@"excludeCals"]);
					if ([allArgKeys containsObject:@"propertyOrder"])
						arg_propertyOrderStr = [constArgsDict objectForKey:@"propertyOrder"];
					if ([allArgKeys containsObject:@"strEncoding"])
						arg_strEncoding = [constArgsDict objectForKey:@"strEncoding"];
					if ([allArgKeys containsObject:@"separateByCalendar"])
						arg_separateByCalendar = [[constArgsDict objectForKey:@"separateByCalendar"] boolValue];
					if ([allArgKeys containsObject:@"separateByDate"])
						arg_separateByDate = [[constArgsDict objectForKey:@"separateByDate"] boolValue];
					if ([allArgKeys containsObject:@"includeOnlyEventsFromNowOn"])
						arg_includeOnlyEventsFromNowOn = [[constArgsDict objectForKey:@"includeOnlyEventsFromNowOn"] boolValue];
					if ([allArgKeys containsObject:@"formatOutput"])
						arg_useFormatting = [[constArgsDict objectForKey:@"formatOutput"] boolValue];
					if ([allArgKeys containsObject:@"noCalendarNames"])
						arg_noCalendarNames = [[constArgsDict objectForKey:@"noCalendarNames"] boolValue];
					if ([allArgKeys containsObject:@"noRelativeDates"])
						displayRelativeDates = ![[constArgsDict objectForKey:@"noRelativeDates"] boolValue];
					if ([allArgKeys containsObject:@"notesNewlinesIndent"])
						notesNewlinesIndentModifier = [[constArgsDict objectForKey:@"notesNewlinesIndent"] integerValue];
					if ([allArgKeys containsObject:@"limitItems"])
						maxPrintedItems = [[constArgsDict objectForKey:@"limitItems"] unsignedIntegerValue];
					if ([allArgKeys containsObject:@"propertySeparators"])
						arg_propertySeparatorsStr = [constArgsDict objectForKey:@"propertySeparators"];
				}
			}
		}
	}
	
	
	
	// read and validate localization configuration file
	
	L10nStringsDict = nil;
	if (L10nFilePath == nil)
		L10nFilePath = [kL10nFilePath stringByExpandingTildeInPath];
	if (L10nFilePath != nil && [L10nFilePath length] > 0)
	{
		BOOL L10nFileIsDir;
		BOOL L10nFileExists = [[NSFileManager defaultManager] fileExistsAtPath:L10nFilePath isDirectory:&L10nFileIsDir];
		if (L10nFileExists && !L10nFileIsDir)
		{
			BOOL L10nFileIsValid = YES;
			
			L10nStringsDict = [NSDictionary dictionaryWithContentsOfFile:L10nFilePath];
			
			if (L10nStringsDict == nil)
			{
				NSPrintErr(@"* Error in localization file \"%@\":\n  can not recognize file format -- must be a valid property list\n  with a structure specified in the icalBuddyLocalization man page.\n", L10nFilePath);
				L10nFileIsValid = NO;
			}
			
			if (L10nFileIsValid)
			{
				// validate some specific keys in localization config
				NSDictionary *L10nKeysRequiringSubstrings = [NSDictionary dictionaryWithObjectsAndKeys:
					@"%d", @"xWeeksFromNow",
					@"%d", @"xWeeksAgo",
					@"%d", @"xDaysAgo",
					@"%d", @"xDaysFromNow",
					@"%@", @"someonesBirthday",
					nil
					];
				NSString *thisKey;
				NSString *thisVal;
				NSString *requiredSubstring;
				for (thisKey in [L10nKeysRequiringSubstrings allKeys])
				{
					requiredSubstring = [L10nKeysRequiringSubstrings objectForKey:thisKey];
					thisVal = [L10nStringsDict objectForKey:thisKey];
					if (thisVal != nil && [thisVal rangeOfString:requiredSubstring].location == NSNotFound)
					{
						NSPrintErr(@"* Error in localization file \"%@\"\n  (key: \"%@\", value: \"%@\"):\n  value must include %@ to indicate position for a variable.\n", L10nFilePath, thisKey, thisVal, requiredSubstring);
						L10nFileIsValid = NO;
					}
				}
			}
			
			if (!L10nFileIsValid)
				NSPrintErr(@"\nTry running \"man icalBuddyLocalization\" to read the relevant documentation\nand \"plutil '%@'\" to validate the\nfile's property list syntax.\n\n", L10nFilePath);
		}
	}
	
	
	
	
	// get arguments
	
	if (argc > 1)
	{
		arg_output = [NSString stringWithCString: argv[argc-1] encoding: NSASCIIStringEncoding];
		
		arg_output_is_uncompletedTasks = [arg_output isEqualToString:@"uncompletedTasks"];
		arg_output_is_eventsToday = [arg_output hasPrefix:@"eventsToday"];
		arg_output_is_eventsNow = [arg_output isEqualToString:@"eventsNow"];
		
		if ([arg_output hasPrefix:@"to:"] && argc > 2)
		{
			NSString *secondToLastArg = [NSString stringWithCString: argv[argc-2] encoding: NSASCIIStringEncoding];
			if ([secondToLastArg hasPrefix:@"eventsFrom:"])
			{
				arg_eventsFrom = [secondToLastArg substringFromIndex:11]; // "eventsFrom:" has 11 chars
				arg_eventsTo = [arg_output substringFromIndex:3]; // "to:" has 3 chars
				arg_output_is_eventsFromTo = YES;
			}
		}
	}
	
	
	
	for (i = 0; i < argc; i++)
	{
		if ((strcmp(argv[i], "-sc") == 0) || (strcmp(argv[i], "--separateByCalendar") == 0))
			arg_separateByCalendar = YES;
		else if ((strcmp(argv[i], "-sd") == 0) || (strcmp(argv[i], "--separateByDate") == 0))
			arg_separateByDate = YES;
		else if ((strcmp(argv[i], "-u") == 0) || (strcmp(argv[i], "--checkForUpdates") == 0))
			arg_updatesCheck = YES;
		else if ((strcmp(argv[i], "-V") == 0) || (strcmp(argv[i], "--version") == 0))
			arg_printVersion = YES;
		else if ((strcmp(argv[i], "-n") == 0) || (strcmp(argv[i], "--includeOnlyEventsFromNowOn") == 0))
			arg_includeOnlyEventsFromNowOn = YES;
		else if ((strcmp(argv[i], "-f") == 0) || (strcmp(argv[i], "--formatOutput") == 0))
			arg_useFormatting = YES;
		else if ((strcmp(argv[i], "-nc") == 0) || (strcmp(argv[i], "--noCalendarNames") == 0))
			arg_noCalendarNames = YES;
		else if ((strcmp(argv[i], "-nrd") == 0) || (strcmp(argv[i], "--noRelativeDates") == 0))
			displayRelativeDates = NO;
		else if (((strcmp(argv[i], "-i") == 0) || (strcmp(argv[i], "--indent") == 0)) && (i+1 < argc))
			prefixStrIndent = [NSString stringWithCString:argv[i+1] encoding:NSUTF8StringEncoding];
		else if (((strcmp(argv[i], "-b") == 0) || (strcmp(argv[i], "--bullet") == 0)) && (i+1 < argc))
			prefixStrBullet = [NSString stringWithCString:argv[i+1] encoding:NSUTF8StringEncoding];
		else if (((strcmp(argv[i], "-ab") == 0) || (strcmp(argv[i], "--alertBullet") == 0)) && (i+1 < argc))
			prefixStrBulletAlert = [NSString stringWithCString:argv[i+1] encoding:NSUTF8StringEncoding];
		else if (((strcmp(argv[i], "-ss") == 0) || (strcmp(argv[i], "--sectionSeparator") == 0)) && (i+1 < argc))
			sectionSeparatorStr = [NSString stringWithCString:argv[i+1] encoding:NSUTF8StringEncoding];
		else if (((strcmp(argv[i], "-tf") == 0) || (strcmp(argv[i], "--timeFormat") == 0)) && (i+1 < argc))
			timeFormatStr = [NSString stringWithCString:argv[i+1] encoding:NSUTF8StringEncoding];
		else if (((strcmp(argv[i], "-df") == 0) || (strcmp(argv[i], "--dateFormat") == 0)) && (i+1 < argc))
			dateFormatStr = [NSString stringWithCString:argv[i+1] encoding:NSUTF8StringEncoding];
		else if (((strcmp(argv[i], "-dts") == 0) || (strcmp(argv[i], "--dateTimeSeparator") == 0)) && (i+1 < argc))
			dateTimeSeparatorStr = [NSString stringWithCString:argv[i+1] encoding:NSUTF8StringEncoding];
		else if (((strcmp(argv[i], "-iep") == 0) || (strcmp(argv[i], "--includeEventProps") == 0)) && (i+1 < argc))
			includedEventProperties = setFromCommaSeparatedStringTrimmingWhitespace([NSString stringWithCString:argv[i+1] encoding:NSUTF8StringEncoding]);
		else if (((strcmp(argv[i], "-eep") == 0) || (strcmp(argv[i], "--excludeEventProps") == 0)) && (i+1 < argc))
			excludedEventProperties = setFromCommaSeparatedStringTrimmingWhitespace([NSString stringWithCString:argv[i+1] encoding:NSUTF8StringEncoding]);
		else if (((strcmp(argv[i], "-itp") == 0) || (strcmp(argv[i], "--includeTaskProps") == 0)) && (i+1 < argc))
			includedTaskProperties = setFromCommaSeparatedStringTrimmingWhitespace([NSString stringWithCString:argv[i+1] encoding:NSUTF8StringEncoding]);
		else if (((strcmp(argv[i], "-etp") == 0) || (strcmp(argv[i], "--excludeTaskProps") == 0)) && (i+1 < argc))
			excludedTaskProperties = setFromCommaSeparatedStringTrimmingWhitespace([NSString stringWithCString:argv[i+1] encoding:NSUTF8StringEncoding]);
		else if (((strcmp(argv[i], "-nni") == 0) || (strcmp(argv[i], "--notesNewlinesIndent") == 0)) && (i+1 < argc))
			notesNewlinesIndentModifier = [[NSString stringWithCString:argv[i+1] encoding:NSUTF8StringEncoding] integerValue];
		else if (((strcmp(argv[i], "-ic") == 0) || (strcmp(argv[i], "--includeCals") == 0)) && (i+1 < argc))
			arg_includeCals = arrayFromCommaSeparatedStringTrimmingWhitespace([NSString stringWithCString:argv[i+1] encoding:NSUTF8StringEncoding]);
		else if (((strcmp(argv[i], "-ec") == 0) || (strcmp(argv[i], "--excludeCals") == 0)) && (i+1 < argc))
			arg_excludeCals = arrayFromCommaSeparatedStringTrimmingWhitespace([NSString stringWithCString:argv[i+1] encoding:NSUTF8StringEncoding]);
		else if (((strcmp(argv[i], "-po") == 0) || (strcmp(argv[i], "--propertyOrder") == 0)) && (i+1 < argc))
			arg_propertyOrderStr = [NSString stringWithCString:argv[i+1] encoding:NSUTF8StringEncoding];
		else if ((strcmp(argv[i], "--strEncoding") == 0) && (i+1 < argc))
			arg_strEncoding = [NSString stringWithCString:argv[i+1] encoding:NSUTF8StringEncoding];
		else if (((strcmp(argv[i], "-li") == 0) || (strcmp(argv[i], "--limitItems") == 0)) && (i+1 < argc))
			maxPrintedItems = abs([[NSString stringWithCString:argv[i+1] encoding:NSUTF8StringEncoding] integerValue]);
		else if (((strcmp(argv[i], "-ps") == 0) || (strcmp(argv[i], "--propertySeparators") == 0)) && (i+1 < argc))
			arg_propertySeparatorsStr = [NSString stringWithCString:argv[i+1] encoding:NSUTF8StringEncoding];
	}
	
	
	if (arg_propertyOrderStr != nil)
	{
		// if property order is specified, filter out property names that are not allowed (the allowed
		// ones are all included in the NSArray specified by the kDefaultPropertyOrder macro definition)
		// and then add to the list the omitted property names in the default order
		NSArray *specifiedPropertyOrder = arrayFromCommaSeparatedStringTrimmingWhitespace(arg_propertyOrderStr);
		NSMutableArray *tempPropertyOrder = [NSMutableArray arrayWithCapacity:10];
		[tempPropertyOrder addObjectsFromArray:[specifiedPropertyOrder filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF IN %@", kDefaultPropertyOrder]]];
		for (NSString *thisPropertyInDefaultOrder in kDefaultPropertyOrder)
		{
			if (![tempPropertyOrder containsObject:thisPropertyInDefaultOrder])
				[tempPropertyOrder addObject:thisPropertyInDefaultOrder];
		}
		propertyOrder = tempPropertyOrder;
	}
	else
		propertyOrder = kDefaultPropertyOrder;
	
	
	if (arg_propertySeparatorsStr != nil)
	{
		NSError *propertySeparatorsArgParseError = nil;
		propertySeparators = arrayFromArbitrarilySeparatedString(arg_propertySeparatorsStr, &propertySeparatorsArgParseError);
		if (propertySeparators == nil && propertySeparatorsArgParseError != nil)
		{
			NSPrintErr(
				@"* Invalid value for argument -ps (or --propertySeparators):\n  \"%@\".\n",
				[propertySeparatorsArgParseError localizedDescription]
				);
			NSPrintErr(@"  Make sure you start and end the value with the separator character\n  (like this: -ps \"|first|second|third|\")\n");
		}
	}
	if (propertySeparators == nil || [propertySeparators count] == 0)
		propertySeparators = kDefaultPropertySeparators;
	
	
	if (arg_strEncoding != nil)
	{
		// process provided output string encoding argument
		arg_strEncoding = [arg_strEncoding stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		NSStringEncoding matchedEncoding = 0;
		const NSStringEncoding *availableEncoding = [NSString availableStringEncodings];
		while(*availableEncoding != 0)
		{
			if ([[NSString localizedNameOfStringEncoding: *availableEncoding] isEqualToString:arg_strEncoding])
			{
				matchedEncoding = *availableEncoding;
				break;
			}
			availableEncoding++;
		}
		if (matchedEncoding != 0)
			outputStrEncoding = matchedEncoding;
		else
			NSPrintErr(
				@"\nError: Invalid string encoding argument: \"%@\". Run \"icalBuddy strEncodings\" to see all the possible values. Using default encoding \"%@\".\n\n",
				arg_strEncoding,
				[NSString localizedNameOfStringEncoding: outputStrEncoding]
				);
	}
	
	
	
	// ------------------------------------------------------------------
	// ------------------------------------------------------------------
	// print version and exit
	// ------------------------------------------------------------------
	if (arg_printVersion)
	{
		NSPrint(@"%@\n", versionNumber());
	}
	// ------------------------------------------------------------------
	// ------------------------------------------------------------------
	// check for updates
	// ------------------------------------------------------------------
	else if (arg_updatesCheck)
	{
		NSPrint(@"Checking for updates... ");
		
		NSString *versionCheckErrorStr = nil;
		NSString *latestVersionStr = latestUpdateVersionOnServer(&versionCheckErrorStr);
		NSString *currentVersionStr = versionNumber();
		
		if (latestVersionStr == nil && versionCheckErrorStr != nil)
			NSPrintErr(@"...%@", versionCheckErrorStr);
		else
		{
			if (latestVersionStr == nil)
				NSPrint(@"...you're up to date! (current & latest: %@)\n\n", currentVersionStr);
			else
			{
				NSPrint(@"...update found! (latest: %@  current: %@)\n\n", latestVersionStr, currentVersionStr);
				NSPrint(
					@"Navigate to the following URL to see the release notes and download the latest version:\n\n%@?currentversion=%@\n\n",
					kAppSiteURLPrefix, currentVersionStr
					);
				char inputChar;
				while(inputChar != 'y' && inputChar != 'n' && inputChar != 'Y' && inputChar != 'N' && inputChar != '\n')
				{
					NSPrint(@"Do you want to navigate to this URL now? [y/n] ");
					scanf("%s&*c",&inputChar);
				}
				
				if (inputChar == 'y' || inputChar == 'Y')
				{
					[[NSWorkspace sharedWorkspace]
						openURL:[
							NSURL
							URLWithString:[
								NSString
								stringWithFormat: @"%@?currentversion=%@",
									kAppSiteURLPrefix, currentVersionStr
							]
						]
						];
				}
			}
		}
	}
	// ------------------------------------------------------------------
	// ------------------------------------------------------------------
	// print possible values for the string encoding argument and exit
	// ------------------------------------------------------------------
	else if ([arg_output isEqualToString:@"strEncodings"])
	{
		NSPrint(@"\nAvailable String encodings (you can use one of these\nas an argument to the --strEncoding option):\n\n");
		const NSStringEncoding *availableEncoding = [NSString availableStringEncodings];
		while(*availableEncoding != 0)
		{
			NSPrint(@"%@\n", [NSString localizedNameOfStringEncoding: *availableEncoding]);
			availableEncoding++;
		}
		NSPrint(@"\n");
	}
	// ------------------------------------------------------------------
	// ------------------------------------------------------------------
	// print all calendars
	// ------------------------------------------------------------------
	else if ([arg_output isEqualToString:@"calendars"])
	{
		NSArray *allCalendars = [[CalCalendarStore defaultCalendarStore] calendars];
		
		CalCalendar *cal;
		for (cal in allCalendars)
		{
			NSPrint(@"* %@\n  uid: %@\n", [cal title], [cal uid]);
		}
	}
	// ------------------------------------------------------------------
	// ------------------------------------------------------------------
	// open config file for editing
	// ------------------------------------------------------------------
	else if ([arg_output hasPrefix:@"editConfig"])
	{
		configFilePath = [kConfigFilePath stringByExpandingTildeInPath];
		BOOL configFileIsDir;
		BOOL configFileExists = [[NSFileManager defaultManager] fileExistsAtPath:configFilePath isDirectory:&configFileIsDir];
		
		if (!configFileExists)
		{
			[kConfigFileStub writeToFile:configFilePath atomically:YES];
			NSPrint(@"Configuration file did not exist; it has now been created.\n");
		}
		
		if (configFileIsDir)
		{
			NSPrintErr(
				@"There seems to be a directory where the configuration\nfile should be: %@\nCan not open configuration file.\n",
				configFilePath
				);
		}
		else
		{
			if ([arg_output hasSuffix:@"CLI"])
			{
				NSString *foundEditorPath = nil;
				
				NSMutableArray *preferredEditors = [NSMutableArray arrayWithObjects:@"vim", @"vi", @"nano", @"pico", @"emacs", @"ed", nil];
				NSString *pathEnvironmentVariable = [[[NSProcessInfo processInfo] environment] objectForKey:@"PATH"];
				NSString *editorEnvironmentVariable = [[[NSProcessInfo processInfo] environment] objectForKey:@"EDITOR"];
				
				if (editorEnvironmentVariable != nil)
				{
					if ([[NSFileManager defaultManager] isExecutableFileAtPath:editorEnvironmentVariable])
						foundEditorPath = editorEnvironmentVariable;
					else
					{
						[preferredEditors removeObject:[editorEnvironmentVariable lastPathComponent]];
						[preferredEditors insertObject:[editorEnvironmentVariable lastPathComponent] atIndex:0];
					}
				}
				
				if (foundEditorPath == nil && pathEnvironmentVariable != nil)
				{
					NSArray *separatePaths = [pathEnvironmentVariable componentsSeparatedByString:@":"];
					NSString *thisFullEditorPathCandidate;
					NSString *thisEditor;
					for (thisEditor in preferredEditors)
					{
						NSString *thisPath;
						for (thisPath in separatePaths)
						{
							thisFullEditorPathCandidate = strConcat(thisPath, @"/", thisEditor, nil);
							if ([[NSFileManager defaultManager] isExecutableFileAtPath:thisFullEditorPathCandidate])
							{
								foundEditorPath = thisFullEditorPathCandidate;
								break;
							}
						}
						if (foundEditorPath != nil)
							break;
					}
				}
				
				if (foundEditorPath != nil)
				{
					NSPrint(
						@"Opening config file for editing with %@ -- press\nany key to continue or Ctrl-C to cancel.\n",
						foundEditorPath
						);
					if (system("read") == 0)
						system([strConcat(@"'", foundEditorPath, @"' '", configFilePath, @"'", nil) UTF8String]);
				}
				else
				{
					NSPrintErr(
						@"Error: Can not find or execute any of the following\neditors in your $PATH: %@\n",
						[preferredEditors componentsJoinedByString:@", "]
						);
				}
			}
			else
			{
				if ([[NSWorkspace sharedWorkspace] fullPathForApplication:kPropertyListEditorAppName] != nil)
				{
					NSPrint(@"Opening configuration file with the Property List\nEditor application.\n");
					[[NSWorkspace sharedWorkspace] openFile:configFilePath withApplication:kPropertyListEditorAppName];
				}
				else
				{
					NSPrint(@"Opening configuration file with the default application\nassociated with the property list type.\n");
					[[NSWorkspace sharedWorkspace] openFile:configFilePath];
				}
			}
		}
	}
	// ------------------------------------------------------------------
	// ------------------------------------------------------------------
	// print events or tasks
	// ------------------------------------------------------------------
	else if (arg_output_is_eventsToday || arg_output_is_eventsNow || arg_output_is_eventsFromTo || arg_output_is_uncompletedTasks)
	{
		BOOL printingEvents = (arg_output_is_eventsToday || arg_output_is_eventsNow || arg_output_is_eventsFromTo);
		BOOL printingAlsoPastEvents = (arg_output_is_eventsFromTo);
		BOOL printingTasks = arg_output_is_uncompletedTasks;
		
		// get all calendars
		NSMutableArray *allCalendars = [NSMutableArray arrayWithCapacity:10];
		[allCalendars addObjectsFromArray: [[CalCalendarStore defaultCalendarStore] calendars]];
		
		// filter calendars to use:
		// - first include what has been specified to be included,
		// - then exclude what has been specified to be excluded
		if (arg_includeCals != nil)
			[allCalendars filterUsingPredicate: [NSPredicate predicateWithFormat:@"(uid IN %@) OR (title IN %@)", arg_includeCals, arg_includeCals]];
		if (arg_excludeCals != nil)
			[allCalendars filterUsingPredicate: [NSPredicate predicateWithFormat:@"(NOT(uid IN %@)) AND (NOT(title IN %@))", arg_excludeCals, arg_excludeCals]];
		
		int tasks_printOptions = PRINT_OPTION_NONE;
		int events_printOptions = PRINT_OPTION_NONE;
		NSArray *uncompletedTasks = nil;
		NSArray *eventsArr = nil;
		
		NSCalendarDate *eventsDateRangeStart = nil;
		NSCalendarDate *eventsDateRangeEnd = nil;
		NSUInteger eventsDateRangeDaysSpan = 0;
		
		// prepare to print events
		if (printingEvents)
		{
			// default print options
			events_printOptions = 
				PRINT_OPTION_SINGLE_DAY | 
				(arg_noCalendarNames ? PRINT_OPTION_CALENDAR_AGNOSTIC : PRINT_OPTION_NONE);
			
			// get start and end dates for predicate
			if (arg_output_is_eventsToday)
			{
				eventsDateRangeStart = [NSCalendarDate dateWithYear:[now yearOfCommonEra] month:[now monthOfYear] day:[now dayOfMonth] hour:0 minute:0 second:0 timeZone:[now timeZone]];
				eventsDateRangeEnd = [NSCalendarDate dateWithYear:[now yearOfCommonEra] month:[now monthOfYear] day:[now dayOfMonth] hour:23 minute:59 second:59 timeZone:[now timeZone]];
			}
			else if (arg_output_is_eventsNow)
			{
				eventsDateRangeStart = now;
				eventsDateRangeEnd = now;
			}
			else if (arg_output_is_eventsFromTo)
			{
				eventsDateRangeStart = [NSCalendarDate dateWithString:arg_eventsFrom];
				eventsDateRangeEnd = [NSCalendarDate dateWithString:arg_eventsTo];
				
				if (eventsDateRangeStart == nil)
				{
					NSPrintErr(@"Error: invalid start date: '%@'\nDates must be specified in the format: \"YYYY-MM-DD HH:MM:SS ±HHMM\"\n\n", arg_eventsFrom);
					return(0);
				}
				else if (eventsDateRangeEnd == nil)
				{
					NSPrintErr(@"Error: invalid end date: '%@'\nDates must be specified in the format: \"YYYY-MM-DD HH:MM:SS ±HHMM\"\n\n", arg_eventsTo);
					return(0);
				}
				
				if ([eventsDateRangeStart compare:eventsDateRangeEnd] == NSOrderedDescending)
				{
					// start date occurs before end date --> swap them
					NSCalendarDate *tempSwapDate = eventsDateRangeStart;
					eventsDateRangeStart = eventsDateRangeEnd;
					eventsDateRangeEnd = tempSwapDate;
				}
				
				events_printOptions &= ~PRINT_OPTION_SINGLE_DAY;
			}
			NSCAssert((eventsDateRangeStart != nil && eventsDateRangeEnd != nil), @"start or end date is nil");
			
			// expand end date if NUM in "eventsToday+NUM" is specified
			if (arg_output_is_eventsToday)
			{
				NSRange arg_output_plusSymbolRange = [arg_output rangeOfString:@"+"];
				if (arg_output_plusSymbolRange.location != NSNotFound)
				{
					NSInteger daysToAddToRange = [[arg_output substringFromIndex:(arg_output_plusSymbolRange.location+arg_output_plusSymbolRange.length)] intValue];
					eventsDateRangeEnd = [eventsDateRangeEnd dateByAddingYears:0 months:0 days:daysToAddToRange hours:0 minutes:0 seconds:0];
					events_printOptions &= ~PRINT_OPTION_SINGLE_DAY;
				}
			}
			
			
			eventsDateRangeDaysSpan = [[[NSCalendar currentCalendar]
				components:NSDayCalendarUnit
				fromDate:eventsDateRangeStart
				toDate:eventsDateRangeEnd
				options:0
				] day];
			
			
			// make predicate for getting all events between start and end dates + use it to get the events
			NSPredicate *eventsPredicate = [CalCalendarStore
				eventPredicateWithStartDate:((arg_includeOnlyEventsFromNowOn)?now:eventsDateRangeStart)
				endDate:eventsDateRangeEnd
				calendars:allCalendars
				];
			eventsArr = [[CalCalendarStore defaultCalendarStore] eventsWithPredicate:eventsPredicate];
		}
		// prepare to print tasks
		else if (printingTasks)
		{
			// make predicate for uncompleted tasks in all calendars and use it to get the tasks
			NSPredicate *uncompletedTasksPredicate = [CalCalendarStore taskPredicateWithUncompletedTasks:allCalendars];
			uncompletedTasks = [[CalCalendarStore defaultCalendarStore] tasksWithPredicate:uncompletedTasksPredicate];
			
			// sort the tasks by priority
			uncompletedTasks = [uncompletedTasks sortedArrayUsingFunction:prioritySort context:NULL];
			
			// default print options
			tasks_printOptions = (arg_noCalendarNames ? PRINT_OPTION_CALENDAR_AGNOSTIC : PRINT_OPTION_NONE);
		}
		
		
		// print the items
		if (arg_separateByCalendar)
		{
			NSMutableArray *byCalendarSections = [NSMutableArray arrayWithCapacity:[allCalendars count]];
			
			CalCalendar *cal;
			for (cal in allCalendars)
			{
				NSMutableArray *thisCalendarItems = [NSMutableArray arrayWithCapacity:((printingEvents)?[eventsArr count]:[uncompletedTasks count])];
				
				if (printingEvents)
					[thisCalendarItems addObjectsFromArray:eventsArr];
				else if (printingTasks)
					[thisCalendarItems addObjectsFromArray:uncompletedTasks];
				
				[thisCalendarItems filterUsingPredicate:[NSPredicate predicateWithFormat:@"calendar.uid == %@", [cal uid]]];
				
				if (thisCalendarItems != nil && [thisCalendarItems count] > 0)
					[byCalendarSections addObject:[NSDictionary dictionaryWithObjectsAndKeys:
						thisCalendarItems, kSectionDictKey_items,
						[cal title], kSectionDictKey_title,
						nil
					]];
			}
			
			int thisPrintOptions = (printingEvents) ? events_printOptions : tasks_printOptions;
			printItemSections(byCalendarSections, (thisPrintOptions | PRINT_OPTION_CALENDAR_AGNOSTIC));
		}
		else if (arg_separateByDate)
		{
			NSMutableArray *byDateSections = [NSMutableArray arrayWithCapacity:[eventsArr count]];
			
			// keys: NSDates (representing *days* to use as sections),
			// values: NSArrays of CalCalendarItems that match those days
			NSMutableDictionary *allDays = [NSMutableDictionary dictionaryWithCapacity:[eventsArr count]];
			
			if (printingEvents)
			{
				// fill allDays using event start dates' days and all spanned days thereafter
				// if the event spans multiple days
				CalEvent *anEvent;
				for (anEvent in eventsArr)
				{
					// calculate anEvent's days span and limit it to the range of days we
					// want displayed
					
					NSUInteger anEventDaysSpan = [[[NSCalendar currentCalendar]
						components:NSDayCalendarUnit
						fromDate:[anEvent startDate]
						toDate:[anEvent endDate]
						options:0
						] day];
					
					// the previous method call returns day spans that are one day too long for
					// all-day events so in those cases we'll subtract one
					if ([anEvent isAllDay] && anEventDaysSpan > 0)
						anEventDaysSpan--;
					
					NSUInteger rangeStartToAnEventStartDaysSpan = [[[NSCalendar currentCalendar]
						components:NSDayCalendarUnit
						fromDate:eventsDateRangeStart
						toDate:[anEvent startDate]
						options:0
						] day];
					
					NSUInteger daySpanLeftInRange = eventsDateRangeDaysSpan - rangeStartToAnEventStartDaysSpan;
					anEventDaysSpan = MIN(daySpanLeftInRange, anEventDaysSpan);
					
					
					NSCalendarDate *thisEventStartDate = [[anEvent startDate] dateWithCalendarFormat:nil timeZone:nil];
					
					NSUInteger i;
					for (i = 0; i <= anEventDaysSpan; i++)
					{
						NSCalendarDate *thisEventStartDatePlusi = [thisEventStartDate
							dateByAddingYears:0 months:0 days:i hours:0 minutes:0 seconds:0
							];
						
						NSCalendarDate *dayToAdd = [NSCalendarDate
							dateWithYear:[thisEventStartDatePlusi yearOfCommonEra]
							month:[thisEventStartDatePlusi monthOfYear]
							day:[thisEventStartDatePlusi dayOfMonth]
							hour:0 minute:0 second:0
							timeZone:[thisEventStartDatePlusi timeZone]
							];
						
						NSComparisonResult dayToAddToNowComparisonResult = [dayToAdd compare:today];
						
						if (printingAlsoPastEvents ||
							dayToAddToNowComparisonResult == NSOrderedDescending ||
							dayToAddToNowComparisonResult == NSOrderedSame ||
							datesRepresentSameDay(now, dayToAdd)
							)
						{
							if (![[allDays allKeys] containsObject:dayToAdd])
								[allDays setObject:[NSMutableArray arrayWithCapacity:20] forKey:dayToAdd];
							
							NSMutableArray *dayToAddEvents = [allDays objectForKey:dayToAdd];
							NSCAssert((dayToAddEvents != nil), @"dayToAddEvents is nil");
							[dayToAddEvents addObject:anEvent];
						}
					}
				}
			}
			else if (printingTasks)
			{
				// fill allDays using task due dates' days
				CalTask *aTask;
				for (aTask in uncompletedTasks)
				{
					id thisDayKey = nil;
					if ([aTask dueDate] != nil)
					{
						NSCalendarDate *thisTaskDueDate = [[aTask dueDate] dateWithCalendarFormat:nil timeZone:nil];
						NSCalendarDate *thisDueDay = [NSCalendarDate
							dateWithYear:[thisTaskDueDate yearOfCommonEra]
							month:[thisTaskDueDate monthOfYear]
							day:[thisTaskDueDate dayOfMonth]
							hour:0 minute:0 second:0
							timeZone:[thisTaskDueDate timeZone]
							];
						thisDayKey = thisDueDay;
					}
					else
						thisDayKey = [NSNull null]; // represents "no due date"
					
					if (![[allDays allKeys] containsObject:thisDayKey])
						[allDays setObject:[NSMutableArray arrayWithCapacity:20] forKey:thisDayKey];
					
					NSMutableArray *thisDayTasks = [allDays objectForKey:thisDayKey];
					NSCAssert((thisDayTasks != nil), @"thisDayTasks is nil");
					[thisDayTasks addObject:aTask];
				}
				
			}
			
			// sort the dates and leave NSNull ("no due date") at the bottom if it exists
			NSMutableArray *allDaysArr = [NSMutableArray arrayWithCapacity:[[allDays allKeys] count]];
			[allDaysArr addObjectsFromArray:[allDays allKeys]];
			[allDaysArr removeObjectIdenticalTo:[NSNull null]];
			[allDaysArr sortUsingSelector:@selector(compare:)];
			if ([allDays objectForKey:[NSNull null]] != nil)
				[allDaysArr addObject:[NSNull null]];
			
			id aDayKey;
			for (aDayKey in allDaysArr)
			{
				NSArray *thisSectionItems = [allDays objectForKey:aDayKey];
				NSCAssert((thisSectionItems != nil), @"thisSectionItems is nil");
				NSMutableDictionary *thisSectionDict = [NSMutableDictionary
					dictionaryWithObject:thisSectionItems
					forKey:kSectionDictKey_items
					];
				
				if (printingEvents && [aDayKey isKindOfClass:[NSCalendarDate class]])
					[thisSectionDict setObject:aDayKey forKey:kSectionDictKey_eventsContextDay];
				
				NSString *thisSectionTitle = nil;
				if ([aDayKey isKindOfClass:[NSCalendarDate class]])
					thisSectionTitle = dateStr(aDayKey, true, false);
				else if ([aDayKey isEqual:[NSNull null]])
					thisSectionTitle = [NSString stringWithFormat:@"(%@)", localizedStr(@"noDueDate")];
				[thisSectionDict setObject:thisSectionTitle forKey:kSectionDictKey_title];
				
				[byDateSections addObject:thisSectionDict];
			}
			
			int thisPrintOptions = (printingEvents) ? events_printOptions : tasks_printOptions;
			printItemSections(byDateSections, (thisPrintOptions | PRINT_OPTION_SINGLE_DAY));
		}
		else // no separation
		{
			if (printingEvents)
			{
				CalEvent *event;
				for (event in eventsArr)
				{
					printCalEvent(event, events_printOptions, now);
				}
			}
			else if (printingTasks)
			{
				CalTask *task;
				for (task in uncompletedTasks)
				{
					printCalTask(task, tasks_printOptions);
				}
			}
		}
	}
	// ------------------------------------------------------------------
	// ------------------------------------------------------------------
	else
	{
		NSPrint(@"\n");
		NSPrint(@"USAGE: %@ [options] <command>\n", [[NSString stringWithCString:argv[0] encoding:NSUTF8StringEncoding] lastPathComponent]);
		NSPrint(@"\n");
		NSPrint(@"<command> specifies the general action icalBuddy should take. Possible values\n");
		NSPrint(@"for it are:\n");
		NSPrint(@"\n");
		NSPrint(@"  'eventsToday'      Print events occurring today\n");
		NSPrint(@"  'eventsToday+NUM'  Print events occurring between today and NUM days into\n");
		NSPrint(@"                     the future\n");
		NSPrint(@"  'eventsNow'        Print events occurring at present time\n");
		NSPrint(@"  'eventsFrom:START to:END'\n");
		NSPrint(@"                     Print events occurring between the two specified dates\n");
		NSPrint(@"                     (START and END), where both are specified in the format:\n");
		NSPrint(@"                     \"YYYY-MM-DD HH:MM:SS ±HHMM\"\n");
		NSPrint(@"  'uncompletedTasks' Print uncompleted tasks\n");
		NSPrint(@"  'calendars'        Print all calendars\n");
		NSPrint(@"  'strEncodings'     Print all the possible string encodings\n");
		NSPrint(@"  'editConfig'       Open the configuration file for editing in a GUI editor\n");
		NSPrint(@"  'editConfigCLI'    Open the configuration file for editing in a CLI editor\n");
		NSPrint(@"\n");
		NSPrint(@"Some of the [options] you can use are:\n");
		NSPrint(@"\n");
		NSPrint(@"-V         Print version number (no <command> needed)\n");
		NSPrint(@"-u         Check for updates to self online (no <command> needed)\n");
		NSPrint(@"-sc,-sd    Separate by calendar or date\n");
		NSPrint(@"-f         Format output\n");
		NSPrint(@"-nc        No calendar names\n");
		NSPrint(@"-nrd       No relative dates\n");
		NSPrint(@"-n         Include only events from now on\n");
		NSPrint(@"-li        Limit items (value required)\n");
		NSPrint(@"-tf,-df    Set time or date format (value required)\n");
		NSPrint(@"-dts       Set date-time separator (value required)\n");
		NSPrint(@"-po        Set property order (value required)\n");
		NSPrint(@"-b         Set bullet point (value required)\n");
		NSPrint(@"-ab        Set alert bullet point (value required)\n");
		NSPrint(@"-i         Set indenting (value required)\n");
		NSPrint(@"-ss        Set section separator (value required)\n");
		NSPrint(@"-ic,-ec    Include or exclude calendars (value required)\n");
		NSPrint(@"-iep,-eep  Include or exclude event properties (value required)\n");
		NSPrint(@"-itp,-etp  Include or exclude task properties (value required)\n");
		NSPrint(@"-cf,-lf    Set config or localization file path (value required)\n");
		NSPrint(@"-nni       Set indentation for new lines in notes (value required)\n");
		NSPrint(@"\n");
		NSPrint(@"See the icalBuddy manual page for a more complete list of\n");
		NSPrint(@"all the possible arguments and their descriptions (just type\n");
		NSPrint(@"'man icalBuddy' into the terminal.)\n");
		NSPrint(@"\n");
		NSPrint(@"Version %@\n", versionNumber());
		NSPrint(@"(c) 2008-2009 Ali Rantakari, http://hasseg.org/icalBuddy\n");
		NSPrint(@"\n");
	}
	
	
	// we've been buffering the output for stdout into an attributed string,
	// now's the time to print out that buffer.
	if ((arg_useFormatting && configDict != nil) &&
		(arg_output_is_eventsToday || arg_output_is_eventsNow ||
		arg_output_is_eventsFromTo || arg_output_is_uncompletedTasks)
		)
	{
		NSDictionary *formattedKeywords = [configDict objectForKey:@"formattedKeywords"];
		if (formattedKeywords != nil)
		{
			// it seems we need to do some search & replace for the output
			// before pushing the buffer to stdout.
			
			NSString *keyword;
			for (keyword in [formattedKeywords allKeys])
			{
				NSDictionary* thisKeywordFormattingAttrs = formattingConfigToStringAttributes([formattedKeywords objectForKey:keyword]);
				
				NSString *cleanStdoutBuffer = [stdoutBuffer string];
				NSRange searchRange = NSMakeRange(0,[stdoutBuffer length]);
				NSRange foundRange = NSMakeRange(NSNotFound,0);
				do
				{
					foundRange = [cleanStdoutBuffer rangeOfString:keyword options:NSLiteralSearch range:searchRange];
					if (foundRange.location != NSNotFound)
					{
						[stdoutBuffer addAttributes:thisKeywordFormattingAttrs range:foundRange];
						searchRange.location = NSMaxRange(foundRange);
						searchRange.length = [stdoutBuffer length]-searchRange.location;
					}
				}
				while (foundRange.location != NSNotFound);
			}
		}
	}
	
	NSString *finalOutput;
	
	if (arg_useFormatting)
		finalOutput = [ansiEscapeHelper ansiEscapedStringWithAttributedString:stdoutBuffer];
	else
		finalOutput = [stdoutBuffer string];
	
	NSPrint(finalOutput);
	
	
	[autoReleasePool release];
	return(0);
}