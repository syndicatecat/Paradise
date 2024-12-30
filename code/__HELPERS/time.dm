#define MILLISECONDS *0.01

#define DECISECONDS *1 //the base unit all of these defines are scaled by, because byond uses that as a unit of measurement for some fucking reason

// So you can be all 10 SECONDS
#define SECONDS *10

#define MINUTES SECONDS*60

#define HOURS MINUTES*60

#define TICKS *world.tick_lag

#define MS2DS(T) ((T) MILLISECONDS)

#define DS2MS(T) ((T) * 100)

#define SECONDS_TO_LIFE_CYCLES /2

#define DS2TICKS(DS) ((DS)/world.tick_lag)

#define TICKS2DS(T) ((T) TICKS)

#define ROUND_TIME_TEXT(...) ( "[world.time - SSticker.round_start_time > MIDNIGHT_ROLLOVER ? "[round((world.time - SSticker.round_start_time)/MIDNIGHT_ROLLOVER)]:[worldtime2text()]" : worldtime2text()]" )

#define SHIFT_TIME_TEXT(...) ( "[SSticker.round_start_time > MIDNIGHT_ROLLOVER ? "[round(SSticker.round_start_time/MIDNIGHT_ROLLOVER)]:[shifttime2text()]" : shifttime2text()]" )

/* This proc should only be used for world/Topic.
 * If you want to display the time for which dream daemon has been running ("round time") use worldtime2text.
 * If you want to display the canonical station "time" (aka the in-character time of the station) use station_time_timestamp
 */
/proc/classic_worldtime2text(time = world.time)
	time = (SSticker.round_start_time ? (time - SSticker.round_start_time) : (time - world.time))
	return "[round(time / 36000)+12]:[(time / 600 % 60) < 10 ? add_zero(time / 600 % 60, 1) : time / 600 % 60]"

//Returns the world time in english
/proc/worldtime2text()
	return gameTimestamp("hh:mm:ss", world.time)

//Returns the world time in english
/proc/roundtime2text()
	return gameTimestamp("hh:mm:ss", world.time - SSticker.time_game_started)

/proc/shifttime2text()
	return gameTimestamp("hh:mm:ss", world.time - SSticker.round_start_time)

// This is ISO-8601
// If anything that uses this proc shouldn't be ISO-8601, change that thing, not this proc. This is important for logging.
/proc/time_stamp()
	var/date_portion = time2text(world.timeofday, "YYYY-MM-DD")
	var/time_portion = time2text(world.timeofday, "hh:mm:ss")
	return "[date_portion]T[time_portion]"

/proc/gameTimestamp(format = "hh:mm:ss", wtime=null)
	if(wtime == null)
		wtime = world.time
	return time2text(wtime - GLOB.timezoneOffset, format)

/proc/deciseconds_to_time_stamp(deciseconds)
	if(istext(deciseconds))
		deciseconds = text2num(deciseconds)
	var/hour_calc = round(deciseconds / 36000) < 10 ? add_zero(round(deciseconds / 36000), 1) : round(deciseconds / 36000)
	var/minute_calc = round((deciseconds % 36000) / 600) < 10 ? add_zero(round((deciseconds % 36000) / 600), 1) : round((deciseconds % 36000) / 600)
	var/second_calc = round(((deciseconds % 36000) % 600) / 10) < 10 ? add_zero(round(((deciseconds % 36000) % 600) / 10), 1) : round(((deciseconds % 36000) % 600) / 10)

	return "[hour_calc]:[minute_calc]:[second_calc]"

// max hh:mm:ss supported
/proc/timeStampToNum(timestamp)
	var/list/splits = text2numlist(timestamp, ":")
	. = 0
	var/split_len = length(splits)
	for(var/i = 1 to length(splits))
		switch(split_len - i)
			if(2)
				. += splits[i] HOURS
			if(1)
				. += splits[i] MINUTES
			if(0)
				. += splits[i] SECONDS

/* This is used for displaying the "station time" equivelent of a world.time value
 Calling it with no args will give you the current time, but you can specify a world.time-based value as an argument
 - You can use this, for example, to do "This will expire at [station_time_at(world.time + 500)]" to display a "station time" expiration date
   which is much more useful for a player)*/
/proc/station_time(time=world.time, display_only=FALSE)
	return ((((time - SSticker.round_start_time)) + GLOB.gametime_offset) % 864000) - (display_only ? GLOB.timezoneOffset : 0)

/proc/station_time_timestamp(format = "hh:mm:ss", time=world.time)
	return time2text(station_time(time, TRUE), format)

/* Returns 1 if it is the selected month and day */
/proc/isDay(var/month, var/day)
	if(isnum(month) && isnum(day))
		var/MM = text2num(time2text(world.timeofday, "MM")) // get the current month
		var/DD = text2num(time2text(world.timeofday, "DD")) // get the current day
		if(month == MM && day == DD)
			return 1

		// Uncomment this out when debugging!
		//else
			//return 1

//returns timestamp in a sql and ISO 8601 friendly format
/proc/SQLtime()
	return time2text(world.realtime, "YYYY-MM-DD hh:mm:ss")

/**
 * Returns "watch handle" (really just a timestamp :V)
 */
/proc/start_watch()
	return REALTIMEOFDAY

/**
 * Returns number of seconds elapsed.
 * @param wh number The "Watch Handle" from start_watch(). (timestamp)
 */
/proc/stop_watch(wh)
	return round(0.1 * (REALTIMEOFDAY - wh), 0.1)

/proc/numberToMonthName(number)
	return GLOB.month_names.Find(number)

//Take a value in seconds and returns a string of minutes and seconds in the format X minute(s) and X seconds.
/proc/seconds_to_time(var/seconds as num)
	var/numSeconds = seconds % 60
	var/numMinutes = (seconds - numSeconds) / 60
	return "[numMinutes] [declension_ru(numMinutes, "минуту", "минуты", "минут")]"

/proc/seconds_to_time_ru(num, single_name, double_name, multiple_name)
	if(!isnum(num) || round(num) != num)
		return double_name
	if(((num % 10) == 1) && ((num % 100) != 11))
		return single_name
	if(((num % 10) in 2 to 4) && !((num % 100) in 12 to 14))
		return double_name
	return multiple_name

//Take a value in seconds and makes it display like a clock
/proc/seconds_to_clock(var/seconds as num)
	return "[add_zero(num2text((seconds / 60) % 60), 2)]:[add_zero(num2text(seconds % 60), 2)]"

//Takes a value of time in deciseconds.
//Returns a text value of that number in hours, minutes, or seconds.
/proc/DisplayTimeText(time_value)
	var/second = time_value * 0.1
	var/second_adjusted = null
	var/second_rounded = FALSE
	var/minute = null
	var/hour = null
	var/day = null


	if(second >= 60)
		minute = round_down(second / 60)
		second = round(second - (minute * 60), 0.1)
		second_rounded = TRUE
	if(second)	//check if we still have seconds remaining to format, or if everything went into minute.
		second_adjusted = round(second)	//used to prevent '1 seconds' being shown
		if(day || hour || minute)
			if(second_adjusted == 1 && second >= 1)
				second = " и 1 секунду"
			else if(second > 1)
				second = " и [second_adjusted] секунд"
			else	//shows a fraction if seconds is < 1
				if(second_rounded) //no sense rounding again if it's already done
					second = " и [second] секунд"
				else
					second = " и [round(second, 0.1)] секунд"
		else
			if(second_adjusted == 1 && second >= 1)
				second = "1 секунду"
			else if(second > 1)
				second = "[second_adjusted] секунд"
			else
				if(second_rounded)
					second = "[second] секунд"
				else
					second = "[round(second, 0.1)] секунд"
	else
		second = null

	if(!minute)
		return "[second]"
	if(minute >= 60)
		hour = round_down(minute / 60,1)
		minute = (minute - (hour * 60))
	if(minute) //alot simpler from here since you don't have to worry about fractions
		if(minute != 1)
			if((day || hour) && second)
				minute = ", [minute] минут"
			else if((day || hour) && !second)
				minute = " и [minute] минут"
			else
				minute = "[minute] минут"
		else
			if((day || hour) && second)
				minute = ", 1 минуту"
			else if((day || hour) && !second)
				minute = " и 1 минуту"
			else
				minute = "1 минута"
	else
		minute = null

	if(!hour)
		return "[minute][second]"
	if(hour >= 24)
		day = round_down(hour / 24,1)
		hour = (hour - (day * 24))
	if(hour)
		if(hour != 1)
			if(day && (minute || second))
				hour = ", [hour] часов"
			else if(day && (!minute || !second))
				hour = " и [hour] часов"
			else
				hour = "[hour] часов"
		else
			if(day && (minute || second))
				hour = ", 1 час"
			else if(day && (!minute || !second))
				hour = " и 1 час"
			else
				hour = "1 час"
	else
		hour = null

	if(!day)
		return "[hour][minute][second]"
	if(day > 1)
		day = "[day] дня"
	else
		day = "1 день"

	return "[day][hour][minute][second]"

GLOBAL_VAR_INIT(midnight_rollovers, 0)
GLOBAL_VAR_INIT(rollovercheck_last_timeofday, 0)
/proc/update_midnight_rollover()
	if(world.timeofday < GLOB.rollovercheck_last_timeofday) //TIME IS GOING BACKWARDS!
		GLOB.midnight_rollovers++
	GLOB.rollovercheck_last_timeofday = world.timeofday
	return GLOB.midnight_rollovers
