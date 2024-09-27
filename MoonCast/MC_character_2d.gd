@icon("res://MoonCast/assets/2dplayer.svg")
extends CharacterBody2D
##A 2D player in MoonCast
class_name MoonCastPlayer2D
#region Consts & Enums
##State flags for various things the player can do or is doing.
enum StateFlags {
	##Flag for the player moving. This means they are traveling
	##above the minimum ground speed.
	MOVING = 1,
	##Flag for the player being on the ground. If this is not set,
	##the player is in the air.
	is_grounded = 2, 
	##Flag for the player rolling.
	ROLLING = 4,
	##Flag for the player jumping.
	JUMPING = 8,
	##Flag for the player balancing on a ledge.
	BALANCING = 16,
	##Flag for the player crouching.
	CROUCHING = 32,
	##Flag for rotation lock. This prevents the player from changing directions.
	CHANGE_DIRECTION = 64,
	##Flag for pushing an object.
	PUSHING = 128,
	##Flag for slipping on the ground.
	SLIPPING = 256
}

const perf_ground_velocity:StringName = &"Ground Velocity"
const perf_ground_angle:StringName = &"Ground Angle"
const perf_state:StringName = &"Player State"

##The sfx name for [member sfx_jump].
const sfx_jump_name:StringName = &"jump"
##The sfx name for [member sfx_roll].
const sfx_roll_name:StringName = &"roll"
##The sfx name for [sfx_skid].
const sfx_skid_name:StringName = &"skid"
##The sfx name for [sfx_hurt].
const sfx_hurt_name:StringName = &"hurt"
#endregion
#region Exported Vars
@export_group("Physics & Controls")
##The physics table for this player.
@export var physics:MoonCastPhysicsTable = MoonCastPhysicsTable.new()
##The control settings for this player.
@export var controls:MoonCastControlSettings = MoonCastControlSettings.new()
##The default direction of gravity.
@export var default_up_direction:Vector2 = Vector2.UP

@export_group("Rotation", "rotation_")
##If true, classic rotation snapping will be used, for a more "Genesis" feel.
##Otherwise, rotation operates smoothly, like in Sonic Mania. This is purely aesthetic.
@export var rotation_classic_snap:bool = false
##The value, in radians, that the sprite rotation will snap to when classic snap is active.
##The default value is equal to 30 degrees.
@export_custom(PROPERTY_HINT_RANGE, "radians_as_degrees, 90.0", PROPERTY_USAGE_EDITOR) var rotation_snap_interval:float = deg_to_rad(30.0)
##The amount per frame, in radians, at which the player's rotation will adjust to 
##new angles, such as how fast it will move back to 0 when airborne or how fast it 
##will adjust to slopes.
@export_range(0.0, 1.0) var rotation_adjustment_speed:float = 0.2
##If this is true, collision boxes of the character will not rotate based on 
##ground angle, mimicking the behavior of RSDK titles.
@export var rotation_static_collision:bool = false

@export_group("Camera", "camera_")
##How many pixels above the player the camera will move to when the player holds up at a standstill.
@export var camera_look_up_offset:int
##How many pixels below the player the camera will move to when the player holds down at a standstill.
@export var camera_look_down_offset:int
##The offset from the player's position (center on screen) the camera will sit at.
@export var camera_neutral_offset:Vector2
##How fast the camera will move around.
@export var camera_move_speed:float

@export_group("Animations", "anim_")
##The animation to play when standing still.
@export var anim_stand:StringName
##The animation for looking up.
@export var anim_look_up:StringName
##The animation for balancing with more ground.
@export var anim_balance:StringName
##The animation for crouching.
@export var anim_crouch:StringName
##The animation for rolling.
@export var anim_roll:StringName
##The animations for when the player is walking or running on the ground.
##[br]The key is the minimum percentage of [member ground_velocity] in relation
##to [member physics.ground_top_speed] that the player must be going for this animation
##to play, and the value for that key is the animation that will play.
##[br]Note: Keys should not use decimal values more precise than thousandths.
@export var anim_run:Dictionary[float, StringName]
##The animations for when the player is skidding to a halt.
##The key is the minimum percentage of [member ground_velocity] in relation
##to [member physics.ground_top_speed] that the player must be going for this animation
##to play, and the value for that key is the animation that will play.
##[br]Note: Keys should not use decimal values more precise than thousandths.
@export var anim_skid:Dictionary[float, StringName]
##Animation to play when pushing a wall or object.
@export var anim_push:StringName
##The animation to play when jumping.
@export var anim_jump:StringName
##The animation to play when falling without being hurt or in a ball.
@export var anim_free_fall:StringName
##The default animation to play when the player dies.
@export var anim_death:StringName
##A set of custom animations to play when the player dies for various abnormal reasons.
##The key is their reason of death, and the value is the animation that will play.
@export var anim_death_custom:Dictionary[StringName, StringName]

##A list of animations that will not be rotated to align to the ground.
##In the air, the player's animation rotation will always be 0, regardless of being in this
##list or not.
@export var anim_rotation_blacklist:Array[StringName]
##A list of animations that will vary in playback speed based on the value of [member ground_velocity].
@export var anim_vary_speed_playback:Array[StringName]

@export_group("Sound Effects", "sfx_")
##The audio bus to play sound effects on.
@export var sfx_bus:StringName = &"Master"
##THe sound effect for jumping.
@export var sfx_jump:AudioStream
##The sound effect for rolling.
@export var sfx_roll:AudioStream
##The sound effect for skidding.
@export var sfx_skid:AudioStream
##The sound effect for getting hurt.3
@export var sfx_hurt:AudioStream
##A Dictionary of custom sound effects. 
@export var sfx_custom:Dictionary[StringName, AudioStream]
#endregion
#region Node references
#generally speaking, these should *not* be directly accessed unless absolutely needed, 
#but they still have documentation because documentation is good
##The AnimationPlayer for all the animations triggered by the player.
##If you have an [class AnimatedSprite2D], you do not need a child [class Sprite2D] nor [class AnimationPlayer].
var animations:AnimationPlayer = null
##The Sprite2D node for this player.
##If you have an AnimatedSprite2D, you do not need a child Sprite2D nor AnimationPlayer.
var sprite1:Sprite2D = null
##The AnimatedSprite2D for this player.
##If you have an AnimatedSprite2D, you do not need a child Sprite2D nor AnimationPlayer.
var animated_sprite1:AnimatedSprite2D = null

##A central node around which all the raycasts rotate.
var raycast_wheel:Node2D = Node2D.new()
##The left ground raycast, used for determining balancing and rotation.
##[br]
##Its position is based on the farthest down and left [CollisionShape2D] shape that 
##is a child of the player (ie. it is not going to account for collision shapes that
##aren't going to touch the ground due to other lower shapes), and it points to that 
##shape's lowest reaching y value, plus [floor_snap_length] into the ground.
var ray_ground_left:RayCast2D = RayCast2D.new()
##The right ground raycast, used for determining balancing and rotation.
##Its position and target_position are determined the same way ray_ground_left.position
##are, but for rightwards values.
var ray_ground_right:RayCast2D = RayCast2D.new()
##The central raycast, used for balancing. This is based on the central point values 
##between ray_ground_left and ray_ground_right.
var ray_ground_central:RayCast2D = RayCast2D.new()
##The left wall raycast. Used for detecting running into a "wall" relative to the 
##player's rotation
var ray_wall_left:RayCast2D = RayCast2D.new()
##The right wall raycast. Used for detecting running into a "wall" relative to the 
##player's rotation
var ray_wall_right:RayCast2D = RayCast2D.new()
##The sfx player node
var sfx_player:AudioStreamPlayer = AudioStreamPlayer.new()
##The sfx player node's AudioStreamPolyphonic
var sfx_player_res:AudioStreamPolyphonic = AudioStreamPolyphonic.new()

var sfx_playback_ref:AudioStreamPlaybackPolyphonic

##The timer for the player's ability to jump after landing.
var jump_timer:Timer = Timer.new()
##The timer for the player's ability to move directionally.
var control_lock_timer:Timer = Timer.new()
##The timer for the player to be able to stick to the floor.
var ground_snap_timer:Timer = Timer.new()

var camera:Camera2D

#endregion
#region API storage vars
##The names of all the abilities of this character.
var abilities:Array[StringName]
##A custom data pool for the ability ECS.
##It's the responsibility of the different abilities to be implemented in a way that 
##does not abuse this pool.
var ability_data:Dictionary = {}
##Custom states for the character. This is a list of Abilities that have registered 
##themselves as a state ability, which can implement an entirely new state for the player.
var state_abilities:Array[StringName]

##The current animation
var current_anim:StringName

var anim_run_lib:SpeedVariedAnimLib = SpeedVariedAnimLib.new()
var anim_skid_lib:SpeedVariedAnimLib = SpeedVariedAnimLib.new()
#endregion
#region physics vars
##The player's current state.
##A signal is emitted when certain values are changed, such as emitting the contact state signals.
var state_is:int
##The state(s) the player can currently be in.
##These are just what the player [i]can[/i] do, not what they necessarily [i]are doing[/i].
var state_can_be:int
##The direction the player is facing. Either -1 for left or 1 for right.
var facing_direction:float = 1.0

##If this is negative, the player is pressing left. If positive, they're pressing right.
##If zero, they're pressing nothing (or their input is being ignored cause they shouldn't move)
var input_direction:float = 0:
	set(new_dir):
		input_direction = new_dir
		if can_change_direction and not is_zero_approx(new_dir):
			facing_direction = signf(new_dir)
##Set to true when an animation is set in the physics frame 
##so that some other animations don't override it.
##Automatically resets to false at the start of each physics frame
##(before the pre-physics ability signal).
var animation_set:bool = false

## the ground velocity. This is how fast the player is 
##travelling on the ground, regardless of angles.
var ground_velocity:float = 0:
	set(new_gvel):
		ground_velocity = new_gvel
		is_moving = absf(ground_velocity) > physics.ground_min_speed
##The character's current velocity in space.
var space_velocity:Vector2 = Vector2.ZERO
##The character's direction of travel.
##Equivalent to get_position_delta().normalized().sign()
var velocity_direction:Vector2
##The original value of floor_max_angle
var default_max_angle:float

#endregion
#region state_can_be bitfield
##If true, the player can jump.
var can_jump:bool = true:
	set(on):
		if on and jump_timer.is_stopped():
			state_can_be |= StateFlags.JUMPING
		else:
			state_can_be &= ~StateFlags.JUMPING
	get:
		return state_can_be & StateFlags.JUMPING
##If true, the player can move. 
var can_move:bool = true:
	set(on):
		if on:
			state_can_be |= StateFlags.MOVING
		else:
			state_can_be &= ~StateFlags.MOVING
	get:
		return state_can_be & StateFlags.MOVING
##If true, the player can move. 
var can_roll:bool = true:
	set(on):
		if physics.control_rolling_enabled:
			if physics.control_move_roll_lock:
				if on and is_zero_approx(input_direction):
					state_can_be |= StateFlags.ROLLING
				else:
					state_can_be &= ~StateFlags.ROLLING
			else:
				if on:
					state_can_be |= StateFlags.ROLLING
				else:
					state_can_be &= ~StateFlags.ROLLING
		else:
			state_can_be &= ~StateFlags.ROLLING
	get:
		return state_can_be & StateFlags.ROLLING
##If true, the player can crouch.
var can_crouch:bool = true:
	set(on):
		if on:
			state_can_be |= StateFlags.CROUCHING
		else:
			state_can_be &= ~StateFlags.CROUCHING
	get:
		return state_can_be & StateFlags.CROUCHING
##If true, the player can change direction.
var can_change_direction:bool = true:
	set(on):
		if on:
			state_can_be |= StateFlags.CHANGE_DIRECTION
		else:
			state_can_be &= ~StateFlags.CHANGE_DIRECTION
	get:
		return state_can_be & StateFlags.CHANGE_DIRECTION
var can_push:bool = true:
	set(can_now_push):
		if can_now_push:
			state_can_be |= StateFlags.PUSHING
		else:
			state_can_be &= ~StateFlags.PUSHING
	get:
		return state_can_be & StateFlags.PUSHING
#endregion
#region state_is bitfield
##If true, the player is on what the physics consider 
##to be the ground.
##A signal is emitted whenever this value is changed;
##contact_air when false, and contact_ground when true
var is_grounded:bool:
	set(now_grounded):
		if now_grounded:
			#check before the value is actually set
			if not is_grounded:
				contact_ground.emit(self)
			state_is |= StateFlags.is_grounded
		else:
			#check before the value is actually set
			if is_grounded:
				contact_air.emit(self)
			state_is &= ~StateFlags.is_grounded
	get:
		return state_is & StateFlags.is_grounded
##If true, the player is moving.
var is_moving:bool:
	set(on):
		if on:
			state_is |= StateFlags.MOVING
			can_crouch = false
		else:
			state_is &= ~StateFlags.MOVING
	get:
		return state_is & StateFlags.MOVING
##If true, the player is in a jump.
var is_jumping:bool:
	set(on):
		if on:
			state_is |= StateFlags.JUMPING
		else:
			state_is &= ~StateFlags.JUMPING
	get:
		return state_is & StateFlags.JUMPING
##If true, the player is rolling.
var rolling:bool:
	set(on):
		if on:
			can_change_direction = false
			state_is |= StateFlags.ROLLING
		else:
			can_change_direction = true
			state_is &= ~StateFlags.ROLLING
	get:
		return state_is & StateFlags.ROLLING
##If true, the player is crouching.
var is_crouching:bool:
	set(on):
		if on:
			state_is |= StateFlags.CROUCHING
			#walking out of a crouch should not be possible
			can_move = false
		else:
			state_is &= ~StateFlags.CROUCHING
			#re-enable movement
			can_move = true
	get:
		return state_is & StateFlags.CROUCHING
##If true, the player is balacing on the edge of a platform.
##This causes certain core abilities to be disabled.
var is_balancing:bool = false:
	set(on):
		if on:
			state_is |= StateFlags.BALANCING
			can_crouch = false
		else:
			state_is &= ~StateFlags.BALANCING
			can_crouch = true
	get:
		return state_is & StateFlags.BALANCING
var is_pushing:bool = false:
	set(now_pushing):
		if now_pushing and can_push:
			if not is_pushing:
				print("Pushing a wall")
				contact_wall.emit()
			state_is |= StateFlags.PUSHING
		else:
			state_is &= ~StateFlags.PUSHING
	get:
		return state_is & StateFlags.PUSHING
#endregion

##The rotation of the sprites. This is seperate than the physics
##rotation so that physics remain consistent despite certain rotation
##settings.
var sprite_rotation:float
##The rotation of the collision. when is_grounded, this is the ground angle.
##In the air, this should be 0.
var collision_rotation:float:
	get:
		if rotation_static_collision:
			return raycast_wheel.rotation
		else:
			return rotation
	set(new_rot):
		if rotation_static_collision:
			raycast_wheel.rotation = new_rot
		else:
			rotation = new_rot
##Collision rotation in global units.
var global_collision_rotation:float:
	get:
		if rotation_static_collision:
			return raycast_wheel.global_rotation
		else:
			return global_rotation
	set(new_rot):
		if rotation_static_collision:
			raycast_wheel.global_rotation = new_rot
		else:
			global_rotation = new_rot

##The name of the custom performance monitor for ground_velocity
var self_perf_ground_vel:StringName
##The name of the custom performance monitor for the ground angle
var self_perf_ground_angle:StringName
##The name of the custom performance monitor for state
var self_perf_state:StringName

#processing signals, for the Ability system
##Emitted before processing physics 
signal pre_physics(player:MoonCastPlayer2D)
##Emitted after processing physics
signal post_physics(player:MoonCastPlayer2D)
##Emitted when the player jumps
signal jump(player:MoonCastPlayer2D)
##Emitted when the player is hurt
signal hurt(player:MoonCastPlayer2D)
##Emitted when the player collects something, like a shield or ring
signal collectible_recieved(player:MoonCastPlayer2D)
##Emitted when the player makes contact with the ground
signal contact_ground(player:MoonCastPlayer2D)
##Emitted when the player makes contact with a wall
signal contact_wall(player:MoonCastPlayer2D)
##Emitted when the player is now airborne
signal contact_air(player:MoonCastPlayer2D)
##Emitted every frame when the player is touching the ground
signal state_ground(player:MoonCastPlayer2D)
##Emitted every frame when the player is in the air
signal state_air(player:MoonCastPlayer2D)

##Detect specific child nodes and properly set them up, such as setting
##internal node references and automatically setting up abilties.
func setup_children() -> void:
	#find the animationPlayer and other nodes
	for nodes in get_children():
		if not is_instance_valid(animations) and nodes is AnimationPlayer:
			animations = nodes
		if not is_instance_valid(sprite1) and nodes is Sprite2D:
			sprite1 = nodes
		if not is_instance_valid(animated_sprite1) and nodes is AnimatedSprite2D:
			animated_sprite1 = nodes
		#Patch for the inability for get_class to return GDScript classes
		if nodes.has_meta(&"Ability_flag"):
			abilities.append(nodes.name)
			nodes.call(&"setup_ability_2D", self)
	
	jump_timer.name = "JumpTimer"
	add_child(jump_timer)
	control_lock_timer.name = "ControlLockTimer"
	add_child(control_lock_timer)
	ground_snap_timer.name = "GroundSnapTimer"
	add_child(ground_snap_timer)
	
	sfx_player.name = "SoundEffectPlayer"
	add_child(sfx_player)
	sfx_player.stream = sfx_player_res
	sfx_player.bus = sfx_bus
	sfx_player.play()
	sfx_playback_ref = sfx_player.get_stream_playback()
	
	#Add the raycasts to the scene
	raycast_wheel.name = "Raycast Rotator"
	add_child(raycast_wheel)
	ray_ground_left.name = "RayGroundLeft"
	raycast_wheel.add_child(ray_ground_left)
	ray_ground_right.name = "RayGroundRight"
	raycast_wheel.add_child(ray_ground_right)
	ray_ground_central.name = "RayGroundCentral"
	raycast_wheel.add_child(ray_ground_central)
	ray_wall_left.name = "RayWallLeft"
	raycast_wheel.add_child(ray_wall_left)
	ray_wall_right.name = "RayWallRight"
	raycast_wheel.add_child(ray_wall_right)
	
	#If we have an AnimatedSprite2D, not having the other two doesn't matter
	if not is_instance_valid(animated_sprite1):
		#we need either an AnimationPlayer and Sprite2D, or an AnimatedSprite2D,
		#but having both is optional. Therefore, only warn about the lack of the latter
		#if one of the two for the former is missing.
		var warn:bool = false
		if not is_instance_valid(animations):
			push_error("No AnimationPlayer found for ", name)
			warn = true
		if not is_instance_valid(sprite1):
			push_error("No Sprite2D found for ", name)
			warn = true
		if warn:
			push_error("No AnimatedSprite2D found for ", name)

#region Performance Monitor
##Set up the custom performance monitors for the player
func setup_performance_monitors() -> void:
	self_perf_ground_angle = name + &"/" + perf_ground_angle
	self_perf_ground_vel = name + &"/" + perf_ground_velocity
	self_perf_state = name + &"/" + perf_state
	Performance.add_custom_monitor(self_perf_ground_angle, get, [&"collision_rotation"])
	Performance.add_custom_monitor(self_perf_ground_vel, get, [&"ground_velocity"])
	Performance.add_custom_monitor(self_perf_state, get, [&"state_is"])

##Clean up the custom performance monitors for the player
func cleanup_performance_monitors() -> void:
	Performance.remove_custom_monitor(self_perf_ground_angle)
	Performance.remove_custom_monitor(self_perf_ground_vel)
	Performance.remove_custom_monitor(self_perf_state)
#endregion
#region Animation API
##A wrapper function to play animations, with built in validity checking.
##This will check for a valid AnimationPlayer [i]before[/i] a valid AnimatedSprite2D, and will
##play the animation on both of them if it can find it on both of them.
##[br][br] By defualt, this is set to stop playing animations after one has been played this frame. 
##The optional force parameter can be used to force-play an animation, even if one has 
##already been set this frame.
func play_animation(anim_name:StringName, force:bool = false) -> void:
	if (force or not animation_set):
		if is_instance_valid(animations) and animations.has_animation(anim_name):
			animations.play(anim_name)
			animation_set = true
		if is_instance_valid(animated_sprite1.sprite_frames) and animated_sprite1.sprite_frames.has_animation(anim_name):
			animated_sprite1.play(anim_name)
			animation_set = true
		current_anim = anim_name

##A special function for sequencing several animations in a chain. The array this takes in as a 
##parameter is assumed to be in the order that you want the animations to play.
func sequence_animations(animation_array:Array[StringName]) -> void:
	for anims:StringName in animation_array:
		pass

##A function to check for if either a child AnimationPlayer or AnimatedSprite2D has an animation.
##This will check for a valid AnimationPlayer [i]before[/i] a valid AnimatedSprite2D, and will 
##return true if the former has an animation even if the latter does not.
func has_animation(anim_name:StringName) -> bool:
	if is_instance_valid(animations):
		return animations.has_animation(anim_name)
	elif is_instance_valid(animated_sprite1):
		return animated_sprite1.sprite_frames.has_animation(anim_name)
	else:
		return false
#endregion
#region Ability API
##Find out if a character has a given ability.
##Ability names are dictated by the name of the node.
func has_ability(ability_name:StringName) -> bool:
	return abilities.has(ability_name)

##Add an ability to the character at runtime.
##Ability names are dictated by the name of the node.
func add_ability(ability_name:MoonCastAbility) -> void:
	add_child(ability_name)
	abilities.append(ability_name.name)
	ability_name.call(&"setup_ability_2D", self)

##Get the MoonCastAbility of the named ability, if the player has it.
##This will return null and show a warning if the ability is not found.
func get_ability(ability_name:StringName) -> MoonCastAbility:
	if has_ability(ability_name):
		return get_node(NodePath(ability_name))
	else:
		push_warning("The character ", name, " doesn't have the ability \"", ability_name, "\"")
		return null

##Remove an ability from the character at runtime.
##Ability names are dictated by the name of the node.
func remove_ability(ability_name:StringName) -> void:
	if has_ability(ability_name):
		abilities.remove_at(abilities.find(ability_name))
		var removing:MoonCastAbility = get_node(NodePath(ability_name))
		remove_child(removing)
		removing.queue_free()
	else:
		push_warning("The character ", name, " doesn't have the ability \"", ability_name, "\" that was called to be removed")
#endregion
#region Sound Effect API
##Add or update a sound effect on this player.
##If a name is already registered, providing a different stream will assign a new 
##stream to that name.
func add_edit_sound_effect(sfx_name:StringName, sfx_stream:AudioStream) -> void:
	sfx_custom[sfx_name] = sfx_stream

##Play a sound effect that belongs to the player. This can be either a custom sound
##effect, or one of the hard coded/built in sound effects. 
func play_sound_effect(sfx_name:StringName) -> void:
	var wrapper:Callable = func(sfx:AudioStream) -> void: 
		if is_instance_valid(sfx) and not is_zero_approx(sfx.get_length()):
			sfx_playback_ref.play_stream(sfx, 0.0, 0.0, 1.0, AudioServer.PLAYBACK_TYPE_DEFAULT, sfx_bus)
	
	match sfx_name:
		sfx_jump_name:
			wrapper.call(sfx_jump)
		sfx_roll_name:
			wrapper.call(sfx_roll)
		sfx_skid_name:
			wrapper.call(sfx_skid)
		sfx_hurt_name:
			wrapper.call(sfx_hurt)
		_:
			if sfx_custom.has(sfx_name):
				wrapper.call(sfx_custom.get(sfx_name))

func check_sound_effect(sfx_name:StringName, sfx_stream:AudioStream) -> int:
	var bitfield:int = 0
	const builtin_sfx:Array[StringName] = [sfx_roll_name]
	if sfx_custom.has(sfx_name):
		bitfield |= 0b0000_0001
	if sfx_custom.values().has(sfx_stream):
		bitfield |= 0b0000_0010
	
	return bitfield
#endregion
#region State API
##Check the player's current state with a bitfield of values
func check_current_state(check:int) -> int:
	return check & state_is

##Check the player's possible state with a bitfield of values
func check_possible_state(check:int) -> int:
	return check & state_can_be

##Returns if the player is going left
func is_going_left() -> bool:
	if is_grounded:
		return is_moving and ground_velocity < 0
	else:
		#TODO: Make this properly check relative to default_up_direction
		return space_velocity.x < 0

##Returns if the player is going right
func is_going_right() -> bool:
	if is_grounded:
		return is_moving and ground_velocity > 0
	else:
		#TODO: Make this properly check relative to default_up_direction
		return space_velocity.x > 0
#endregion
#region Physics calculations
##Returns the given angle as an angle (in radians) between -PI and PI
##Unlike the built in angle_difference function, return value for 0 and 180 degrees
#is flipped.
func limitAngle(input_angle:float) -> float:
	var return_angle:float = angle_difference(0, input_angle)
	if is_equal_approx(absf(return_angle), PI) or is_zero_approx(return_angle):
		return_angle = -return_angle
	return return_angle

#Note: In C++, I would overwrite set_collision_layer in order to automatically 
#update the child raycasts with it. But, I cannot overwrite it in GDScript, so...

##Assess the CollisionShape children (hitboxes of the character) and accordingly
##set some internal sensors to their proper positions, among other things.
func setup_collision() -> void:
	#find the two "lowest" and farthest out points among the shapes, and the lowest 
	#left and lowest right points are where the ledge sensors will be placed. These 
	#will be mostly used for ledge animation detection, as the collision system 
	#handles most of the rest for detection that these would traditionally be used 
	#for.
	
	#The lowest left point for collision among the player's hitboxes
	var ground_left_corner:Vector2
	#The lowest right point for collision among the player's hitboxes
	var ground_right_corner:Vector2
	
	for collision_shapes:int in get_shape_owners():
		for shapes:int in shape_owner_get_shape_count(collision_shapes):
			#Get the shape itself
			var this_shape:Shape2D = shape_owner_get_shape(collision_shapes, shapes)
			#Get the shape's node, for stuff like position
			var this_shape_node:Node2D = shape_owner_get_owner(collision_shapes)
			
			#If this shape's node isn't higher up than the player's origin
			#(ie. it's on the player's lower half)
			if this_shape_node.position.y >= 0:
				var shape_outmost_point:Vector2 = this_shape.get_rect().end
				#the lower right corner of the shape
				var collision_outmost_right:Vector2 = this_shape_node.position + shape_outmost_point
				#The lower left corner of the shape
				var collision_outmost_left:Vector2 = this_shape_node.position + Vector2(-shape_outmost_point.x, shape_outmost_point.y)
				
				#If it's farther down vertically than either of the max points
				if collision_outmost_left.y >= ground_left_corner.y or collision_outmost_right.y >= ground_right_corner.y:
					#If it's farther left than the most left point so far...
					if collision_outmost_left.x < ground_left_corner.x:
						ground_left_corner = collision_outmost_left
					#Otherwise, if it's farther right that the most right point so far...
					if collision_outmost_right.x > ground_right_corner.x:
						ground_right_corner = collision_outmost_right
	
	#place the raycasts based on the above derived values
	
	var ground_safe_margin:int = int(floor_snap_length)
	
	ray_ground_left.position.x = ground_left_corner.x
	ray_ground_left.target_position.y = ground_left_corner.y + ground_safe_margin
	ray_ground_left.collision_mask = collision_mask
	ray_ground_left.add_exception(self)
	
	ray_ground_right.position.x = ground_right_corner.x
	ray_ground_right.target_position.y = ground_right_corner.y + ground_safe_margin
	ray_ground_right.collision_mask = collision_mask
	ray_ground_right.add_exception(self)
	
	ray_ground_central.position.x = (ground_left_corner.x + ground_right_corner.x) / 2.0
	ray_ground_central.target_position.y = ((ground_left_corner.y + ground_right_corner.y) / 2.0) + ground_safe_margin
	ray_ground_central.collision_mask = collision_mask
	ray_ground_central.add_exception(self)
	
	
	#TODO: Place these better; they should be targeting the x pos of the absolute
	#farthest horizontal collision boxes, not only the ground-valid boxes
	ray_wall_left.target_position = Vector2(ground_left_corner.x - 1, 0)
	ray_wall_left.add_exception(self)
	
	ray_wall_right.target_position = Vector2(ground_right_corner.x + 1, 0)
	ray_wall_right.add_exception(self)

##Process the player's air physics
func process_air() -> void:
	# Allow the player to change the duration of the jump by releasing the jump
	# button early
	if not Input.is_action_pressed(controls.action_jump) and is_jumping:
		space_velocity.y = maxf(space_velocity.y, -physics.jump_short_limit)
	
	if not rolling and roll_checks() and Input.is_action_pressed(controls.action_roll):
		rolling = true
		play_animation(anim_roll)
		play_sound_effect(sfx_roll_name)
	
	# air-based movement
	#Only let the player accelerate if they aren't already at max speed
	if absf(space_velocity.x) < physics.ground_top_speed and not is_zero_approx(input_direction):
		space_velocity.x += physics.air_acceleration * input_direction
	
	#calculate air drag
	if space_velocity.y < 0 and space_velocity.y > -physics.jump_short_limit:
		space_velocity.x -= (space_velocity.x * 0.125) / 256
	
	# apply gravity
	space_velocity.y += physics.air_gravity_strength


##Process the player's ground physics
func process_ground() -> void:
	var sine_ground_angle:float = sin(collision_rotation)
	
	#Calculate movement based on the mode
	if rolling:
		#Calculate rolling
		
		#apply gravity
		ground_velocity += physics.air_gravity_strength * sine_ground_angle
		
		#apply slope factors
		
		if is_zero_approx(collision_rotation): #If we're on level ground
			#If we're also moving at all
			if not is_zero_approx(ground_velocity):
				ground_velocity -= physics.rolling_flat_factor * facing_direction
		else: #We're on a hill of some sort
			if is_equal_approx(signf(ground_velocity), signf(sine_ground_angle)):
				#rolling downhill
				ground_velocity += physics.rolling_downhill_factor * sine_ground_angle
			else:
				#rolling uphill
				ground_velocity += physics.rolling_uphill_factor * sine_ground_angle
		
		#Check if the player wants to (and can) jump
		if Input.is_action_just_pressed(controls.action_jump) and can_jump:
			is_jumping = true
		
		#Allow the player to actively slow down if they try to move in the opposite direction
		if not is_equal_approx(facing_direction, signf(ground_velocity)):
			ground_velocity += physics.rolling_active_stop * facing_direction
			facing_direction = -facing_direction
			sprites_flip()
	else:
		#slope factors for being on foot
		if is_moving:
			#apply gravity if we're on a slope and not standing still
			ground_velocity += physics.air_gravity_strength * sine_ground_angle
			
			#Apply the standing/running slope factor if we're not in ceiling mode
			#These two magic numbers are 45 degrees and 135 degrees as radians, respectively
			if not (global_collision_rotation > 0.7853982 and global_collision_rotation < 2.356194):
				ground_velocity += physics.ground_slope_factor * sine_ground_angle
		else:
			#don't allow standing on steep slopes
			if fmod(absf(global_collision_rotation), PI) >= fmod(default_max_angle, PI):
				ground_velocity += physics.ground_slope_factor * sine_ground_angle
		
		#Check if the player wants to (and can) jump
		if Input.is_action_pressed(controls.action_jump) and can_jump:
			is_jumping = true
		
		#input processing
		if is_zero_approx(input_direction): #handle input-less deceleration
			if not is_zero_approx(ground_velocity):
				ground_velocity = move_toward(ground_velocity, 0.0, physics.ground_deceleration)
			#snap ground velocity to the minimum ground speed
			if not is_moving:
				ground_velocity = 0
		#If input matches the direction we're going
		elif is_equal_approx(facing_direction, signf(ground_velocity)):
			#If we *can* add speed (can't add above the top speed)
			if absf(ground_velocity) < physics.ground_top_speed:
				ground_velocity += physics.ground_acceleration * facing_direction
		else: #We're going opposite to the facing direction, so apply skid mechanic
			ground_velocity += physics.ground_skid_speed * facing_direction
			
			for speeds:float in anim_skid_lib.sorted_keys:
				if absf(ground_velocity) > physics.ground_top_speed * speeds:
					
					#correct the direction of the sprite
					facing_direction = -facing_direction
					sprites_flip()
					
					#They were snapped earlier, but I find that it still won't work
					#unless I snap them here
					play_animation(anim_skid.get(snappedf(speeds, 0.001), &"RESET"), true)
					
					#only play skid anim once while skidding
					if not anim_skid.values().has(current_anim):
						play_sound_effect(sfx_skid_name)
					break
	
	#Do rolling or crouching checks
	
	#if the player is moving fast enough and can be rolling according to external settings
	if absf(ground_velocity) > physics.rolling_min_speed:
		#We're moving too fast to crouch
		is_crouching = false
		
		#Roll if the player tries to, and is not already rolling
		if roll_checks() and not rolling and Input.is_action_pressed(controls.action_roll):
			rolling = true
			play_sound_effect(sfx_roll_name)
		
	else: #standing or crouching
		#Disable rolling
		can_roll = false
		rolling = false
		#don't allow crouching when balacing
		if not is_balancing:
			#Only crouch while the input is still held down
			if Input.is_action_pressed(controls.direction_down):
				if not is_crouching and can_move: #only crouch if we weren't before
					is_crouching = true
			else: #down is not held, uncrouch
				#Re-enable controlling and return the player to their standing state
				if is_crouching:
					is_crouching = false
					can_move = true
	
	#jumping logic
	
	#This is a shorthand for Vector2(cos(collision_rotation), sin(collision_rotation))
	#we need to calculate this before we leave the ground, becuase collision_rotation
	#is reset when we do
	var rotation_vector:Vector2 = Vector2.from_angle(collision_rotation)
	
	if is_jumping:
		jump.emit(self)
		#Add velocity to the jump
		space_velocity.x += physics.jump_velocity * rotation_vector.y
		space_velocity.y -= physics.jump_velocity * rotation_vector.x
		
		is_grounded = false
		
		play_animation(anim_jump, true)
		play_sound_effect(sfx_jump_name)
		
		#the following does not apply if we are already rolling
		if not rolling:
			#rolling is used as a shorthand for if the player is 
			#"attacking". Therefore, it should not be set if the player
			#should be vulnerable in midair
			rolling = not  physics.control_is_jump_vulnerable
	else:
		#apply the ground velocity to the "actual" velocity
		space_velocity = ground_velocity * rotation_vector


func roll_checks() -> bool:
	#check this first, cause if we aren't allowed to roll externally, we don't
	#need the more nitty gritty checks
	if  physics.control_rolling_enabled:
		#If the player is is_grounded, they can roll, since the previous check for
		#it being enabled is true. If they're in the air though, they can only 
		#roll if they can midair roll, and they aren't already rolling
		can_roll = true if is_grounded else (physics.control_can_midair_roll and not rolling)
		
		#we only care about this check if the player isn't already rolling, so that
		#external influences on rolling, such as tubes, are not affected
		if not rolling and physics.control_move_roll_lock:
			#only allow rolling if we aren't going left or right actively
			can_roll = can_roll and is_zero_approx(input_direction)
	
	else:
		can_roll = false
	return can_roll

##A function that is called when the player enters the air from
##previously being on the ground
func enter_air(_player:MoonCastPlayer2D = null) -> void:
	collision_rotation = 0

##A function that is called when the player lands on the ground
##from previously being in the air
func land_on_ground(_player:MoonCastPlayer2D = null) -> void:
	#Transfer space_velocity to ground_velocity
	var applied_ground_speed:Vector2 = Vector2.from_angle(collision_rotation) 
	applied_ground_speed *= (space_velocity)
	ground_velocity = applied_ground_speed.x + applied_ground_speed.y
	
	#land in a roll if the player can
	if roll_checks() and Input.is_action_pressed(controls.action_roll):
		rolling = true
		play_sound_effect(sfx_roll_name)
	else:
		rolling = false
	
	#start control lock timer
	if not can_move:
		can_move = true
		#control_lock_timer.connect(&"timeout", func(): can_move = true, CONNECT_ONE_SHOT)
		#control_lock_timer.start(3.0)
	
	#if they were landing from a jump, clean up jump stuff
	if is_jumping:
		is_jumping = false
		can_jump = false
		#we use a timer to make sure the player can't spam the jump
		jump_timer.timeout.connect(func(): jump_timer.stop(); can_jump = true, CONNECT_ONE_SHOT)
		jump_timer.start(physics.jump_spam_timer)

##Update collision and rotation.
func update_collision_rotation() -> void:
	#figure out if we've hit a wall
	var stop_on_wall:bool = (ray_wall_left.is_colliding() and space_velocity.x < 0) or (ray_wall_right.is_colliding() and space_velocity.x > 0)
	if stop_on_wall:
		#null horizontal velocity if the player is on a wall
		ground_velocity = 0.0
		space_velocity.x = 0.0
		
		if is_equal_approx(signf(ground_velocity), facing_direction):
			is_pushing = true
		else:
			is_pushing = false
	else:
		is_pushing = false
	
	var contact_point_count:int = int(ray_ground_left.is_colliding()) + int(ray_ground_central.is_colliding()) + int(ray_ground_right.is_colliding())
	#IMPORTANT: Do NOT set is_grounded until angle is calculated, so that landing on the ground 
	#properly applies ground angle
	var in_ground_range:bool = bool(contact_point_count)
	#This check is made so that the player does not prematurely enter the ground state as soon
	# as the raycasts intersect the ground
	var will_actually_land:bool = get_slide_collision_count() > 0 and not is_on_wall_only()
	
	#calculate ground angles. This happens even in the air, because we need to 
	#know before landing what the ground angle is/will be, to apply landing speed
	if in_ground_range:
		if not is_on_wall():
			match contact_point_count:
				1:
					#player balances when two of the raycasts are over the edge
					is_balancing = true
					
					if is_grounded:
						#This bit of code usually only runs when the player runs off an upward
						#slope but too slowly to actually "launch". If we do nothing in this scenario,
						#it can cause an odd situation where the player is stuck on the ground but at 
						#the angle that they launched at, which is not good.
						collision_rotation = lerp_angle(collision_rotation, 0, 0.01)
					else:
						#Don't update rotation if we were already grounded. This allows for 
						#slope launch physics while retaining slope landing physics, by eliminating
						#false positives caused by one raycast being the remaining raycast when 
						#launching off a slope
						
						if ray_ground_left.is_colliding():
							collision_rotation = limitAngle(-atan2(ray_ground_left.get_collision_normal().x, ray_ground_left.get_collision_normal().y) - PI)
							facing_direction = 1.0 #slope is to the left, face right
						elif ray_ground_right.is_colliding():
							collision_rotation = limitAngle(-atan2(ray_ground_right.get_collision_normal().x, ray_ground_right.get_collision_normal().y) - PI)
							facing_direction = -1.0 #slope is to the right, face left
				2:
					is_balancing = false
					var left_angle:float = limitAngle(-atan2(ray_ground_left.get_collision_normal().x, ray_ground_left.get_collision_normal().y) - PI)
					var right_angle:float = limitAngle(-atan2(ray_ground_right.get_collision_normal().x, ray_ground_right.get_collision_normal().y) - PI)
					
					if ray_ground_left.is_colliding() and ray_ground_right.is_colliding():
						collision_rotation = (right_angle + left_angle) / 2.0
					#in these next two cases, the other contact point is the center
					elif ray_ground_left.is_colliding():
						collision_rotation = left_angle
					elif ray_ground_right.is_colliding():
						collision_rotation = right_angle
				3:
					is_balancing = false
					
					if is_grounded:
						apply_floor_snap()
						var gnd_angle:float = limitAngle(get_floor_normal().rotated(-deg_to_rad(270.0)).angle())
						
						#make sure the player can't merely run into anything in front of them and 
						#then walk up it
						if absf(angle_difference(collision_rotation, gnd_angle)) < default_max_angle and not is_on_wall():
							collision_rotation = gnd_angle
					else:
						#the CharacterBody2D system has no idea what the ground normal is when its
						#not on the ground. But, raycasts do. So when we aren't on the ground yet, 
						#we use the raycasts. 
						
						var left_angle:float = limitAngle(-atan2(ray_ground_left.get_collision_normal().x, ray_ground_left.get_collision_normal().y) - PI)
						var right_angle:float = limitAngle(-atan2(ray_ground_right.get_collision_normal().x, ray_ground_right.get_collision_normal().y) - PI)
						
						collision_rotation = (right_angle + left_angle) / 2.0
		
		var fast_enough:bool = absf(ground_velocity) > physics.ground_stick_speed
		
		#var floor_is_too_steep:bool = fmod(absf(global_collision_rotation), PI) >= fmod(floor_max_angle, PI)
		var floor_is_too_steep:bool = fmod(absf(global_collision_rotation), PI) >= fmod(default_max_angle, PI)
		
		#slip checks
		if is_grounded:
			
			if fast_enough:
				#up_direction is set so that floor snapping can be used for walking on walls. 
				up_direction = Vector2.from_angle(collision_rotation - deg_to_rad(90.0))
				
				#floor angle is PI, so that the player can run on basically anything
				floor_max_angle = PI
				#in this situation, they only need to be in range of the ground to be grounded
				is_grounded = in_ground_range
			
			else: #not fast enough to simply stick to the ground
				#up_direction should be set to the default direction, which will unstick
				#the player from any walls they were on
				up_direction = default_up_direction
				
				#if the floor is too steep and the player walked onto the slope, 
				#they need to slip down by temporarily losing control
				if floor_is_too_steep:
					#the timer to set this back to true will be activated upon landing
					can_move = false
					
					is_grounded = false
				else:
					is_grounded = in_ground_range
		else:
			if get_slide_collision_count() > 0:
				up_direction = default_up_direction
			
			#the raycasts will find the ground before the CharacterBody hitbox does, 
			#so only become grounded when both are "on the ground"
			is_grounded = in_ground_range and get_slide_collision_count() > 0 and not is_on_wall_only()
		
		#set sprite rotations
		if is_moving and in_ground_range:
			if anim_rotation_blacklist.has(current_anim):
				sprite_rotation = 0
			else:
				var rotation_snap:float = snappedf(collision_rotation, rotation_snap_interval)
				if rotation_classic_snap:
					sprite_rotation = snappedf(collision_rotation, rotation_snap_interval)
				else:
					var actual_rotation_speed:float = rotation_adjustment_speed
					if limitAngle(sprite_rotation) > (rotation_snap + rotation_snap):
						actual_rotation_speed *= 2
					sprite_rotation = lerp_angle(sprite_rotation, rotation_snap, actual_rotation_speed)
		
		else: #So that the character stands upright on slopes and such
			sprite_rotation = 0
	else:
		#it's important to set this here so that slope launching is calculated 
		#before reseting collision rotation
		is_grounded = false
		
		#ground sensors point whichever direction the player is traveling vertically
		#this is so that landing on the ceiling is made possible
		if space_velocity.y > 0:
			collision_rotation = 0
		else:
			collision_rotation = PI #180 degrees, pointing up
		
		#Ceiling landing check
		if space_velocity.y < 0 and in_ground_range:
			#The player can land on "steep ceilings", but not flat ones
			printt(collision_rotation, fmod(collision_rotation, PI), floor_max_angle)
			if fmod(collision_rotation, PI) <= floor_max_angle:
				is_grounded = true
			else:
				#they bonked their head on the ceiling, funne
				space_velocity.y = 0
		
		
		up_direction = default_up_direction
		
		#set sprite rotation
		if not anim_rotation_blacklist.has(current_anim):
			if rotation_classic_snap:
				sprite_rotation = 0
			else:
				sprite_rotation = move_toward(sprite_rotation, 0.0, rotation_adjustment_speed)
		else:
			sprite_rotation = 0
	
	sprites_set_rotation(sprite_rotation)
#endregion
#region Sprite/Animation processing
##Update the rotation of the character when they are in the air
func update_animations() -> void:
	sprites_flip()
	
	#rolling is rolling, whether the player is in the air or on the ground
	if rolling:
		play_animation(anim_roll, true)
	elif not is_grounded: #air animations
		if is_jumping:
			play_animation(anim_jump)
		else:
			play_animation(anim_free_fall, true)
	elif is_grounded:
		if is_pushing:
			play_animation(anim_push)
		# set player animations based on ground velocity
		#These use percents to scale to the stats
		elif is_moving:
			for speeds:float in anim_run_lib.sorted_keys:
				if absf(ground_velocity) > physics.ground_top_speed * speeds:
					#They were snapped earlier, but I find that it still won't work
					#unless I snap them here
					play_animation(anim_run.get(snappedf(speeds, 0.001), &"RESET"))
					break
		else: #standing still
			#not balancing on a ledge
			if is_balancing:
				if not ray_ground_left.is_colliding():
					#face the ledge
					facing_direction = -1.0
				elif not ray_ground_right.is_colliding():
					#face the ledge
					facing_direction = 1.0
				sprites_flip()
				if has_animation(anim_balance):
					play_animation(anim_balance)
				else:
					play_animation(anim_stand)
			else:
				if Input.is_action_pressed(controls.direction_up):
					#TODO: Add some API stuff to make this usable for stuff like camera repositioning
					if current_anim != anim_look_up:
						play_animation(anim_look_up)
					
					move_camera_vertical(camera_look_up_offset)
				elif is_crouching:
					play_animation(anim_crouch)
					move_camera_vertical(camera_look_down_offset)
				else:
					play_animation(anim_stand, true)
					move_camera_vertical(0)

##Flip the sprites for the player based on the direction the player is facing.
func sprites_flip() -> void:
	#ensure the character is facing the right direction
	#run checks, because having the nodes for this is not assumable
	if not is_zero_approx(ground_velocity):
		if facing_direction < 0: #left
			if is_instance_valid(sprite1):
				sprite1.flip_h = true
			if is_instance_valid(animated_sprite1):
				animated_sprite1.flip_h = true
		elif facing_direction > 0: #right
			if is_instance_valid(sprite1):
				sprite1.flip_h = false
			if is_instance_valid(animated_sprite1):
				animated_sprite1.flip_h = false

##Set the rotation of the sprites, in radians. This is required in order to preserve
##physics behavior while still implementing certain visual rotation features.
func sprites_set_rotation(new_rotation:float) -> void:
	if is_instance_valid(sprite1):
		sprite1.global_rotation = new_rotation
	if is_instance_valid(animated_sprite1):
		animated_sprite1.global_rotation = new_rotation

func move_camera_vertical(dest_offset:float) -> void:
	#var camera_dest_pos:float = camera_neutral_offset.y + camera_look_up_offset
	#
	#if not is_equal_approx(camera.offset.y, camera_dest_pos):
		#camera.offset.y = move_toward(camera.offset.y, camera_dest_pos, camera_move_speed)
	
	pass
#endregion

func _ready() -> void:
	#Set up nodes
	setup_children()
	#Find collision points. Run this after children
	#setup so that the raycasts can be placed properly.
	setup_collision()
	#setup performance montiors
	setup_performance_monitors()
	
	#After all, why [i]not[/i] use our own API?
	connect(&"contact_air", enter_air)
	connect(&"contact_ground", land_on_ground)
	
	anim_run_lib.load_dictionary(anim_run)
	anim_skid_lib.load_dictionary(anim_skid)
	
	default_max_angle = floor_max_angle
	
	camera = get_window().get_camera_2d()

func _exit_tree() -> void:
	cleanup_performance_monitors()

func _physics_process(delta: float) -> void:
	#reset this flag specifically
	animation_set = false
	pre_physics.emit(self)
	
	#some calculations/checks that always happen no matter what the state
	velocity_direction = get_position_delta().normalized().sign()
	
	input_direction = 0.0
	if can_move:
		input_direction = Input.get_axis(controls.direction_left, controls.direction_right)
	
	var skip_builtin_states:bool = false
	#Check for custom abilities
	if not state_abilities.is_empty():
		for customized_states:StringName in state_abilities:
			var state_node:MoonCastAbility = get_node(NodePath(customized_states))
			#If the state returns false, that means it has requested a skip in the
			#regular state processing
			if not state_node._custom_state_2D(self):
				skip_builtin_states = true
				break
	
	if not skip_builtin_states:
		if is_grounded:
			process_ground()
			#If we're still on the ground, call the state function
			if is_grounded:
				state_ground.emit(self)
		else:
			process_air()
			state_air.emit(self)
			#If we're still in the air, call the state function
			if not is_grounded:
				state_air.emit(self)
	#Make the callback for physics post-calculation
	#But this is *before* actually moving, or else it'd be nearly
	#the same as pre_physics
	post_physics.emit(self)
	
	var physics_tick_adjust:float = 60.0 * (delta * 60.0)
	
	velocity = space_velocity * physics_tick_adjust
	move_and_slide()
	
	update_animations()
	
	update_collision_rotation()
