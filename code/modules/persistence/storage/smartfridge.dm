/datum/persistent/storage/smartfridge/get_storage_list(var/obj/machinery/smartfridge/entry)
	if(!istype(entry))
		return ..()

	. = list()
	for(var/datum/stored_item/I in entry.item_records)
		.[I.item_path] = I.get_amount()

/datum/persistent/storage/smartfridge/CreateEntryInstance(var/turf/creating, var/list/tokens)
	var/obj/machinery/smartfridge/S = find_specific_instance(creating)
	var/list/L = generate_items(tokens["items"])
	for(var/atom/A in L)
		if(S.accept_check(A))
			S.stock(A)
		else
			qdel(A) // Should clean this up here, it couldn't be stocked





/datum/persistent/storage/smartfridge/sheet_storage
	name = "sheet_storage"
	max_storage = 50
	store_per_type = TRUE
	target_type = /obj/machinery/smartfridge/sheets

	var/stacks_go_missing = FALSE // Variable rate depletion of stacks inter-round

/datum/persistent/storage/smartfridge/sheet_storage/lossy
	name = "sheet_storage_lossy"
	max_storage = 250
	stacks_go_missing = TRUE

/datum/persistent/storage/smartfridge/sheet_storage/generate_items(var/list/L)
	. = list()
	for(var/obj/item/stack/material/S as anything in L)
		if(!ispath(S, /obj/item/stack/material))
			log_debug("Warning: Sheet_storage persistent datum tried to create [S]")
			continue

		// Skip entire stack if we hit the chance
		if(prob(go_missing_chance))
			continue

		var/count = L[S]

		var/obj/item/stack/material/inst = S
		var/max_amount = initial(inst.max_amount)

		// Delete some stacks if we want
		if(stacks_go_missing)
			var/fuzzy = rand(-5,5)
			switch(count / max_amount)
				if(0 to 1)
					count -= 10+fuzzy // 1 stack or less, lose 10
				if(1 to 10)
					count -= max_amount+fuzzy // 1 to 10 stacks, lose a stack
				if(10 to INFINITY)
					count -= max_amount*3+fuzzy // 10+ stacks, lose 3 stacks
			if(count <= 0)
				qdel(inst)
				continue
		
		while(count > 0)	
			inst = new S
			inst.amount = min(count, max_amount)
			count -= inst.get_amount()
			. += inst


/datum/persistent/storage/smartfridge/produce
	name = "fruit_storage"
	max_storage = 50
	store_per_type = FALSE
	target_type = /obj/machinery/smartfridge/produce

/datum/persistent/storage/smartfridge/produce/lossy
	name = "fruit_storage_lossy"
	go_missing_chance = 12.5 // 10% loss between rounds

/datum/persistent/storage/smartfridge/produce/assemble_token(var/T)
	var/list/subtok = splittext(T, " ")
	if(subtok.len != 2)
		return null
	
	if(!istype(SSplants)) // No seed controller means the fruit will come out all wonky if at all
		return null

	subtok[2] = text2num(subtok[2])

	// Ensure we've found a token describing the quantity of a path
	if(subtok.len != 2 || \
			!istype(SSplants.seeds[subtok[1]], /datum/seed) || \
			!isnum(subtok[2]))
		return null
	
	return subtok

/datum/persistent/storage/smartfridge/produce/create_item(var/seedtype)
	return new /obj/item/weapon/reagent_containers/food/snacks/grown(null, seedtype) // Smartfridge will be stock()ed with it, loc is unimportant

/datum/persistent/storage/smartfridge/produce/get_storage_list(var/obj/machinery/smartfridge/produce/entry)
	if(!istype(entry))
		return ..()

	. = list()
	for(var/datum/stored_item/I in entry.item_records)
		if(prob(go_missing_chance))
			continue
		if(LAZYLEN(I.instances))
			var/obj/item/weapon/reagent_containers/food/snacks/grown/G = I.instances[1]
			if(!istype(G))
				continue
			.[G.plantname] = I.get_amount() // Store the seed type, because that's what's used to generate the fruit