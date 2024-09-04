/obj/machinery/computer/brigcells
    name = "cell management computer"
    desc = "Используется для дистанционного управления камерами заключённых."
    icon_keyboard = "security_key"
    icon_screen = "cell_monitor"
    use_power = IDLE_POWER_USE
    idle_power_usage = 250
    active_power_usage = 500
    circuit = /obj/item/circuitboard/brigcells
    light_color = LIGHT_COLOR_DARKRED
    req_access = list(ACCESS_BRIG)

/obj/machinery/computer/brigcells/attack_ai(mob/user)
    attack_hand(user)
    ui_interact(user)

/obj/machinery/computer/brigcells/attack_hand(mob/user)
	if(stat & (BROKEN|NOPOWER))
		return

	if(..())
		return TRUE

	if(!allowed(user))
		to_chat(user, span_warning("Access denied."))
		return
	add_fingerprint(user)
	ui_interact(user)

/obj/machinery/computer/brigcells/ui_interact(mob/user, datum/tgui/ui = null)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "BrigCells", "Brig Cell Management")
		ui.open()

/obj/machinery/computer/brigcells/ui_data(mob/user)
	var/list/data = list()
	var/list/timers = list()
	for(var/obj/machinery/door_timer/T in GLOB.celltimers_list)
		var/timer = list()
		timer["Номер камеры"] = T.name
		timer["Заключённый"] = T.occupant
		timer["Обвинения"] = T.crimes
		timer["Сотрудник"] = T.officer
		timer["Срок"] = round(T.timetoset / 10, 1)
		timer["Осталось"] = round(T.timeleft(), 1)
		timer["ref"] = "\ref[T]"
		timers[++timers.len] += timer
	timers = sortByKey(timers, "cell_id")
	data["cells"] = timers
	return data

/obj/machinery/computer/brigcells/ui_act(action, params)
	if (..())
		return FALSE

	if(!allowed(usr))
		to_chat(usr, span_warning("Access denied."))
		playsound(src, pick('sound/machines/button.ogg', 'sound/machines/button_alternate.ogg', 'sound/machines/button_meloboom.ogg'), 20)
		return FALSE

	if (action == "release")
		var/ref = params["ref"]
		var/obj/machinery/door_timer/T = locate(ref)
		if (T)
			T.timer_end()
			T.Radio.autosay("Таймер был вручную остановлен через консоль.", T.name, "Security", list(z))
		return TRUE

	return FALSE
