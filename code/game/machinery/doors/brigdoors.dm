#define CELL_NONE "None"
#define PERMABRIG_TIME 60 //MINUTES

///////////////////////////////////////////////////////////////////////////////////////////////
// Brig Door control displays.
//  Description: This is a controls the timer for the brig doors, displays the timer on itself and
//               has a popup window when used, allowing to set the timer.
//  Code Notes: Combination of old brigdoor.dm code from rev4407 and the status_display.dm code
//  Date: 01/September/2010
//  Programmer: Veryinky
/////////////////////////////////////////////////////////////////////////////////////////////////
/obj/machinery/door_timer
	name = "door timer"
	icon = 'icons/obj/status_display.dmi'
	icon_state = "frame"
	desc = "Дистанционное управление камерой заключения."
	ru_names = list(
		NOMINATIVE = "Таймер",
		GENITIVE = "Таймера",
		DATIVE = "Таймера",
		ACCUSATIVE = "Таймер",
		INSTRUMENTAL = "Таймером",
		PREPOSITIONAL = "Таймера"
	)
	req_access = list(ACCESS_BRIG)
	anchored = TRUE    		// can't pick it up
	density = FALSE			// can walk through it.
	layer = 4 				// above all glasses and other things
	var/id = null     		// id of door it controls.
	var/releasetime = 0		// when world.timeofday reaches it - release the prisoner
	var/timing = 0    		// boolean, true/1 timer is on, false/0 means it's not timing
	var/picture_state		// icon_state of alert picture, if not displaying text/numbers
	var/list/obj/machinery/targets = list()
	var/timetoset = 0		// Used to set releasetime upon starting the timer
	var/obj/item/radio/Radio
	var/printed = 0
	var/datum/data/record/prisoner
	maptext_height = 26
	maptext_width = 32
	maptext_y = -1
	var/occupant = CELL_NONE
	var/crimes = CELL_NONE
	var/time = 0
	var/officer = CELL_NONE
	var/prisoner_name
	var/prisoner_charge
	var/prisoner_time
	var/prisoner_hasrecord = FALSE
	var/prisoner_time_add


/obj/machinery/door_timer/Initialize(mapload)
	. = ..()
	GLOB.celltimers_list += src

	Radio = new /obj/item/radio(src)
	Radio.listening = 0
	Radio.config(list("Security" = 0))
	Radio.follow_target = src

	addtimer(CALLBACK(src, PROC_REF(delayed_update)), 2 SECONDS, TIMER_DELETE_ME)


/obj/machinery/door_timer/Destroy()
	GLOB.celltimers_list -= src
	QDEL_NULL(Radio)
	targets.Cut()
	prisoner = null
	return ..()


/obj/machinery/door_timer/proc/delayed_update()
	for(var/obj/machinery/door/window/brigdoor/brigdoor in GLOB.airlocks)
		if(brigdoor.id == id)
			targets += brigdoor
			INVOKE_ASYNC(brigdoor, TYPE_PROC_REF(/obj/machinery/door, open))

	for(var/obj/machinery/machine in GLOB.machines)
		if(istype(machine, /obj/machinery/flasher))
			var/obj/machinery/flasher/flasher = machine
			if(flasher.id == id)
				targets += flasher

		if(istype(machine, /obj/machinery/treadmill_monitor))
			var/obj/machinery/treadmill_monitor/monitor = machine
			if(monitor.id == id)
				targets += monitor

	for(var/obj/structure/closet/secure_closet/brig/brig_closet in GLOB.closets)
		if(brig_closet.id == id)
			targets += brig_closet

	if(!length(targets))
		stat |= BROKEN
		update_icon(UPDATE_OVERLAYS)


/obj/machinery/door_timer/proc/print_report()
	if(occupant == CELL_NONE || crimes == CELL_NONE)
		return 0

	time = timetoset
	officer = usr.name

	for(var/obj/machinery/computer/prisoner/C in GLOB.prisoncomputer_list)
		var/obj/item/paper/P = new /obj/item/paper(C.loc)
		P.name = "Запись [id] - [occupant] [station_time_timestamp()]"
		P.info =  "<center><b>[id] - Записи Службы Безопасности</b></center><br><hr><br>"
		P.info += {"<center>[station_name()] - Служба Безопасности</center><br>
						<center><small><b>Данные:</b></small></center><br>
						<small><b>Запись создана в:</b>		[station_time_timestamp()]<br>
						<b>Заключённый:</b>		[occupant]<br>
						<b>Срок заключения:</b>		[seconds_to_time(timetoset / 10)]<br>
						<b>Совершённые преступления:</b>	[crimes]<br>
						<b>Задержание произвёл:</b>		[usr.name]<br><hr><br>
						<small>Записи были созданы автоматически путём активации таймера камеры.</small>"}

		playsound(C.loc, "sound/goonstation/machines/printer_dotmatrix.ogg", 50, 1)
		GLOB.cell_logs += P

	var/datum/data/record/G = find_record("name", occupant, GLOB.data_core.general)
	var/prisoner_drank = "unknown"
	var/prisoner_trank = "unknown"
	if(G)
		if(G.fields["rank"])
			prisoner_drank = G.fields["rank"]
		if(G.fields["real_rank"]) // Ignore alt job titles - necessary for lookups
			prisoner_trank = G.fields["real_rank"]

	var/datum/data/record/R = find_security_record("name", occupant)

	var/timetext = seconds_to_time_ru(timetoset / 10)
	var/announcetext = "Заключённый [occupant] ([prisoner_drank]) был заключён на [timetext] за следующие преступления: [crimes]. \
	Задержание произвёл: [usr.name].[R ? "" : " Отсутствуют записи о заключённом, требуется обновление вручную."]"
	Radio.autosay(announcetext, name, "Security")

	// Notify the actual criminal being brigged. This is a QOL thing to ensure they always know the charges against them.
	// Announcing it on radio isn't enough, as they're unlikely to have sec radio.
	notify_prisoner("Вы были заключены на [timetext] за следующие преступления: [crimes]")

	if(prisoner_trank != "unknown" && prisoner_trank != "Civilian")
		SSjobs.notify_dept_head(prisoner_trank, announcetext)

	if(R)
		prisoner = R
		R.fields["criminal"] = SEC_RECORD_STATUS_INCARCERATED
		var/mob/living/carbon/human/M = usr
		var/rank = "UNKNOWN RANK"
		if(istype(M))
			var/obj/item/card/id/I = M.get_id_card()
			if(I)
				rank = I.assignment
		if(!R.fields["comments"] || !islist(R.fields["comments"])) //copied from security computer code because apparently these need to be initialized
			R.fields["comments"] = list()
		R.fields["comments"] += "Автоматически сгенерировано [declent_ru(INSTRUMENTAL)] в [GLOB.current_date_string] [station_time_timestamp()]<BR>Заключён на [seconds_to_time(timetoset / 10)] за следующие преступления: [crimes]. Задержание произвёл: [usr.name] ([rank])."
		update_all_mob_security_hud()
	return 1

/obj/machinery/door_timer/proc/notify_prisoner(notifytext)
	for(var/mob/living/carbon/human/H in range(4, get_turf(src)))
		if(occupant == H.name)
			to_chat(H, "[declent_ru(NOMINATIVE)] сообщает, \"[notifytext]\"")
			return
	atom_say("[declent_ru(NOMINATIVE)] сообщает, \"[occupant]: [notifytext]\"")


//Main door timer loop, if it's timing and time is >0 reduce time by 1.
// if it's less than 0, open door, reset timer
// update the door_timer window and the icon
/obj/machinery/door_timer/process()
	if((stat & (NOPOWER|BROKEN)))
		update_display()
		return PROCESS_KILL
	if(timing)
		if(emagged)
			timer_end()
			return PROCESS_KILL
		if(timeleft() <= 0)
			Radio.autosay("Время заключения истекло. Заключённый освобождён.", name, "Security", list(z))
			occupant = CELL_NONE
			timer_end() // open doors, reset timer, clear status screen
			return PROCESS_KILL
		update_display()
	else
		timer_end()
		return PROCESS_KILL


//Checks to see if there's 1 line or 2, adds text-icons-numbers/letters over display
// Stolen from status_display
/obj/machinery/door_timer/proc/update_display()
	update_icon(UPDATE_OVERLAYS)

	if(stat & (NOPOWER|BROKEN))
		if(maptext)
			maptext = ""
		return

	if(timing)
		var/disp1 = id
		var/timeleft = timeleft()
		var/disp2 = "[add_zero(num2text((timeleft / 60) % 60),2)]:[add_zero(num2text(timeleft % 60), 2)]"
		if(length(disp2) > DISPLAY_CHARS_PER_LINE)
			disp2 = "Error"
		var/new_text = {"<div style="font-size:[DISPLAY_FONT_SIZE];color:[DISPLAY_FONT_COLOR];font:'[DISPLAY_FONT_STYLE]';text-align:center;" valign="top">[uppertext(disp1)]<br>[uppertext(disp2)]</div>"}
		if(maptext != new_text)
			maptext = new_text
	else if(maptext)
		maptext = ""


// has the door power situation changed, if so update icon.
/obj/machinery/door_timer/power_change(forced = FALSE)
	if(!..())
		return
	update_display()


// open/closedoor checks if door_timer has power, if so it checks if the
// linked door is open/closed (by density) then opens it/closes it.

// Closes and locks doors, power check
/obj/machinery/door_timer/proc/timer_start()
	timing = TRUE
	update_display()

	if(stat & (NOPOWER|BROKEN))
		timing = FALSE
		return FALSE

	if(!printed && !print_report())
		timing = FALSE
		return FALSE

	// Set releasetime
	releasetime = world.timeofday + timetoset
	START_PROCESSING(SSmachines, src)

	for(var/obj/machinery/door/window/brigdoor/door in targets)
		if(door.density)
			continue
		INVOKE_ASYNC(door, TYPE_PROC_REF(/obj/machinery/door, close))

	for(var/obj/structure/closet/secure_closet/brig/closet in targets)
		if(closet.broken)
			continue
		if(closet.opened && !closet.close())
			continue
		closet.locked = TRUE
		closet.update_icon()

	for(var/obj/machinery/treadmill_monitor/monitor in targets)
		monitor.total_joules = 0
		monitor.on = TRUE

	return TRUE


// Opens and unlocks doors, power check
/obj/machinery/door_timer/proc/timer_end()
	timing = FALSE
	update_display()

	if(stat & (NOPOWER|BROKEN))
		return FALSE

	// Reset vars
	occupant = CELL_NONE
	crimes = CELL_NONE
	time = 0
	timetoset = 0
	officer = CELL_NONE
	releasetime = 0
	printed = FALSE
	if(prisoner)
		prisoner.fields["criminal"] = SEC_RECORD_STATUS_RELEASED
		update_all_mob_security_hud()
		prisoner = null

	for(var/obj/machinery/door/window/brigdoor/door in targets)
		if(!door.density)
			continue
		INVOKE_ASYNC(door, TYPE_PROC_REF(/obj/machinery/door/window/brigdoor, open))

	for(var/obj/structure/closet/secure_closet/brig/closet in targets)
		if(closet.broken)
			continue
		if(closet.opened)
			continue
		closet.locked = FALSE
		closet.update_icon()

	for(var/obj/machinery/treadmill_monitor/monitor in targets)
		if(!monitor.stat)
			monitor.redeem()
		monitor.on = FALSE

	return TRUE


// Check for releasetime timeleft
/obj/machinery/door_timer/proc/timeleft()
	var/time = releasetime - world.timeofday
	if(time > MIDNIGHT_ROLLOVER / 2)
		time -= MIDNIGHT_ROLLOVER
	if(time < 0)
		return 0
	return time / 10

// Set timetoset
/obj/machinery/door_timer/proc/timeset(seconds)
	timetoset = seconds * 10

	if(timetoset <= 0)
		timetoset = 0

	return

/obj/machinery/door_timer/attack_ai(mob/user)
	ui_interact(user)

/obj/machinery/door_timer/attack_ghost(mob/user)
	ui_interact(user)


/obj/machinery/door_timer/emp_act(severity)
	if((stat & (BROKEN|NOPOWER)) || emagged)
		..(severity)
		return
	if(timing && prob(100 / severity))
		emagged = TRUE
	..(severity)


/obj/machinery/door_timer/emag_act()
	if((stat & (BROKEN|NOPOWER)) || emagged || !timing)
		return
	emagged = TRUE


//Allows humans to use door_timer
//Opens dialog window when someone clicks on door timer
// Allows altering timer and the timing boolean.
// Flasher activation limited to 150 seconds
/obj/machinery/door_timer/attack_hand(mob/user)
	if(..())
		return
	ui_interact(user)

/obj/machinery/door_timer/ui_interact(mob/user, datum/tgui/ui = null)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "BrigTimer", name)
		ui.open()

/obj/machinery/door_timer/ui_static_data(mob/user)
	var/list/data = list()
	data["spns"] = list()
	for(var/mob/living/carbon/human/H in range(4, get_turf(src)))
		if(H.handcuffed)
			data["spns"] += H.name
	return data

/obj/machinery/door_timer/ui_data(mob/user)
	var/list/data = list()
	data["cell_id"] = name
	data["occupant"] = occupant
	data["crimes"] = crimes
	data["brigged_by"] = officer
	data["time_set"] = seconds_to_clock(timetoset / 10)
	data["time_left"] = seconds_to_clock(timeleft())
	data["timing"] = timing
	data["isAllowed"] = allowed(user)
	data["prisoner_name"] = prisoner_name
	data["prisoner_charge"] = prisoner_charge
	data["prisoner_time"] = prisoner_time
	data["prisoner_hasrec"] = prisoner_hasrecord
	data["add_timer"] = prisoner_time_add
	return data

/obj/machinery/door_timer/allowed(mob/user)
	if(user.can_admin_interact())
		return TRUE
	return ..()

/obj/machinery/door_timer/ui_act(action, params)
	if(..())
		return
	if(!allowed(usr))
		to_chat(usr, span_warning("Access denied."))
		return
	. = TRUE

	var/seconds_to_time_ru = (num, single_name, double_name, multiple_name)
		if(!isnum(num) || round(num) != num)
			return double_name
		if(((num % 10) == 1) && ((num % 100) != 11))
			return single_name
		if(((num % 10) in 2 to 4) && !((num % 100) in 12 to 14))
			return double_name
				return

	switch(action)
		if("prisoner_name")
			if(params["prisoner_name"])
				prisoner_name = params["prisoner_name"]
			else
				var/new_name = tgui_input_text(usr, "Имя заключённого:", name, prisoner_name, MAX_NAME_LEN, encode = FALSE)
				if(isnull(new_name))
					return
				prisoner_name = new_name
			if(prisoner_name)
				var/datum/data/record/R = find_security_record("name", prisoner_name)
				if(istype(R))
					prisoner_hasrecord = TRUE
				else
					prisoner_hasrecord = FALSE
		if("prisoner_charge")
			var/new_charge = tgui_input_text(usr, "Обвиняется в:", name, prisoner_charge, encode = FALSE)
			if(isnull(new_charge))
				return
			prisoner_charge = new_charge
		if("prisoner_time")
			var/new_time = tgui_input_number(usr, "Время заключения (в минутах):", name, prisoner_time, PERMABRIG_TIME)
			if(isnull(new_time))
				return
			prisoner_time = new_time
		if("start")
			if(!prisoner_name || !prisoner_charge || !prisoner_time)
				return FALSE
			timeset(prisoner_time * 60)
			occupant = prisoner_name
			crimes = prisoner_charge
			prisoner_name = null
			prisoner_charge = null
			prisoner_time = null
			timer_start()
		if("add_timer")
			if(timing)
				var/add_reason = sanitize(copytext(input(usr, "Причина:", name, "") as text|null, 1, MAX_MESSAGE_LEN))
				if(!add_reason)
					to_chat(usr, span_warning("Необходимо указать причину!"))
					return FALSE
				prisoner_time_add = input(usr, "Время, которое будет добавлено (в минутах):", name, prisoner_time_add) as num|null
				prisoner_time_add = min(max(round(prisoner_time_add), 0), PERMABRIG_TIME)

				if(!prisoner_time_add)
					to_chat(usr, span_warning("Время указывается числом!"))
					return FALSE
				prisoner_time_add = prisoner_time_add MINUTES
				if(timetoset + prisoner_time_add >= PERMABRIG_TIME MINUTES)
					notify_prisoner("Таймер превышает 60 минут. Переместите заключённого в пермабриг!")
					return FALSE
				timetoset = timetoset + prisoner_time_add
				releasetime = releasetime + prisoner_time_add
				Radio.autosay("Время заключения [occupant] было увеличено на [prisoner_time_add / 600] [declension_ru(prisoner_time_add / 600, "минуту", "минуты", "минут")] [addtext]", name, "Security", list(z))
				Radio.autosay("Время заключения [occupant] было увеличен на [prisoner_time_add / 600] [seconds_to_time_ru] [addtext]", name, "Security", list(z))
				notify_prisoner("Ваше время заключения было увеличено на [prisoner_time_add / 600] [declension_ru(prisoner_time_add / 600, "минуту", "минуты", "минут")] [add_reason]")
				var/datum/data/record/R = find_security_record("name", occupant)
				if(istype(R))
					R.fields["comments"] += "Автоматически сгенерировано [declent_ru(INSTRUMENTAL)] в [GLOB.current_date_string] [station_time_timestamp()]. Время заключения увеличено на [prisoner_time_add / 600] [declension_ru(prisoner_time_add / 600, "минуту", "минуты", "минут")] [addtext]"
			else
				. = FALSE
				var/resettext = isobserver(usr) ? "по причине: [reset_reason]." : "сотрудником [usr.name] по причине: [reset_reason]."
		if("restart_timer")
				notify_prisoner("Ваш таймер был перезапущен по причине: [reset_reason].")
				var/reset_reason = tgui_input_text(usr, "Причина перезапуска таймера:", name)
				if(!reset_reason)
					R.fields["comments"] += "Автоматически сгенерировано [declent_ru(INSTRUMENTAL)] в [GLOB.current_date_string] [station_time_timestamp()]. Таймер перезапущен [resettext]"
					return FALSE
				releasetime = world.timeofday + timetoset
				var/resettext = isobserver(usr) ? "по причине: [reset_reason]." : "сотрудником [usr.name] по причине: [reset_reason]."
				Radio.autosay("Таймер заключённого [occupant] был перезапущен [resettext]", name, "Security", list(z))
				notify_prisoner("Ваш таймер был перезапущен по причине: [reset_reason].")
				var/stoptext = isobserver(usr) ? "с помощью консоли управления камерой." : "сотрудником [usr.name]."
				if(istype(R))
					R.fields["comments"] += "Автоматически сгенерировано [declent_ru(INSTRUMENTAL)] в [GLOB.current_date_string] [station_time_timestamp()]. Таймер перезапущен [resettext]"
			else
				. = FALSE
		if("stop")
			if(timing)
					to_chat(usr, span_warning("Флешер перезаряжается!"))
				var/stoptext = isobserver(usr) ? "с помощью консоли управления камерой." : "сотрудником [usr.name]."
				Radio.autosay("Таймер принудительно остановлен [stoptext]", name, "Security", list(z))
			else
				. = FALSE
		if("flash")
			for(var/obj/machinery/flasher/flasher in targets)
				if(flasher.last_flash && (flasher.last_flash + 15 SECONDS) > world.time)
					to_chat(usr, span_warning("Флешер перезаряжается!"))
				else
					flasher.flash()
		else
			. = FALSE


/obj/machinery/door_timer/update_overlays()
	. = ..()
	if(!(stat & NOPOWER) && ((stat & BROKEN) || emagged))
		. += "ai_bsod"


/obj/machinery/door_timer/cell_1
	name = "Cell 1"
	ru_names = list(
		NOMINATIVE = "Камера 1",
		GENITIVE = "Камеры 1",
		DATIVE = "Камеры 1",
		ACCUSATIVE = "Камера 1",
		INSTRUMENTAL = "Камерой 1",
		PREPOSITIONAL = "Камеры 1"
	)
	id = "Cell 1"

/obj/machinery/door_timer/cell_2
	name = "Cell 2"
	ru_names = list(
		NOMINATIVE = "Камера 1",
		GENITIVE = "Камеры 1",
		DATIVE = "Камеры 1",
		ACCUSATIVE = "Камера 1",
		INSTRUMENTAL = "Камерой 1",
		PREPOSITIONAL = "Камеры 1"
	)
	id = "Cell 2"

/obj/machinery/door_timer/cell_3
	name = "Cell 3"
	ru_names = list(
		NOMINATIVE = "Камера 1",
		GENITIVE = "Камеры 1",
		DATIVE = "Камеры 1",
		ACCUSATIVE = "Камера 1",
		INSTRUMENTAL = "Камерой 1",
		PREPOSITIONAL = "Камеры 1"
	)
	id = "Cell 3"

/obj/machinery/door_timer/cell_4
	name = "Cell 4"
	ru_names = list(
		NOMINATIVE = "Камера 1",
		GENITIVE = "Камеры 1",
		DATIVE = "Камеры 1",
		ACCUSATIVE = "Камера 1",
		INSTRUMENTAL = "Камерой 1",
		PREPOSITIONAL = "Камеры 1"
	)
	id = "Cell 4"

/obj/machinery/door_timer/cell_5
	name = "Cell 5"
	ru_names = list(
		NOMINATIVE = "Камера 1",
		GENITIVE = "Камеры 1",
		DATIVE = "Камеры 1",
		ACCUSATIVE = "Камера 1",
		INSTRUMENTAL = "Камерой 1",
		PREPOSITIONAL = "Камеры 1"
	)
	id = "Cell 5"

/obj/machinery/door_timer/cell_6
	name = "Cell 6"
	ru_names = list(
		NOMINATIVE = "Камера 1",
		GENITIVE = "Камеры 1",
		DATIVE = "Камеры 1",
		ACCUSATIVE = "Камера 1",
		INSTRUMENTAL = "Камерой 1",
		PREPOSITIONAL = "Камеры 1"
	)
	id = "Cell 6"

/obj/machinery/door_timer/cell_7
	name = "Cell 7"
	ru_names = list(
		NOMINATIVE = "Камера 1",
		GENITIVE = "Камеры 1",
		DATIVE = "Камеры 1",
		ACCUSATIVE = "Камера 1",
		INSTRUMENTAL = "Камерой 1",
		PREPOSITIONAL = "Камеры 1"
	)
	id = "Cell 7"

/obj/machinery/door_timer/cell_8
	name = "Cell 8"
	ru_names = list(
		NOMINATIVE = "Камера 1",
		GENITIVE = "Камеры 1",
		DATIVE = "Камеры 1",
		ACCUSATIVE = "Камера 1",
		INSTRUMENTAL = "Камерой 1",
		PREPOSITIONAL = "Камеры 1"
	)
	id = "Cell 8"
