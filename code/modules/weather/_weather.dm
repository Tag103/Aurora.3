/*
 * Notes on weather:
 *
 * - Weather is a single object that sits in the vis_contents of all outside turfs on
 *   its associated z-levels and is removed or added by /turf/proc/update_weather(),
 *   which is usually called from /turf/proc/set_outside().
 *
 * - Weather generally assumes any atom that cares about it will ask it directly and
 *   mobs do this in /mob/living/proc/handle_environment().
 *
 * - For this system to be scalable, it should minimize the amount of list-based
 *   processing it does and be primarily passive, allowing mobs to ignore it or
 *   poll it on their own time.
 *
 * - The weather object is queued on SSweather and is polled every fifteen seconds at time
 *   of writing. This is handled in /obj/abstract/weather_system/proc/tick().
 *
 * - When evaluating, weather will generally get more intense or more severe rather than
 *   jumping around randomly. Each state will set a minimum duration based on min/max time.
 *
 * - If polled between weather updates there is a chance of modifying wind speed and direction
 *   instead.
 */

/obj/abstract/weather_system
	plane             = DEFAULT_PLANE
	layer             = ABOVE_PROJECTILE_LAYER
	icon              = 'icons/effects/weather.dmi'
	icon_state        = "blank"
	invisibility      = 0
	appearance_flags  = (RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM)


	// Temporarily removing these, we do not have the same material system as Nebula

	// /// Material to use for the properties of rain.
	// var/water_material = null

	// /// Material to use for the properties of snow and hail.
	// var/ice_material = null

	/// Whether this weather system supports having watery weather
	var/has_water_weather = FALSE

	/// Whether this weather system supports having icy weather
	var/has_icy_weather = FALSE

	/// What z-levels are we affecting?
	var/list/affecting_zs

	/// What is our internal state and how do we decide what state to use?
	var/datum/state_machine/weather/weather_system

	/// What world.time will we next evaluate our state?
	var/next_weather_transition = 0

	/// We've evaluated a new weather pattern and we're in the process of transitioning to it
	var/transitioning_weather = FALSE

	/// A visible atom used for animated lighting effects.
	var/obj/abstract/lightning_overlay/lightning_overlay

	/// Holder for a list used to add required atoms to turf vis_contents.
	var/tmp/list/vis_contents_additions

// Main heartbeat proc, called by SSweather.
/obj/abstract/weather_system/proc/tick()

	// Check if we should move to a new state.
	if(world.time >= next_weather_transition && !transitioning_weather)
		weather_system.evaluate()

	// Change wind direction and speed.
	handle_wind()

	// Handle periodic effects for ticks (like lightning)
	var/singleton/state/weather/rain/weather_state = weather_system.current_state
	if(istype(weather_state))
		weather_state.tick(src)


/obj/abstract/weather_system/Destroy()
	// Clean ourselves out of the vis_contents of our affected turfs.
	for(var/tz in affecting_zs)
		for(var/turf/T as anything in block(locate(1, 1, tz), locate(world.maxx, world.maxy, tz)))
			if(T.weather == src)
				T.remove_vis_contents(vis_contents_additions)
				T.weather = null
	vis_contents_additions.Cut()
	SSweather.unregister_weather_system(src)
	QDEL_NULL(lightning_overlay)
	. = ..()

// Called by /turf/examine() to show current weather status.
/obj/abstract/weather_system/examine(mob/user, distance, is_adjacent, infix, suffix, show_extended)
	SHOULD_CALL_PARENT(FALSE)
	var/singleton/state/weather/weather_state = weather_system.current_state
	if(istype(weather_state))
		to_chat(user, weather_state.descriptor)
	show_wind(user, force = TRUE)

// Called by /singleton/state/weather to assess validity of a state in the weather FSM.
/obj/abstract/weather_system/proc/supports_weather_state(var/singleton/state/weather/next_state)
	// Exoplanet stuff for the future:
	// - TODO: track and check exoplanet temperature.
	// - TODO: compare to a list of 'acceptable' states
	if(istype(next_state))
		// Temporarily removing these, we do not have the same material system as Nebula
		// if(next_state.is_liquid)
		// 	return !!water_material
		// if(next_state.is_ice)
		// 	return !!ice_material
		if(next_state.is_liquid)
			return has_water_weather
		if(next_state.is_ice)
			return has_icy_weather
		return TRUE
	return FALSE

// Dummy object for lightning flash animation.
/obj/abstract/lightning_overlay
	plane             = EFFECTS_ABOVE_LIGHTING_PLANE //Future EMISSIVE_PLANE
	layer             = LIGHTNING_LAYER
	icon              = 'icons/effects/weather.dmi'
	icon_state        = "full"
	alpha             = 0
	invisibility      = 0
