class_name TestState extends State

var PlayerInput: bool = false

func Enter() -> void:
	# Perform Enter Animations and Sounds	
	PlayerInput = true

func Exit() -> void:
	PlayerInput = false
	# Perform Exit Animations and Sounds

func Update(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		if PlayerInput == true:
			Accept_Input()

	if Input.is_action_just_pressed("ui_cancel"):
		if PlayerInput == true:
			Cancel_Input()

func Accept_Input() -> void:
	print("You pressed the A button.")

func Cancel_Input() -> void:
	print("You pressed the B button.")
