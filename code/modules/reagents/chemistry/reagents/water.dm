/*
// Frankly, this is just for chemicals that are sortof 'watery', which really didn't seem to fit under any other file
// Current chems: Water, Space Lube, Space Cleaner, Blood, Fish Water, Holy water
//
//
*/

GLOBAL_LIST_INIT(diseases_carrier_reagents, list(
			"blood",
			"slimejelly",
			"cryoxadone",
		))

/datum/reagent/water
	name = "Water"
	id = "water"
	description = "A ubiquitous chemical substance that is composed of hydrogen and oxygen."
	reagent_state = LIQUID
	color = "#0064C8" // rgb: 0, 100, 200
	taste_description = "water"
	var/cooling_temperature = 2
	process_flags = ORGANIC | SYNTHETIC
	drink_icon = "glass_clear"
	drink_name = "Glass of Water"
	drink_desc = "The father of all refreshments."
	var/water_temperature = COLD_WATER_TEMPERATURE	// As reagents don't have a temperature value, we'll just use 10 celsius.

/datum/reagent/water/reaction_mob(mob/living/M, method = REAGENT_TOUCH, volume)
	M.water_act(volume, water_temperature, src, method)

/datum/reagent/water/reaction_turf(turf/T, volume)
	T.water_act(volume, water_temperature, src)
	var/obj/effect/acid/A = (locate(/obj/effect/acid) in T)
	if(A)
		A.acid_level = max(A.acid_level - volume*  50, 0)

/datum/reagent/water/reaction_obj(obj/O, volume)
	O.water_act(volume, water_temperature, src)

/datum/reagent/lube
	name = "Space Lube"
	id = "lube"
	description = "Lubricant is a substance introduced between two moving surfaces to reduce the friction and wear between them. giggity."
	reagent_state = LIQUID
	color = "#1BB1AB"
	harmless = TRUE
	taste_description = "cherry"

/datum/reagent/lube/reaction_turf(turf/simulated/T, volume)
	if(volume >= 1 && istype(T))
		T.MakeSlippery(TURF_WET_LUBE, 120 SECONDS)


/datum/reagent/space_cleaner
	name = "Space cleaner"
	id = "cleaner"
	description = "A compound used to clean things. Now with 50% more sodium hypochlorite!"
	reagent_state = LIQUID
	color = "#61C2C2"
	harmless = TRUE
	process_flags = ORGANIC | SYNTHETIC
	taste_description = "floor cleaner"


/datum/reagent/space_cleaner/reaction_obj(obj/O, volume)
	if(iseffect(O))
		var/obj/effect/E = O
		if(E.is_cleanable())
			var/obj/effect/decal/cleanable/blood/B = E
			if(!(istype(B) && B.off_floor))
				qdel(E)
	else
		if(O.simulated)
			O.remove_atom_colour(WASHABLE_COLOUR_PRIORITY)
			var/obj/item/clothing/suit/space/hardsuit/H = O
			if(istype(H) && H.helmet)
				H.helmet.remove_atom_colour(WASHABLE_COLOUR_PRIORITY)
		O.clean_blood()


/datum/reagent/space_cleaner/reaction_turf(turf/T, volume)
	if(volume >= 1)
		var/floor_only = TRUE
		for(var/obj/effect/decal/cleanable/C in T)
			var/obj/effect/decal/cleanable/blood/B = C
			if(istype(B) && B.off_floor)
				floor_only = FALSE
			else
				qdel(C)
		T.remove_atom_colour(WASHABLE_COLOUR_PRIORITY)
		if(floor_only)
			T.clean_blood()

		for(var/mob/living/simple_animal/slime/M in T)
			M.adjustToxLoss(rand(5, 10))

/datum/reagent/space_cleaner/reaction_mob(mob/living/M, method=REAGENT_TOUCH, volume)
	M.clean_blood()

/datum/reagent/blood
	data = list("donor"=null,"diseases"=null,"blood_DNA"=null,"blood_type"=null,"blood_species"=null,"blood_colour"="#A10808","resistances"=null,"trace_chem"=null,"mind"=null,"ckey"=null,"gender"=null,"real_name"=null,"cloneable"=null,"factions"=null, "dna" = null)
	name = "Blood"
	id = "blood"
	reagent_state = LIQUID
	color = "#770000" // rgb: 40, 0, 0
	metabolization_rate = 12.5 * REAGENTS_METABOLISM //fast rate so it disappears fast.
	drink_icon = "glass_red"
	drink_name = "Glass of Tomato juice"
	drink_desc = "Are you sure this is tomato juice?"
	taste_description = "<span class='warning'>blood</span>"
	taste_mult = 1.3

/datum/reagent/blood/reaction_mob(mob/living/M, method=REAGENT_TOUCH, volume)
	if(data && data["diseases"])
		for(var/datum/disease/virus/V in data["diseases"])

			if(V.spread_flags < BLOOD)
				continue

			if(method == REAGENT_TOUCH)
				V.Contract(M, need_protection_check = TRUE, act_type = CONTACT)
			else
				V.Contract(M, need_protection_check = FALSE)

	if(method == REAGENT_INGEST && iscarbon(M))
		var/mob/living/carbon/C = M
		if(C.get_blood_id() == "blood")
			if(!data || !(data["blood_type"] in get_safe_blood(C.dna.blood_type)) || !(data["blood_species"] == C.dna.species.blood_species))
				C.reagents.add_reagent("toxin", volume * 0.5)
			else
				C.blood_volume = min(C.blood_volume + round(volume, 0.1), BLOOD_VOLUME_NORMAL)

/datum/reagent/blood/on_new(list/data)
	if(istype(data))
		SetViruses(src, data)

/datum/reagent/blood/on_merge(list/mix_data)
	merge_diseases_data(mix_data)
	if(data && mix_data)
		data["cloneable"] = 0 //On mix, consider the genetic sampling unviable for pod cloning, or else we won't know who's even getting cloned, etc
		if(mix_data["blood_color"])
			color = mix_data["blood_color"]
	return 1

/datum/reagent/blood/on_update(atom/A)
	if(data["blood_color"])
		color = data["blood_color"]
	return ..()

/datum/reagent/blood/reaction_turf(turf/simulated/T, volume)//splash the blood all over the place
	if(!istype(T))
		return
	if(volume < 3)
		return
	if(!data["donor"] || ishuman(data["donor"]))
		var/obj/effect/decal/cleanable/blood/blood_prop = locate() in T //find some blood here
		if(!blood_prop) //first blood!
			blood_prop = new(T)
			blood_prop.blood_DNA[data["blood_DNA"]] = data["blood_type"]

	else if(isalien(data["donor"]))
		var/obj/effect/decal/cleanable/blood/xeno/blood_prop = locate() in T
		if(!blood_prop)
			blood_prop = new(T)
			blood_prop.blood_DNA["UNKNOWN DNA STRUCTURE"] = "X*"

/datum/reagent/blood/synthetic
	id = "sblood"

/datum/reagent/blood/synthetic/reaction_mob(mob/living/M, method=REAGENT_TOUCH, volume)
	if(data && data["diseases"])
		for(var/datum/disease/virus/V in data["diseases"])

			if(V.spread_flags < BLOOD)
				continue

			if(method == REAGENT_TOUCH)
				V.Contract(M, need_protection_check = TRUE, act_type = CONTACT)
			else
				V.Contract(M, need_protection_check = FALSE)

/datum/reagent/blood/synthetic/vox
	name = "Synthetic Blood"
	id = "sbloodvox"
	data = list("donor"=null,"diseases"=null,"blood_DNA"=null,"blood_type"=null,"blood_species"=null,"blood_colour"="#6093dc","resistances"=null,"trace_chem"=null,"mind"=null,"ckey"=null,"gender"=null,"real_name"=null,"cloneable"=null,"factions"=null, "dna" = null)
	color = "#6093dc"

/datum/reagent/blood/synthetic/vox/reaction_mob(mob/living/M, method=REAGENT_TOUCH, volume)
	..()

	if(method == REAGENT_INGEST && iscarbon(M))
		var/mob/living/carbon/C = M
		if(C.get_blood_id() == "blood")
			if(!data || !(C.dna.species.blood_species == "Vox"))
				C.reagents.add_reagent("toxin", volume * 0.5)
				if(C.stat != DEAD)
					C.adjustOxyLoss(4)
			else
				C.blood_volume = min(C.blood_volume + round(volume, 0.1), BLOOD_VOLUME_NORMAL)

/datum/reagent/blood/synthetic/oxy
	name = "Synthetic Blood"
	id = "sbloodoxy"
	data = list("donor"=null,"diseases"=null,"blood_DNA"=null,"blood_type"=null,"blood_species"=null,"blood_colour"="#e8479d","resistances"=null,"trace_chem"=null,"mind"=null,"ckey"=null,"gender"=null,"real_name"=null,"cloneable"=null,"factions"=null, "dna" = null)
	color = "#e8479d"

/datum/reagent/blood/synthetic/oxy/reaction_mob(mob/living/M, method=REAGENT_TOUCH, volume)
	..()

	if(method == REAGENT_INGEST && iscarbon(M))
		var/mob/living/carbon/C = M
		if(C.get_blood_id() == "blood")
			if(!data || C.dna.species.blood_species == "Vox")
				C.reagents.add_reagent("toxin", volume * 0.5)
				if(C.stat != DEAD)
					C.adjustOxyLoss(4)
			else
				C.blood_volume = min(C.blood_volume + round(volume, 0.1), BLOOD_VOLUME_NORMAL)

/datum/reagent/vaccine
	//data must contain virus type
	name = "Vaccine"
	id = "vaccine"
	color = "#C81040" // rgb: 200, 16, 64
	taste_description = "antibodies"

/datum/reagent/vaccine/reaction_mob(mob/living/M, method=REAGENT_TOUCH, volume)
	if(islist(data) && (method == REAGENT_INGEST))
		for(var/thing in M.diseases)
			var/datum/disease/D = thing
			if(D.GetDiseaseID() in data)
				D.cure()
		LAZYOR(M.resistances, data)

/datum/reagent/vaccine/on_merge(list/data)
	if(istype(data))
		data |= data.Copy()

/datum/reagent/fishwater
	name = "Fish Water"
	id = "fishwater"
	description = "Smelly water from a fish tank. Gross!"
	reagent_state = LIQUID
	color = "#757547"
	taste_description = "puke"

/datum/reagent/fishwater/reaction_mob(mob/living/M, method=REAGENT_TOUCH, volume)
	if(method == REAGENT_INGEST)
		to_chat(M, "Oh god, why did you drink that?")

/datum/reagent/fishwater/on_mob_life(mob/living/M)
	if(prob(30))		// Nasty, you drank this stuff? 30% chance of the fakevomit (non-stunning version)
		if(prob(50))	// 50/50 chance of green vomit vs normal vomit
			M.fakevomit(1)
		else
			M.fakevomit(0)
	return ..()

/datum/reagent/fishwater/toiletwater
	name = "Toilet Water"
	id = "toiletwater"
	description = "Filthy water scoured from a nasty toilet bowl. Absolutely disgusting."
	reagent_state = LIQUID
	color = "#757547"
	taste_description = "the inside of a toilet... or worse"

/datum/reagent/fishwater/toiletwater/reaction_mob(mob/living/M, method=REAGENT_TOUCH, volume) //For shennanigans
	return

/datum/reagent/holywater
	name = "Water"
	id = "holywater"
	description = "A ubiquitous chemical substance that is composed of hydrogen and oxygen."
	reagent_state = LIQUID
	color = "#0064C8" // rgb: 0, 100, 200
	process_flags = ORGANIC | SYNTHETIC
	drink_icon = "glass_clear"
	drink_name = "Glass of Water"
	drink_desc = "The father of all refreshments."
	taste_description = "water"

/datum/reagent/holywater/on_mob_life(mob/living/M)
	var/update_flags = STATUS_UPDATE_NONE
	M.AdjustJitter(-10 SECONDS)
	if(current_cycle >= 30)		// 12 units, 60 seconds @ metabolism 0.4 units & tick rate 2.0 sec
		M.AdjustStuttering(8 SECONDS, bound_lower = 0, bound_upper = 40 SECONDS)
		M.Dizzy(10 SECONDS)
		if(isclocker(M) && prob(5))
			M.AdjustClockSlur(10 SECONDS)
			M.say(pick("Via Ra'var!", "P'res Ni", "Nu'nce te Ren'", "Et Def'Fre", "RELO'JE AR SAGE", "Ric'gui'nea", "Uy'a Rad kos", "Uo Rom'tis!", "Rup'ru ge"))
		if(iscultist(M))
			for(var/datum/action/innate/cult/blood_magic/BM in M.actions)
				for(var/datum/action/innate/cult/blood_spell/BS in BM.spells)
					to_chat(M, "<span class='cultlarge'>Your blood rites falter as holy water scours your body!</span>")
					qdel(BS)
			if(prob(5))
				M.AdjustCultSlur(10 SECONDS)//5 seems like a good number...
				M.say(pick("Av'te Nar'sie","Pa'lid Mors","INO INO ORA ANA","SAT ANA!","Daim'niodeis Arc'iai Le'eones","Egkau'haom'nai en Chaous","Ho Diak'nos tou Ap'iron","R'ge Na'sie","Diabo us Vo'iscum","Si gn'um Co'nu"))
	if(current_cycle >= 75 && prob(33))	// 30 units, 150 seconds
		M.AdjustConfused(6 SECONDS)
		if(isvampirethrall(M))
			M.mind.remove_antag_datum(/datum/antagonist/mindslave/thrall)
			holder.remove_reagent(id, volume)
			M.visible_message("<span class='biggerdanger'>[M] recoils, their skin flushes with colour, regaining their sense of control!</span>")
			M.SetJitter(0)
			M.SetStuttering(0)
			M.SetConfused(0)
			return

		if(iscultist(M))
			SSticker.mode.remove_cultist(M.mind)
			holder.remove_reagent(id, volume)	// maybe this is a little too perfect and a max() cap on the statuses would be better??
			M.SetJitter(0)
			M.SetStuttering(0)
			M.SetConfused(0)
			if(ishuman(M)) // Unequip all cult clothing
				var/mob/living/carbon/human/H = M
				for(var/I in H.contents - (H.bodyparts | H.internal_organs)) // Satanic liver NYI
					if(is_type_in_list(I, CULT_CLOTHING))
						H.drop_item_ground(I)
			return
		if(isclocker(M))
			SSticker.mode.remove_clocker(M.mind)
			holder.remove_reagent(id, volume)
			M.SetJitter(0)
			M.SetStuttering(0)
			M.SetConfused(0)
			if(ishuman(M)) // Unequip all cult clothing
				var/mob/living/carbon/human/H = M
				for(var/I in H.contents - (H.bodyparts | H.internal_organs))
					if(is_type_in_list(I, CLOCK_CLOTHING))
						H.drop_item_ground(I)

	var/datum/antagonist/vampire/vamp = M.mind?.has_antag_datum(/datum/antagonist/vampire)
	if(ishuman(M) && vamp && !vamp.get_ability(/datum/vampire_passive/full) && prob(80))
		var/mob/living/carbon/V = M
		if(vamp.bloodusable)
			M.Stuttering(2 SECONDS)
			M.Jitter(60 SECONDS)
			update_flags |= M.adjustStaminaLoss(5, FALSE)
			if(prob(20))
				M.emote("scream")
			vamp.base_nullification()
			vamp.bloodusable = max(vamp.bloodusable - 3,0)
			var/vomit_stun = (vamp.nullification == OLD_NULLIFICATION)? 8 SECONDS : FALSE
			if(vamp.bloodusable)
				V.vomit(0, TRUE, vomit_stun)
				if(!vomit_stun)
					V.adjustBruteLoss(3)
			else
				holder.remove_reagent(id, volume)
				V.vomit(0, FALSE, vomit_stun)
				return
		else
			if(!vamp.bloodtotal && vamp.nullification == NEW_NULLIFICATION)
				return ..() | update_flags
			switch(current_cycle)
				if(1 to 4)
					to_chat(M, "<span class = 'warning'>Something sizzles in your veins!</span>")
					vamp.base_nullification()
				if(5 to 12)
					to_chat(M, "<span class = 'danger'>You feel an intense burning inside of you!</span>")
					update_flags |= M.adjustFireLoss(1, FALSE)
					M.Stuttering(2 SECONDS)
					M.Jitter(40 SECONDS)
					if(prob(20))
						M.emote("scream")
					vamp.base_nullification()
				if(13 to INFINITY)
					M.visible_message("<span class='danger'>[M] suddenly bursts into flames!</span>",
									"<span class='danger'>You suddenly ignite in a holy fire!</span>")
					M.fire_stacks = min(5, M.fire_stacks + 3)
					M.IgniteMob()
					update_flags |= M.adjustFireLoss(3, FALSE)
					M.Stuttering(2 SECONDS)
					M.Jitter(60 SECONDS)
					if(prob(40))
						M.emote("scream")
					vamp.base_nullification()

	if(ishuman(M) && !M.mind?.isholy)
		switch(current_cycle)
			if(0 to 24)
				M.adjustBrainLoss(0.5, FALSE)
			if(25 to 49)
				M.adjustBrainLoss(1, FALSE)
			if(50 to INFINITY)
				M.adjustBrainLoss(2, FALSE)

	return ..() | update_flags


/datum/reagent/holywater/reaction_mob(mob/living/M, method=REAGENT_TOUCH, volume)
	// Vampires have their powers weakened by holy water applied to the skin.
	if(!ishuman(M) || !M.mind)
		return

	var/mob/living/carbon/human/target = M

	var/datum/antagonist/vampire/vamp = target.mind.has_antag_datum(/datum/antagonist/vampire)
	if(vamp && !vamp.get_ability(/datum/vampire_passive/full))

		if(method == REAGENT_TOUCH)
			if(target.wear_mask)
				to_chat(target, "<span class='warning'>Your mask protects you from the holy water!</span>")
				return
			else if(target.head)
				to_chat(target, "<span class='warning'>Your helmet protects you from the holy water!</span>")
				return
			else
				to_chat(target, "<span class='warning'>Something holy interferes with your powers!</span>")
				vamp.adjust_nullification(5, 2)



/datum/reagent/holywater/reaction_turf(turf/simulated/T, volume)
	if(!istype(T))
		return
	if(volume>=10)
		for(var/obj/effect/rune/R in T)
			qdel(R)
	T.Bless()

/datum/reagent/fuel/unholywater		//if you somehow managed to extract this from someone, dont splash it on yourself and have a smoke
	name = "Unholy Water"
	id = "unholywater"
	description = "Something that shouldn't exist on this plane of existance."
	process_flags = ORGANIC | SYNTHETIC //ethereal means everything processes it.
	metabolization_rate = 2.5 * REAGENTS_METABOLISM
	taste_description = "sulfur"

/datum/reagent/fuel/unholywater/on_mob_life(mob/living/M)
	var/update_flags = STATUS_UPDATE_NONE
	if(iscultist(M))
		M.AdjustDrowsy(-10 SECONDS)
		M.AdjustParalysis(-2 SECONDS)
		M.AdjustStunned(-4 SECONDS)
		M.AdjustWeakened(-4 SECONDS)
		update_flags |= M.adjustToxLoss(-2, FALSE)
		update_flags |= M.adjustFireLoss(-2, FALSE)
		update_flags |= M.adjustOxyLoss(-2, FALSE)
		update_flags |= M.adjustBruteLoss(-2, FALSE)
	else
		update_flags |= M.adjustBrainLoss(3, FALSE)
		update_flags |= M.adjustToxLoss(1, FALSE)
		update_flags |= M.adjustFireLoss(2, FALSE)
		update_flags |= M.adjustOxyLoss(2, FALSE)
		update_flags |= M.adjustBruteLoss(2, FALSE)
		M.AdjustCultSlur(20 SECONDS) //CUASE WHY THE HELL NOT
	return ..() | update_flags

/datum/reagent/hellwater
	name = "Hell Water"
	id = "hell_water"
	description = "YOUR FLESH! IT BURNS!"
	process_flags = ORGANIC | SYNTHETIC		//Admin-bus has no brakes! KILL THEM ALL.
	metabolization_rate = 2.5 * REAGENTS_METABOLISM
	can_synth = FALSE
	taste_description = "burning"

/datum/reagent/hellwater/on_mob_life(mob/living/M)
	var/update_flags = STATUS_UPDATE_NONE
	M.fire_stacks = min(5, M.fire_stacks + 3)
	M.IgniteMob()			//Only problem with igniting people is currently the commonly availible fire suits make you immune to being on fire
	update_flags |= M.adjustToxLoss(1, FALSE)
	update_flags |= M.adjustFireLoss(1, FALSE)		//Hence the other damages... ain't I a bastard?
	update_flags |= M.adjustBrainLoss(5, FALSE)
	return ..() | update_flags

/datum/reagent/liquidgibs
	name = "Liquid gibs"
	id = "liquidgibs"
	color = "#FF9966"
	description = "You don't even want to think about what's in here."
	reagent_state = LIQUID
	taste_description = "meat"

/datum/reagent/liquidgibs/reaction_turf(turf/T, volume) //yes i took it from synthflesh...
	if(volume >= 5 && !isspaceturf(T))
		new /obj/effect/decal/cleanable/blood/gibs/cleangibs(T)
		playsound(T, 'sound/effects/splat.ogg', 50, 1, -3)

/datum/reagent/lye
	name = "Lye"
	id = "lye"
	description = "Also known as sodium hydroxide."
	reagent_state = LIQUID
	color = "#FFFFD6" // very very light yellow
	taste_description = "<span class='userdanger'>ACID</span>"//don't drink lye, kids

/datum/reagent/drying_agent
	name = "Drying agent"
	id = "drying_agent"
	description = "Can be used to dry things."
	reagent_state = LIQUID
	color = "#A70FFF"
	taste_description = "dry mouth"

/datum/reagent/drying_agent/reaction_turf(turf/simulated/T, volume)
	if(istype(T))
		T.MakeDry(TURF_WET_WATER)

/datum/reagent/drying_agent/reaction_obj(obj/O, volume)
	if(istype(O, /obj/item/clothing/shoes/galoshes))
		var/t_loc = get_turf(O)
		qdel(O)
		new /obj/item/clothing/shoes/galoshes/dry(t_loc)
