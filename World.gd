extends Node2D

const TileSize = 16
const SeaLevel = 0.001 #0.1 for a few more islands; 0.01 for 2 continents; 0.001 for a big single continent
const ForestLevel = 0.3
const MountainLevel = 0.7

const MAP_SIZE_X = 64
const MAP_SIZE_Y = 48
const screen_width = ((TileSize * MAP_SIZE_X) / 2) - (TileSize / 2)
const screen_height = ((TileSize * MAP_SIZE_Y) / 2) - (TileSize / 2)

var tileArray = []
var currTileArrayX = -1
var currTileArrayY = -1

var continents = {}
var regions = {}
var cheat_show_regions = false

var currentCharacter

var inputs = {"move_right": Vector2.RIGHT,
			"move_left": Vector2.LEFT,
			"move_up": Vector2.UP,
			"move_down": Vector2.DOWN}
var pressed_direction = Vector2.ZERO

const CharacterResource = preload("res://character.tscn")

@export var altitude_noise: FastNoiseLite
@export var tile: PackedScene
#@export var character: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready():
	await generate_map()
	
	
	#TEMPORARY TEST just getting a character in on the world map
	var tempChar = CharacterResource.instantiate()
	tempChar.load_stats("res://test_char_30.tres")
	$Characters.add_child(tempChar)
	currentCharacter = tempChar
	SignalBus.combatants_dict["hero"].append(tempChar)
	
	#And trying to place 'em somewhere
	place_character()
	
	#set up camera
	$Camera2D.make_current()
	$Camera2D.position = currentCharacter.position
	$Camera2D.set_limit(SIDE_RIGHT,screen_width)
	$Camera2D.set_limit(SIDE_LEFT,(-1 * screen_width) - 16)
	$Camera2D.set_limit(SIDE_BOTTOM,screen_height)
	$Camera2D.set_limit(SIDE_TOP,(-1 * screen_height) - 16)

func place_character():
	var randomContinent = continents.keys().pick_random()
	var randomTile = continents[randomContinent]["list"].pick_random()
	var tempPosition = randomTile.position
	#var tempPosition = position.snapped(Vector2.ONE * TileSize)
	tempPosition += Vector2.ONE * TileSize/2
	if SignalBus.map_starting_location != Vector2.ONE:
		tempPosition = SignalBus.map_starting_location
		
	currentCharacter.position = tempPosition
	#print(currentCharacter.position) #TEST
	#currentCharacter.play_anim("idle_sword_l") #for starting

func clear_map():
	for line in tileArray:
		for tile in line:
			if is_instance_valid(tile):
				tile.queue_free()
	
	continents.clear()
	tileArray.clear()
	currTileArrayX = -1
	currTileArrayY = -1

func generate_map():
	#Make map
	altitude_noise.seed = randi()
	for n in MAP_SIZE_Y:
		# We divide by two so that half the tiles
		# generate left/above center and half right/below
		var y = n - MAP_SIZE_Y / 2.0
		
		currTileArrayY += 1
		tileArray.append([])
		for m in MAP_SIZE_X:
			var x = m - MAP_SIZE_X / 2.0
			
			currTileArrayX += 1
			
			generate_terrain_tile(x, y)
		currTileArrayX = -1
		
		#await get_tree().create_timer(0.2).timeout #TEST
	
	map_smoother() #smooth out shapes' edges
	
	determine_continents() #determine the continents
	
	print_continents()
	
	determine_regions_by_continent()
	
	for tileRow in tileArray:
		for tile in tileRow:
			tile.set_edges()
			
func _unhandled_input(event):
	pressed_direction = Vector2.ZERO
	if event.is_action("move_up") or event.is_action("move_down"):
		#pressed_direction = Vector2.ZERO
		pressed_direction.y = Input.get_axis("move_up","move_down")
		if pressed_direction.y == 0.0:
			pressed_direction.x = Input.get_axis("move_left","move_right")
	elif event.is_action("move_left") or event.is_action("move_right"):
		#pressed_direction = Vector2.ZERO
		pressed_direction.x = Input.get_axis("move_left","move_right")
		if pressed_direction.x == 0.0:
			pressed_direction.y = Input.get_axis("move_down","move_up")
			
	if event.is_action_pressed("debug_refresh"): #F5, of course
		print("Regenerating map...")
		add_cheat_label("Regenerating Map...")
		await clear_map()
		await generate_map()
		remove_cheat_label("Regenerating Map...")
	if event.is_action_pressed("cheat_walk_through_walls"):
		#toggle walk through walls on or off.
		currentCharacter.cheat_walk_through_walls = not currentCharacter.cheat_walk_through_walls
		if currentCharacter.cheat_walk_through_walls:
			#var tempResource = load("res://initiative_list_item.tscn")
			add_cheat_label("Walk Through Walls")
		else:
			remove_cheat_label("Walk Through Walls")
	if event.is_action_pressed("cheat_move_faster"):
		currentCharacter.activate_cheat_move_faster(!currentCharacter.cheat_move_faster)
		if currentCharacter.cheat_move_faster:
			#var tempResource = load("res://initiative_list_item.tscn")
			add_cheat_label("Move Faster")
		else:
			remove_cheat_label("Move Faster")
	if event.is_action_pressed("cheat_show_regions"):
		cheat_show_regions = not cheat_show_regions
		if cheat_show_regions:
			for region in regions.keys():
				for tile in regions[region]["list"]:
					tile.activate_debug_color_overlay(regions[region]["debug color"])
			add_cheat_label("Showing Regions")
		else:
			for region in regions.keys():
				for tile in regions[region]["list"]:
					tile.deactivate_debug_color_overlay()
			remove_cheat_label("Showing Regions")
			
func add_cheat_label(text):
	print("Adding cheat label: " + text)
	var tempLabel = load("res://initiative_list_item.tscn").instantiate()
	tempLabel.set_text(text)
	$CanvasLayer/"Cheat Text Overlay Manager".add_child(tempLabel)
	$CanvasLayer/"Cheat Text Overlay Manager".queue_redraw()

func remove_cheat_label(text):
	print("Removing cheat label: " + text)
	for label in $CanvasLayer/"Cheat Text Overlay Manager".get_children():
		if label.get_text() == text:
			label.queue_free()


func move(character, dir):
	if character.isMoving or dir == Vector2.ZERO:
		$Camera2D.position = currentCharacter.position
		##print($Camera2D.position) #TEST
		return #don't need to do anything
	
	character.move(dir)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	move(currentCharacter,pressed_direction)
	#OLD INPUT
	#pass

func generate_terrain_tile(x: int, y: int):
	var tile = tile.instantiate()
	tile.tile_type = altitude_value(x, y)
	tile.position = Vector2(x, y) * TileSize
	$Tiles.add_child(tile)
	tileArray[currTileArrayY].append(tile)
	link_tile_to_neighbors(currTileArrayX,currTileArrayY)
#
	
func link_tile_to_neighbors(tileArrayX,tileArrayY):
	var tile = tileArray[tileArrayY][tileArrayX]
	if tileArrayX > 0 and tileArrayY > 0: #if it's not in the top row nor left column, link to what's up and left of it.
		tile.tileLinks[0][0] = tileArray[tileArrayY - 1][tileArrayX - 1]
		tileArray[tileArrayY - 1][tileArrayX - 1].tileLinks[2][2] = tile
	if tileArrayY > 0:
		tile.tileLinks[0][1] = tileArray[tileArrayY - 1][tileArrayX]
		tileArray[tileArrayY - 1][tileArrayX].tileLinks[2][1] = tile
		if tileArrayX < (int(MAP_SIZE_X) - 1):
			tile.tileLinks[0][2] = tileArray[tileArrayY - 1][tileArrayX + 1]
			tileArray[tileArrayY - 1][tileArrayX + 1].tileLinks[2][0] = tile
	if tileArrayX > 0:
		tile.tileLinks[1][0] = tileArray[tileArrayY][tileArrayX - 1]
		tileArray[tileArrayY][tileArrayX - 1].tileLinks[1][2] = tile

func determine_continents():
	#basically determines what island a given tile belongs to.
	#also gathers data in the continents dictionary that will prove useful later.
	var continentGrouperY = -1
	var continentGrouperX = -1
	var tempContinent = 999999
	for row in tileArray:
		continentGrouperY += 1
		for tile in row:
			tempContinent = 999999
			continentGrouperX += 1
			if tile.tile_type != tile.TileType.SEA:
				#check if any of the previous tiles it's connected to are part of a group. If they are, this one is too.
				if tile.tileLinks[0][0].continent > 0:
					tempContinent = tile.tileLinks[0][0].continent
				if tile.tileLinks[0][1].continent > 0 and tile.tileLinks[0][1].continent != tempContinent:
					if tile.tileLinks[0][1].continent > tempContinent:
						await combine_continents(tempContinent,tile.tileLinks[0][1].continent)
					tempContinent = tile.tileLinks[0][1].continent
				if tile.tileLinks[0][2].continent > 0 and tile.tileLinks[0][2].continent != tempContinent:
					if tile.tileLinks[0][2].continent > tempContinent:
						await combine_continents(tempContinent,tile.tileLinks[0][2].continent)
					tempContinent = tile.tileLinks[0][2].continent
				if tile.tileLinks[1][0].continent > 0 and tile.tileLinks[1][0].continent != tempContinent:
					if tile.tileLinks[1][0].continent > tempContinent:
						await combine_continents(tempContinent,tile.tileLinks[1][0].continent)
					elif tempContinent != 999999:
						await combine_continents(tile.tileLinks[1][0].continent, tempContinent)
						#This is dumb, but it seems to work, so... good enough for me.
					tempContinent = tile.tileLinks[1][0].continent
				
				if tempContinent == 999999: #we didn't find an existing group so let's make a new one
					tempContinent = add_new_continent()
				
				tile.set_continent(tempContinent)
				add_tile_to_continents(tile,tile.continent)
		continentGrouperX = -1
	#a little cleanup afterwards
	for entry in continents.keys():
		if continents[entry].is_empty():
			continents.erase(entry)
		elif continents[entry].count <= 6: #it only has 6 or fewer tiles? Too small, let's remove it.
			for tile in continents[entry]["list"]:
				tile.set_tile_type(0)
				#tile.$Label.visible = false
				tile.set_continent(0)
		else:
			continents[entry]["centerpoint"] /= continents[entry]["count"]

func remove_too_small_continents(numTileLimit:int):
	for entry in continents.keys():
		if continents[entry]["count"] <= numTileLimit:
			for tile in continents[entry]["list"]:
				tile.set_tile_type(0) #set each tile in the micro-continent to water
			continents.erase(entry) #and remove the continent entirely

func add_tile_to_continents(tile,continent:int):
	continents[continent]["count"] += 1
	continents[continent]["list"].append(tile)
	continents[continent]["centerpoint"] += tile.position

func combine_continents(oldContinentToKeep:int,oldContinentToRemove:int):
	continents[oldContinentToKeep]["count"] += continents[oldContinentToRemove]["count"]
	continents[oldContinentToKeep]["list"].append_array(continents[oldContinentToRemove]["list"])
	continents[oldContinentToKeep]["centerpoint"] += continents[oldContinentToRemove]["centerpoint"]
	for tile in continents[oldContinentToRemove]["list"]: #make sure those tiles get the message!
		tile.set_continent(oldContinentToKeep)
	continents[oldContinentToRemove].clear()
		

func add_new_continent():
	#make a blank continent!
	var newContinent = continents.size() + 1
	continents[newContinent] = {}
	continents[newContinent]["count"] = 0
	continents[newContinent]["list"] = []
	
	continents[newContinent]["centerpoint"] = Vector2.ZERO
	
	var randomVector = Vector2.ZERO
	randomVector.x = randf_range(-1,1)
	randomVector.y = randf_range(-1,1)
	continents[newContinent]["vector"] = randomVector
	return newContinent

func print_continents():
	var tempString = ""
	for continent in continents.keys():
		tempString = ""
		tempString = "Continent "+str(continent)+":\n"
		tempString += "    Count: "+str(continents[continent]["count"])+"\n"
		tempString += "    Vector: "+str(continents[continent]["vector"].x)+", "+str(continents[continent]["vector"].x)+"\n"
		tempString += "    Centerpoint: "+str(continents[continent]["centerpoint"])
		print(tempString)

func add_new_region():
	var newRegion = regions.size() + 1
	regions[newRegion] = {}
	regions[newRegion]["count"] = 0
	regions[newRegion]["list"] = []
	regions[newRegion]["origin"] = null
	regions[newRegion]["expanding edge tiles"] = []
	regions[newRegion]["expanding pythagoras bit"] = true
	regions[newRegion]["debug color"] = Color(randf(),randf(),randf(),0.5)
	
	regions[newRegion]["centerpoint"] = Vector2.ZERO
	return newRegion

func add_tile_to_regions(tile,region:int):
	tile.region = region
	if regions[region]["count"] == 0:
		regions[region]["origin"] = tile
		regions[region]["expanding edge tiles"].append(tile)
	regions[region]["count"] += 1
	regions[region]["list"].append(tile)
	regions[region]["centerpoint"] += tile.position

func expand_region(region:int):
	var temp_edge_tiles = regions[region]["expanding edge tiles"].duplicate()
	var temp_claimed_tiles = []
	for tile in temp_edge_tiles:
		for row in tile.tileLinks:
			for linkedTile in row:
				if linkedTile: #if it exists at all!
					#print("Thinking of adding a tile to region "+str(region)+"...")
					if (not regions[region]["expanding pythagoras bit"]) and (linkedTile == tile.tileLinks[0][0] or linkedTile == tile.tileLinks[0][2] or linkedTile == tile.tileLinks[2][0] or linkedTile == tile.tileLinks[2][2]):
						pass #the pythagoras two-step
					#print("Tile's region: "+str(linkedTile.region)+". Tile's type: "+str(linkedTile.tile_type)+".")
					elif linkedTile.region == 0 and linkedTile.tile_type != 0:
						#It's not water, and it's not claimed.
						#print("    Added a tile to region "+str(region))
						add_tile_to_regions(linkedTile,region)
						temp_claimed_tiles.append(linkedTile)
		regions[region]["expanding edge tiles"].erase(tile)
	regions[region]["expanding pythagoras bit"] = not regions[region]["expanding pythagoras bit"]
	print("Finished expanding region "+str(region)+". Number of tiles on the edge now: "+str(len(regions[region]["expanding edge tiles"])))
	return temp_claimed_tiles

func determine_regions_by_continent():
	print("Determining Regions...")
	var temp_origin_tile = Tile
	var temp_new_region = 0
	var temp_regions = []
	var temp_continent_tile_list = []
	var temp_region_edges_list = [] #this will be a 2d array
	var temp_tile_count = 0
	var temp_count_of_regions_to_make = 0
	var temp_captured_tiles = []
	for continent in continents.keys():
		print("Determining regions for Continent "+str(continent)+"...")
		#get the list of tiles; each continent starts fresh.
		temp_continent_tile_list = continents[continent]["list"]
		temp_tile_count = continents[continent]["count"]
		temp_regions = []
		#How many regions do we want?
		temp_count_of_regions_to_make = int(temp_tile_count / 80) + 1
		if randf() <= fmod((temp_tile_count / 80.0), 1.0):
			temp_count_of_regions_to_make += 1 #random chance of an additional one based on the math
		while temp_count_of_regions_to_make > 0:
			print("  Regions left to make: "+str(temp_count_of_regions_to_make))
			#pick a random spot to be the origin of our new region.
			temp_origin_tile = temp_continent_tile_list.pick_random()
			temp_new_region = add_new_region()
			temp_regions.append(temp_new_region)
			add_tile_to_regions(temp_origin_tile,temp_new_region)
			temp_continent_tile_list.erase(temp_origin_tile)
			#place that tile, and any tile within X tiles of it, 
			#    into a new region, while removing them from the temp list.
			for n in 3:
				temp_captured_tiles = expand_region(temp_new_region)
				for capturedTile in temp_captured_tiles:
					temp_continent_tile_list.erase(capturedTile)
			temp_count_of_regions_to_make -= 1 #we did a region, so remove it.
		#while not temp_continent_tile_list.is_empty():
			#
			#for region in temp_regions:
				#print("Trying to fill out Region "+str(region)+"...")
				#temp_captured_tiles = expand_region(region)
				#for capturedTile in temp_captured_tiles:
					#temp_continent_tile_list.erase(capturedTile)
		
		#Then fill in the rest of the tiles on that continent by expanding each region, bit by bit.

func map_smoother():
	#if two tiles of the same type are bookending something that isn't of that type,
	#smooth that out.
	var smoothingY = -1
	var smoothingX = -1
	for row in tileArray:
		smoothingY += 1
		for tile in row:
			smoothingX += 1
			if smoothingY == 0 or smoothingY == len(tileArray) - 1: #if it's the top or bottom row,
				tile.set_tile_type(tile.TileType.SEA) #make it water.
				#print("Row " + str(smoothingY) + ", Col "+ str(smoothingX) + ": forcing water.")
			elif smoothingX > 0 and smoothingX < len(row) - 1: #if it's in the middle somewhere,
				if tileArray[smoothingY][smoothingX - 1].tile_type == tileArray[smoothingY][smoothingX + 1].tile_type and tileArray[smoothingY][smoothingX - 1].tile_type != tileArray[smoothingY][smoothingX].tile_type: 
					#and the tiles to the left and right are the same,
					#TEST print("Row " + str(smoothingY) + ", Col "+ str(smoothingX) + ": was "+ str(tile.tile_type) +", forcing " + str(tileArray[smoothingY][smoothingX - 1].tile_type) + ".")
					tile.set_tile_type(tileArray[smoothingY][smoothingX - 1].tile_type) #smooth it out and make this tile those tile-types too
				elif tileArray[smoothingY - 1][smoothingX].tile_type == tileArray[smoothingY + 1][smoothingX].tile_type and tileArray[smoothingY - 1][smoothingX].tile_type != tileArray[smoothingY][smoothingX].tile_type: 
					#and the tiles above and below are the same,
					#TEST print("Row " + str(smoothingY) + ", Col "+ str(smoothingX) + ": was "+ str(tile.tile_type) +", forcing " + str(tileArray[smoothingY - 1][smoothingX].tile_type) + ".")
					tile.set_tile_type(tileArray[smoothingY - 1][smoothingX].tile_type) #smooth it out and make this tile those tile-types too
					
			else: #it's on the left or right edge, let's make it just water.
				tile.set_tile_type(tile.TileType.SEA)
				#print("Row " + str(smoothingY) + ", Col "+ str(smoothingX) + ": forcing water.")
		smoothingX = -1
		

func altitude_value(x: int, y: int) -> Tile.TileType:
	var value = altitude_noise.get_noise_2d(x, y)
	
	if value >= ForestLevel:
		return Tile.TileType.FOREST
	
	if value >= SeaLevel:
		return Tile.TileType.LAND
		
	return Tile.TileType.SEA


