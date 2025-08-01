///////////////////
//Admin Commands///
///////////////////
client/proc/enable_waterflow(var/enabled as num)
	set name = "Set Fluid Flow Enabled"
	set desc = "0 to disable, 1 to enable"
	SET_ADMIN_CAT(ADMIN_CAT_DEBUG)
	ADMIN_ONLY
	SHOW_VERB_DESC
	waterflow_enabled = !!enabled

client/proc/delete_fluids()
	set name = "Delete All Fluids"
	set desc = "Probably safe to run. Probably."
	SET_ADMIN_CAT(ADMIN_CAT_DEBUG)
	ADMIN_ONLY
	SHOW_VERB_DESC

	var/exenabled = waterflow_enabled
	enable_waterflow(0)
	var/i = 0
	SPAWN(0)
		for(var/obj/fluid/fluid in world)
			if (fluid.disposed) continue

			for (var/mob/living/M in fluid.loc)
				fluid.Uncrossed(M)
				M.show_submerged_image(0)
			for(var/obj/O in fluid.loc)
				if (O.submerged_images)
					fluid.Uncrossed(O)
					O.show_submerged_image(0)
			if(fluid.group)
				fluid.group.evaporate()
			else
				fluid.turf_remove_cleanup(fluid.loc)
				fluid.removed()
			i++
			if(!(i%30))
				sleep(0.2 SECONDS)

		enable_waterflow(exenabled)

client/proc/special_fullbright()
	set name = "Static Sea Light"
	set desc = "Helps when server load is heavy. Doesn't affect trench."
	SET_ADMIN_CAT(ADMIN_CAT_DEBUG)
	set hidden = 1
	ADMIN_ONLY
	SHOW_VERB_DESC

	message_admins("[key_name(src)] is making all Z1 Sea Lights static...")
	SPAWN(0)
		for(var/turf/space/fluid/F in world)
			if (F.z == 1)
				F.fullbright = 0.5
			LAGCHECK(LAG_REALTIME)
		message_admins("Sea Lights are now Static.")

client/proc/replace_space()
	set name = "Replace All Space Tiles With Ocean"
	set desc = "uh oh."
	SET_ADMIN_CAT(ADMIN_CAT_UNUSED)
	ADMIN_ONLY

	var/datum/reagent/reagent = pick_reagent(src.mob)
	if (!reagent)
		return

	logTheThing(LOG_ADMIN, src, "began to convert all space tiles into an ocean of [reagent.id].")
	message_admins("[key_name(src)] began to convert all space tiles into an ocean of [reagent.id]. Oh no.")

	SPAWN(0)
		ocean_reagent_id = reagent.id
		var/datum/reagents/R = new /datum/reagents(100)
		R.add_reagent(reagent.id, 100)
		ocean_name = "ocean of " + R.get_master_reagent_name()
		ocean_color = R.get_average_color()
		qdel(R)

		for(var/turf/space/S in world)
			LAGCHECK(LAG_HIGH)
			var/turf/orig = locate(S.x, S.y, S.z)
			orig.ReplaceWith(/turf/space/fluid, FALSE, TRUE, FALSE, TRUE)
		message_admins("Finished space replace!")
		map_currently_underwater = 1

client/proc/replace_space_exclusive()
	set name = "Oceanify"
	set desc = "This is the safer one."
	SET_ADMIN_CAT(ADMIN_CAT_FUN)
	ADMIN_ONLY
	SHOW_VERB_DESC

	var/datum/reagent/reagent = pick_reagent(src)

	logTheThing(LOG_ADMIN, src, "began to convert all station space tiles into an ocean of [reagent.id].")
	message_admins("[key_name(src)] began to convert all station space tiles into an ocean of [reagent.id].")

	SPAWN(0)
		ocean_reagent_id = reagent.id
		var/datum/reagents/R = new /datum/reagents(100)
		R.add_reagent(reagent.id, 100)

		ocean_fluid_obj?.group?.reagents?.clear_reagents()
		fluid_turf_setup(first_time=FALSE)

#ifdef UNDERWATER_MAP
		var/master_reagent_name = R.get_master_reagent_name()
		if(master_reagent_name == "water")
			ocean_name = "ocean floor" //normal ocean
		else
			ocean_name = master_reagent_name + " ocean floor"
#else
		ocean_name = "ocean of " + R.get_master_reagent_name()
#endif

		ocean_color = R.get_average_color().to_rgb()
		qdel(R)

		map_currently_underwater = 1
		for(var/turf/space/S in world)
			if (S.z != 1 || istype(S, /turf/space/fluid/warp_z5)) continue

			var/turf/orig = locate(S.x, S.y, S.z)

			var/turf/space/fluid/T = orig.ReplaceWith(/turf/space/fluid, FALSE, TRUE, FALSE, TRUE)

#ifdef UNDERWATER_MAP
			T.name = ocean_name
#endif
			T.color = ocean_color
			LAGCHECK(LAG_REALTIME)

// catwalks sim water otherwise
#ifndef UNDERWATER_MAP
		for(var/turf/simulated/floor/airless/plating/catwalk/C in world)
			if (C.z != 1 || istype(C, /turf/space/fluid/warp_z5)) continue
			var/turf/orig = locate(C.x, C.y, C.z)
			var/turf/space/fluid/T = orig.ReplaceWith(/turf/space/fluid, FALSE, TRUE, FALSE, TRUE)
			T.color = ocean_color
			LAGCHECK(LAG_REALTIME)
#endif

		REMOVE_ALL_PARALLAX_RENDER_SOURCES_FROM_GROUP(Z_LEVEL_STATION)
		REMOVE_ALL_PARALLAX_RENDER_SOURCES_FROM_GROUP(Z_LEVEL_DEBRIS)
		REMOVE_ALL_PARALLAX_RENDER_SOURCES_FROM_GROUP(Z_LEVEL_MINING)
		message_admins("Finished space replace!")
		map_currently_underwater = 1


client/proc/dereplace_space()
	set name = "Unoceanify"
	set desc = "uh oh."
	SET_ADMIN_CAT(ADMIN_CAT_FUN)
	ADMIN_ONLY
	SHOW_VERB_DESC

	var/answer = alert("Replace Z1 only?",,"Yes","No")

	logTheThing(LOG_ADMIN, src, "began to convert all ocean tiles into space.")
	message_admins("[key_name(src)] began to convert all ocean tiles into space.")

	SPAWN(0)
		map_currently_underwater = 0

		if (answer == "Yes")
			for(var/turf/space/fluid/F in world)
				if (F.z == 1)
					var/turf/orig = locate(F.x, F.y, F.z)
					orig.ReplaceWith(/turf/space, FALSE, TRUE, FALSE, TRUE)
				LAGCHECK(LAG_REALTIME)
			RESTORE_PARALLAX_RENDER_SOURCE_GROUP_TO_DEFAULT(Z_LEVEL_STATION)
		else
			for(var/turf/space/fluid/F in world)
				var/turf/orig = locate(F.x, F.y, F.z)
				orig.ReplaceWith(/turf/space, FALSE, TRUE, FALSE, TRUE)
				LAGCHECK(LAG_REALTIME)
			RESTORE_PARALLAX_RENDER_SOURCE_GROUP_TO_DEFAULT(Z_LEVEL_STATION)
			RESTORE_PARALLAX_RENDER_SOURCE_GROUP_TO_DEFAULT(Z_LEVEL_DEBRIS)
			RESTORE_PARALLAX_RENDER_SOURCE_GROUP_TO_DEFAULT(Z_LEVEL_MINING)

		message_admins("Finished space dereplace!")
		map_currently_underwater = 0
