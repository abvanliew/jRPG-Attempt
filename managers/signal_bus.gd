extends Node

signal start_next_turn(character)
signal end_of_round()
signal end_of_turn()
signal do_attack_from_instruction_list(user,target,instruction_list)
signal character_died(character)

signal scene_change(scene: SceneManager.SceneOption)
signal gold_changed()

signal save_game()
signal load_game()
signal successful_load()

@export var combatants_dict = {"hero":[],"enemy":[]}
@export var map_starting_location = Vector2.ONE

var tileEdgeSubstitutionDictionary = {
	"000001001":"000001000",
	"011101111":"111101111",
	"001001001":"000001000",
	"000000011":"000000010",
	"000000111":"000000010",
	"111000000":"010000000",
	"110000000":"010000000",
	"011000000":"010000000",
	"000001011":"000001111",
	"010001000":"011001000",
	"100100000":"000100000",
	"110001001":"011001000",
	"110100010":"110100000",
	"111100000":"110100000",
	"000100010":"000100000",
	"010001001":"011001000",
	"000000110":"000000010",
	"011001001":"011001000",
	"001001111":"000001111",
	"000101110":"000101111",
	"000101011":"000101111",
	"011100111":"110100110",
	"111001111":"011001011",
	"001001011":"000001111",
	"110100100":"110100000",
	"100100110":"000100111",
	"001001000":"000001000",
	"000100100":"000100000",
	"111001011":"011001011",
	"011001111":"011001011",
	"111001001":"011001000",
	"111001000":"011001000",
	"100100100":"000100000",
	"111100100":"110100000",
	"000100110":"000100111",
	"001000011":"001000010",
	"001000110":"001000010",
	"001000111":"001000010",
	"101100000":"001100000",
	"001100100":"001100000",
	"101100100":"001100000",
	"110000010":"010000010",
	"111000010":"010000010",
	"011000010":"010000010",
	"010000011":"010000010",
	"010000110":"010000010",
	"010000111":"010000010",
	"100101000":"000101000",
	"100101100":"000101000",
	"000101100":"000101000",
	"001101000":"000101000",
	"001101001":"000101000",
	"000101001":"000101000",
	"100101001":"000101000",
	"100101101":"000101000",
	"101101101":"000101000",
	"100100111":"000100111",
	"101101111":"000101111",
	"000101010":"000101111",
	"100100010":"000100111",
	"011101000":"111101000",
	"000001101":"000001100",
	"001001100":"000001100",
	"001001101":"000001100",
	"111101110":"111101111",
	"011101110":"111101111",
	"011100100":"110100000",
	"111101100":"111101000",
	"101101000":"000101000",
	"110100111":"110100110",
	"000100011":"000100111",
	"010001111":"011001011",
	"000001110":"000001111",
	"010101000":"111101000",
	"001101111":"000101111",
	"001001110":"000001111",
	"100101111":"000101111",
	"001001010":"000001111",
	"010100000":"110100000",
	"111101001":"111101000",
	"111100110":"110100110",
	"001101010":"000101111",
	"000001010":"000001111",
	"010101011":"111101111",
	"011101100":"111101000",
	"000101101":"000101000",
	"110101000":"111101000",
	"100100011":"000100111",
	"110101111":"111101111",
	"111100001":"010000001",
	"100001001":"100001000",
	"110000100":"010000100",
	"011000111":"010000010",
	"011000011":"010000010",
	"110000110":"010000010",
	"001101101":"000101000",
	"101101110":"000101111",
	"100000111":"100000010",
	"011100000":"110100000",
	"110000001":"010000001",
	"101000011":"101000010",
	"101000110":"101000010",
	"101000111":"101000010",
	"101001001":"100001000",
	"111100111":"110100110",
	"010100100":"110100000",
	"100100101":"000100001",
	"111101101":"111101000",
	"101001000":"100001000",
	"011000001":"010000001",
	"111101011":"111101111",
	"111100010":"110100100",
	"100000011":"100000010",
	"100000110":"100000010",
	
	
}