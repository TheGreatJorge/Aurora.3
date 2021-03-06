/proc/get_hat_icon(var/obj/item/hat, var/offset_x = 0, var/offset_y = 0)
	var/list/mob_hat_cache = SSicon_cache.mob_hat_cache
	var/t_state = hat.icon_state
	if(hat.item_state_slots && hat.item_state_slots[slot_head_str])
		t_state = hat.item_state_slots[slot_head_str]
	else if(hat.item_state)
		t_state = hat.item_state
	var/key = "[t_state]_[offset_x]_[offset_y]"
	if(!mob_hat_cache[key])            // Not ideal as there's no guarantee all hat icon_states
		var/t_icon = INV_HEAD_DEF_ICON // are unique across multiple dmis, but whatever.
		if(hat.icon_override)
			t_icon = hat.icon_override
		else if(hat.item_icons && (slot_head_str in hat.item_icons))
			t_icon = hat.item_icons[slot_head_str]
		var/image/I = image(icon = t_icon, icon_state = t_state)
		I.pixel_x = offset_x
		I.pixel_y = offset_y
		mob_hat_cache[key] = I
	return mob_hat_cache[key]

/mob/living/silicon/robot/drone
	name = "drone"
	real_name = "drone"
	icon = 'icons/mob/robots.dmi'
	icon_state = "repairbot"
	maxHealth = 35
	health = 35
	cell_emp_mult = 1
	universal_speak = 0
	universal_understand = 1
	gender = NEUTER
	pass_flags = PASSTABLE | PASSDOORHATCH
	braintype = "Robot"
	lawupdate = 0
	density = 0
	req_access = list(access_engine, access_robotics)
	integrated_light_power = 3
	local_transmit = 1
	possession_candidate = 1
	mob_size = 4

	can_pull_size = 3
	can_pull_mobs = MOB_PULL_SMALLER

	mob_bump_flag = SIMPLE_ANIMAL
	//mob_swap_flags = SIMPLE_ANIMAL
	//mob_push_flags = SIMPLE_ANIMAL
	//mob_always_swap = 1

	//Used for self-mailing.
	var/mail_destination = ""
	var/obj/machinery/drone_fabricator/master_fabricator
	var/law_type = /datum/ai_laws/drone
	var/module_type = /obj/item/weapon/robot_module/drone
	var/obj/item/hat
	var/hat_x_offset = 0
	var/hat_y_offset = -13
	var/range_limit = 1

	holder_type = /obj/item/weapon/holder/drone

/mob/living/silicon/robot/drone/can_be_possessed_by(var/mob/dead/observer/possessor)
	if(!istype(possessor) || !possessor.client || !possessor.ckey)
		return 0
	if(!config.allow_drone_spawn)
		src << "<span class='danger'>Playing as drones is not currently permitted.</span>"
		return 0
	if(too_many_active_drones())
		src << "<span class='danger'>The maximum number of active drones has been reached..</span>"
		return 0
	if(jobban_isbanned(possessor,"Cyborg"))
		usr << "<span class='danger'>You are banned from playing synthetics and cannot spawn as a drone.</span>"
		return 0
	if(!possessor.MayRespawn(1,MINISYNTH))
		return 0
	return 1

/mob/living/silicon/robot/drone/do_possession(var/mob/dead/observer/possessor)
	if(!(istype(possessor) && possessor.ckey))
		return 0
	if(src.ckey || src.client)
		possessor << "<span class='warning'>\The [src] already has a player.</span>"
		return 0
	message_admins("<span class='adminnotice'>[key_name_admin(possessor)] has taken control of \the [src].</span>")
	log_admin("[key_name(possessor)] took control of \the [src].",ckey=key_name(possessor))
	transfer_personality(possessor.client)
	qdel(possessor)
	return 1

/mob/living/silicon/robot/drone/Destroy()
	if(hat)
		hat.loc = get_turf(src)
	return ..()

/mob/living/silicon/robot/drone/construction
	icon_state = "constructiondrone"
	law_type = /datum/ai_laws/construction_drone
	module_type = /obj/item/weapon/robot_module/drone/construction
	hat_x_offset = 1
	hat_y_offset = -12
	can_pull_size = 5
	can_pull_mobs = MOB_PULL_SAME
	holder_type = /obj/item/weapon/holder/drone/heavy
	range_limit = 0

/mob/living/silicon/robot/drone/Initialize()
	. = ..()

	verbs += /mob/living/proc/hide
	remove_language("Robot Talk")
	add_language("Robot Talk", 0)
	add_language("Drone Talk", 1)

	//They are unable to be upgraded, so let's give them a bit of a better battery.
	cell.maxcharge = 10000
	cell.charge = 10000

	// NO BRAIN.
	mmi = null

	//We need to screw with their HP a bit. They have around one fifth as much HP as a full borg.
	for(var/V in components) if(V != "power cell")
		var/datum/robot_component/C = components[V]
		C.max_damage = 10

	verbs -= /mob/living/silicon/robot/verb/Namepick
	updateicon()
	density = 0

/mob/living/silicon/robot/drone/init()
	aiCamera = new/obj/item/device/camera/siliconcam/drone_camera(src)
	additional_law_channels["Drone"] = ":d"
	if(!laws) laws = new law_type
	if(!module) module = new module_type(src)

	flavor_text = "It's a tiny little repair drone. The casing is stamped with an corporate logo and the subscript: '[company_name] Recursive Repair Systems: Fixing Tomorrow's Problem, Today!'"
	playsound(src.loc, 'sound/machines/twobeep.ogg', 50, 0)

//Redefining some robot procs...
/mob/living/silicon/robot/drone/SetName(pickedName as text)
	// Would prefer to call the grandparent proc but this isn't possible, so..
	real_name = pickedName
	name = real_name

/mob/living/silicon/robot/drone/updatename()
	real_name = "maintenance drone ([rand(100,999)])"
	name = real_name

/mob/living/silicon/robot/drone/updateicon()

	cut_overlays()
	if(stat == 0)
		add_overlay("eyes-[icon_state]")
	if(hat) // Let the drones wear hats.
		add_overlay(get_hat_icon(hat, hat_x_offset, hat_y_offset))

/mob/living/silicon/robot/drone/choose_icon()
	return

/mob/living/silicon/robot/drone/pick_module()
	return

/mob/living/silicon/robot/drone/proc/wear_hat(var/obj/item/new_hat)
	if(hat)
		return
	hat = new_hat
	new_hat.forceMove(src)
	updateicon()

//Drones cannot be upgraded with borg modules so we need to catch some items before they get used in ..().
/mob/living/silicon/robot/drone/attackby(var/obj/item/weapon/W, var/mob/user)

	if(user.a_intent == "help" && istype(W, /obj/item/clothing/head))
		if(hat)
			user << "<span class='warning'>\The [src] is already wearing \the [hat].</span>"
			return
		user.unEquip(W)
		wear_hat(W)
		user.visible_message("<span class='notice'>\The [user] puts \the [W] on \the [src].</span>")
		return
	else if(istype(W, /obj/item/borg/upgrade/))
		user << "<span class='danger'>\The [src] is not compatible with \the [W].</span>"
		return

	else if (iscrowbar(W))
		user << "<span class='danger'>\The [src] is hermetically sealed. You can't open the case.</span>"
		return

	else if (istype(W, /obj/item/weapon/card/id)||istype(W, /obj/item/device/pda))

		if(stat == 2)

			if(!config.allow_drone_spawn || emagged || health < -maxHealth) //It's dead, Dave.
				user << "<span class='danger'>The interface is fried, and a distressing burned smell wafts from the robot's interior. You're not rebooting this one.</span>"
				return

			if(!allowed(usr))
				user << "<span class='danger'>Access denied.</span>"
				return

			user.visible_message("<span class='danger'>\The [user] swipes \his ID card through \the [src], attempting to reboot it.</span>", "<span class='danger'>>You swipe your ID card through \the [src], attempting to reboot it.</span>")
			request_player()
			return

		else
			user.visible_message("<span class='danger'>\The [user] swipes \his ID card through \the [src], attempting to shut it down.</span>", "<span class='danger'>You swipe your ID card through \the [src], attempting to shut it down.</span>")

			if(emagged)
				return

			if(allowed(usr))
				shut_down()
			else
				user << "<span class='danger'>Access denied.</span>"

		return

	..()

/mob/living/silicon/robot/drone/emag_act(var/remaining_charges, var/mob/user)
	if(!client || stat == 2)
		user << "<span class='danger'>There's not much point subverting this heap of junk.</span>"
		return

	if(emagged)
		src << "<span class='danger'>\The [user] attempts to load subversive software into you, but your hacked subroutines ignore the attempt.</span>"
		user << "<span class='danger'>You attempt to subvert [src], but the sequencer has no effect.</span>"
		return

	user << "<span class='danger'>You swipe the sequencer across [src]'s interface and watch its eyes flicker.</span>"
	src << "<span class='danger'>You feel a sudden burst of malware loaded into your execute-as-root buffer. Your tiny brain methodically parses, loads and executes the script.</span>"

	message_admins("[key_name_admin(user)] emagged drone [key_name_admin(src)].  Laws overridden.")
	log_game("[key_name(user)] emagged drone [key_name(src)].  Laws overridden.",ckey=key_name(user),ckey_target=key_name(src))
	var/time = time2text(world.realtime,"hh:mm:ss")
	lawchanges.Add("[time] <B>:</B> [user.name]([user.key]) emagged [name]([key])")

	emagged = 1
	lawupdate = 0
	connected_ai = null
	clear_supplied_laws()
	clear_inherent_laws()
	laws = new /datum/ai_laws/syndicate_override
	set_zeroth_law("Only [user.real_name] and people \he designates as being such are operatives.")

	src << "<b>Obey these laws:</b>"
	laws.show_laws(src)
	src << "<span class='danger'>ALERT: [user.real_name] is your new master. Obey your new laws and \his commands.</span>"
	return 1

//DRONE LIFE/DEATH

//For some goddamn reason robots have this hardcoded. Redefining it for our fragile friends here.
/mob/living/silicon/robot/drone/updatehealth()
	if(status_flags & GODMODE)
		health = maxHealth
		stat = CONSCIOUS
		return
	health = maxHealth - (getBruteLoss() + getFireLoss())
	return

//Easiest to check this here, then check again in the robot proc.
//Standard robots use config for crit, which is somewhat excessive for these guys.
//Drones killed by damage will gib.
/mob/living/silicon/robot/drone/handle_regular_status_updates()
	var/turf/T = get_turf(src)
	var/area/A = get_area(T)
	if((!T || health <= -maxHealth || (range_limit && !(A in the_station_areas))) && src.stat != DEAD)
		timeofdeath = world.time
		death() //Possibly redundant, having trouble making death() cooperate.
		gib()
		return
	..()

//DRONE MOVEMENT.
/mob/living/silicon/robot/drone/slip_chance(var/prob_slip)
	return 0

//CONSOLE PROCS
/mob/living/silicon/robot/drone/proc/law_resync()
	if(stat != 2)
		if(emagged)
			src << "<span class='danger'>You feel something attempting to modify your programming, but your hacked subroutines are unaffected.</span>"
		else
			src << "<span class='danger'>A reset-to-factory directive packet filters through your data connection, and you obediently modify your programming to suit it.</span>"
			full_law_reset()
			show_laws()

/mob/living/silicon/robot/drone/proc/shut_down()
	if(stat != 2)
		if(emagged)
			src << "<span class='danger'>You feel a system kill order percolate through your tiny brain, but it doesn't seem like a good idea to you.</span>"
		else
			src << "<span class='danger'>You feel a system kill order percolate through your tiny brain, and you obediently destroy yourself.</span>"
			death()

/mob/living/silicon/robot/drone/proc/full_law_reset()
	clear_supplied_laws(1)
	clear_inherent_laws(1)
	clear_ion_laws(1)
	laws = new law_type

//Reboot procs.

/mob/living/silicon/robot/drone/proc/request_player()
	if(too_many_active_drones())
		return
	var/datum/ghosttrap/G = get_ghost_trap("maintenance drone")
	G.request_player(src, "Someone is attempting to reboot a maintenance drone.", 30 SECONDS)

/mob/living/silicon/robot/drone/proc/transfer_personality(var/client/player)
	if(!player) return
	stat = 0
	src.ckey = player.ckey

	if(player.mob && player.mob.mind)
		player.mob.mind.transfer_to(src)

	lawupdate = 0
	src << "<b>Systems rebooted</b>. Loading base pattern maintenance protocol... <b>loaded</b>."
	full_law_reset()
	welcome_drone()

/mob/living/silicon/robot/drone/proc/welcome_drone()
	src << "<b>You are a maintenance drone, a tiny-brained robotic repair machine</b>."
	src << "You have no individual will, no personality, and no drives or urges other than your laws."
	src << "Remember,  you are <b>lawed against interference with the crew</b>. Also remember, <b>you DO NOT take orders from the AI.</b>"
	src << "Use <b>say ;Hello</b> to talk to other drones and <b>say Hello</b> to speak silently to your nearby fellows."

/mob/living/silicon/robot/drone/start_pulling(var/atom/movable/AM)

	if(!(istype(AM,/obj/item/pipe) || istype(AM,/obj/structure/disposalconstruct)))
		if(istype(AM,/obj/item))
			var/obj/item/O = AM
			if(O.w_class > can_pull_size)
				src << "<span class='warning'>You are too small to pull that.</span>"
				return
		else
			if(!can_pull_mobs)
				src << "<span class='warning'>You are too small to pull that.</span>"
				return
	..()


/mob/living/silicon/robot/drone/add_robot_verbs()
	src.verbs |= silicon_subsystems

/mob/living/silicon/robot/drone/remove_robot_verbs()
	src.verbs -= silicon_subsystems

/mob/living/silicon/robot/drone/construction/welcome_drone()
	src << "<b>You are a construction drone, an autonomous engineering and fabrication system.</b>."
	src << "You are assigned to a NanoTrasen construction project. The name is irrelevant. Your task is to complete construction and subsystem integration as soon as possible."
	src << "Use <b>:d</b> to talk to other drones and <b>say</b> to speak silently to your nearby fellows."
	src << "<b>You do not follow orders from anyone; not the AI, not humans, and not other synthetics.</b>."

/mob/living/silicon/robot/drone/construction/init()
	..()
	flavor_text = "It's a bulky construction drone stamped with a NanoTrasen glyph."

/mob/living/silicon/robot/drone/construction/updatename()
	real_name = "construction drone ([rand(100,999)])"
	name = real_name

/proc/too_many_active_drones()
	var/drones = 0
	for(var/mob/living/silicon/robot/drone/D in mob_list)
		if(D.key && D.client)
			drones++
	return drones >= config.max_maint_drones
