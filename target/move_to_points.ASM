; StartingCodeWithLog.asm
; Created by Kevin Johnson
; (no copyright applied; edit freely, no attribution necessary)
; This program includes:
; - Wireless position logging using timer interrupt
; - Subroutines for
; -- 16x16 signed multiplication
; -- 16/16 signed division
; -- Arctangent (in appropriate robot units)
; -- Distance (L2 norm) approximation
; - Example of using tables (ILOAD, ISTORE)
; - Additional misc. examples


;***************************************************************
;* Jump Table
;***************************************************************
; When an interrupt occurs, execution is redirected to one of
; these addresses (depending on the interrupt source), which
; needs to either contain RETI (return from interrupt) if not
; used, or a JUMP instruction to the desired interrupt service
; routine (ISR).  The first location is the reset vector, and
; should be a JUMP instruction to the beginning of your normal
; code.
ORG        &H000       ; Jump table is located in mem 0-4
	JUMP   Init        ; Reset vector
	RETI               ; Sonar interrupt (unused)
	JUMP   CTimer_ISR  ; Timer interrupt
	RETI               ; UART interrupt (unused)
	RETI               ; Motor stall interrupt (unused)
	
;***************************************************************
;* Initialization
;***************************************************************
Init:
	; Always a good idea to make sure the robot
	; stops in the event of a reset.
	LOAD   Zero
	OUT    LVELCMD     ; Stop motors
	OUT    RVELCMD
	OUT    SONAREN     ; Disable sonar (optional)
	OUT    BEEP        ; Stop any beeping
	
	CALL   SetupI2C    ; Configure the I2C to read the battery voltage
	CALL   BattCheck   ; Get battery voltage (and end if too low).
	OUT    LCD         ; Display batt voltage on LCD

WaitForSafety:
	; Wait for safety switch to be toggled
	IN     XIO         ; XIO contains SAFETY signal
	AND    Mask4       ; SAFETY signal is bit 4
	JPOS   WaitForUser ; If ready, jump to wait for PB3
	IN     TIMER       ; We'll use the timer value to
	AND    Mask1       ;  blink LED17 as a reminder to toggle SW17
	SHIFT  8           ; Shift over to LED17
	OUT    XLEDS       ; LED17 blinks at 2.5Hz (10Hz/4)
	JUMP   WaitForSafety
	
WaitForUser:
	; Wait for user to press PB3
	IN     TIMER       ; We'll blink the LEDs above PB3
	AND    Mask1
	SHIFT  5           ; Both LEDG6 and LEDG7
	STORE  Temp        ; (overkill, but looks nice)
	SHIFT  1
	OR     Temp
	OUT    XLEDS
	IN     XIO         ; XIO contains KEYs
	AND    Mask2       ; KEY3 mask (KEY0 is reset and can't be read)
	JPOS   WaitForUser ; not ready (KEYs are active-low, hence JPOS)
	LOAD   Zero
	OUT    XLEDS       ; clear LEDs once ready to continue
	JUMP   Main
	
;***************************************************************
;* Main code
;***************************************************************
Main: ; "Real" program starts here.
	; You will probably want to reset the position at the start your project code:
	OUT    RESETPOS    ; reset odometer in case wheels moved after programming
	CALL   UARTClear   ; empty the UART receive FIFO of any old data
	CALL	StartLog

	LOADI COORDINATE_TABLE ;load  AC with address of the COORDINATE_TABLE
	STORE TABLE_POINTER      ; now the address of the COORDINATE_TABLE is stored in a mem address
	
	LOAD Zero ;reset table pointer
	STORE POINTER_ADD_AMT
	
	MOVEMENT_LOOP:
		ILOAD TABLE_POINTER	;load the index of the COORDINATE_TABLE pointed to by the TABLE_POINTER
		STORE ROTATE_DESIRED_X  ;load and store x of goal coordinate
		
		LOAD TABLE_POINTER ;increment TABLE_POINTER
		ADDI 1
		STORE TABLE_POINTER 
		
		ILOAD TABLE_POINTER
		STORE ROTATE_DESIRED_Y ;load and store y of goal coordinate
		
		LOAD TABLE_POINTER
		ADDI 1
		STORE TABLE_POINTER
		
		;do the rotation / movement to the next ggoal coordinate:  (ROTATE_DESIRED_X, ROTATE_DESIRED_Y)
		LOAD BEFORE
		OUT SSEG1
		
		;setup rotate speed for initial rotation
		LOAD FSlow
		STORE F_ROTATE_SPEED
		LOAD RSlow
		STORE R_ROTATE_SPEED
		LOAD Zero
		ADDI 45
		STORE ROTATE_THRESHOLD
		CALL ROTATE_TO_FACE
		
		CALL MOVE
		
		LOAD AFTER
		OUT SSEG1
		
		ILOAD TABLE_POINTER ; load original destination number
		CALL IndicateDest          ; send original destination number to computer log
		OUT SSEG2
		LOAD TABLE_POINTER
		ADDI 1
		STORE TABLE_POINTER
		
		
		LOAD POINTER_ADD_AMT	;used to keep track of how many points we have loaded out of table so we know when to stop the loop and die
		ADDI 3
		STORE POINTER_ADD_AMT
		ADDI -36
	JNEG MOVEMENT_LOOP
	
	CALL Die
	
	BEFORE: DW &H1010
	AFTER: DW &H1111
	
	TABLE_POINTER: DW 0
	POINTER_ADD_AMT: DW 0
	;COORDINATE_TABLE_BEGIN
	COORDINATE_TABLE:
		DW 0 ; x
		DW -290 ; y
		DW 6 ; dest #6
		DW 290 ; x
		DW -290 ; y
		DW 11 ; dest #11
		DW 290 ; x
		DW -870 ; y
		DW 8 ; dest #8
		DW -580 ; x
		DW -870 ; y
		DW 7 ; dest #7
		DW -870 ; x
		DW -580 ; y
		DW 1 ; dest #1
		DW -1161 ; x
		DW -580 ; y
		DW 5 ; dest #5
		DW -580 ; x
		DW -1451 ; y
		DW 3 ; dest #3
		DW 870 ; x
		DW 290 ; y
		DW 12 ; dest #12
		DW 870 ; x
		DW 580 ; y
		DW 9 ; dest #9
		DW 580 ; x
		DW 1451 ; y
		DW 4 ; dest #4
		DW -290 ; x
		DW 1161 ; y
		DW 2 ; dest #2
		DW -870 ; x
		DW 870 ; y
		DW 10 ; dest #10
	;COORDINATE_TABLE_END
	
Die:
; Sometimes it's useful to permanently stop execution.
; This will also catch the execution if it accidentally
; falls through from above.
	LOAD   Zero        ; Stop everything.
	OUT    LVELCMD
	OUT    RVELCMD
	OUT    SONAREN
	CALL   Wait1         ; wait for last point to be logged
	CALL   StopLog     ; Disable position logging
	
	;LOAD   DEAD        ; An indication that we are dead
	
	
	;*************distance from point*****************
	
	LOOP_FOREVER: IN XPOS
	SUB ROTATE_DESIRED_X
	STORE L2X
			
	IN YPOS
	SUB ROTATE_DESIRED_Y
	STORE L2Y
			
	CALL L2Estimate
	OUT SSEG1
	JUMP LOOP_FOREVER

Forever:
	JUMP   Forever     ; Do this forever.
DEAD:      DW &HDEAD   ; Example of a "local variable"

	
	
	
	
;********
; MOVE - move in a direction, making small adjustments if necessary
;************************************
MOVE:
	; - Store X and Y offset in L2X and L2Y.
	; - Call L2Estimate
	LOAD TEST_VAL
	OUT SSEG2
	MOVE_LOOP:
		CALL SETUP_CALC_ERROR
		LOAD DIRECTION_TO_MOVE_AFTER_ROTATING
		JPOS SKIP_FLIP
			;flip angle b/c moving backwards
			CALL FLIP_ANGLE
			STORE DESIRED_ANGLE
		SKIP_FLIP:
		CALL CALC_ERROR
		STORE ERROR
		CALL ABS
		ADDI -80 ;see if current angle is >= -80 degrees off
		JNEG AFTER_ROTATION_ADJUSTMENT
		;rotate if error is too great	
			; if (angle error is too great, make an in-place rotation to adjust before continuing movement
			LOAD Zero
			OUT LVELCMD
			OUT RVELCMD
			LOAD FSlow
			STORE F_ROTATE_SPEED
			LOAD RSlow
			STORE R_ROTATE_SPEED
			LOAD Zero
			ADDI 45
			STORE ROTATE_THRESHOLD
			CALL ROTATE_TO_FACE
		
		AFTER_ROTATION_ADJUSTMENT:
			;determine which direction to move
			;forward is positive, backward is negative
		LOAD DIRECTION_TO_MOVE_AFTER_ROTATING
		JNEG MOVE_BACKWARD
			;move forward
			LOAD ERROR ;negative = rotate right, positive = rotate left
			JNEG F_SLIGHT_RIGHT
			    ;slight rotation to left
				LOAD FMidLow
				OUT LVELCMD
				ADDI 150
				OUT RVELCMD
				JUMP END_OF_MOVEMENT_CASES
			F_SLIGHT_RIGHT:
				; slight rotation to right
				LOAD FMidLow
				OUT RVELCMD
				ADDI 150
				OUT LVELCMD
			JUMP END_OF_MOVEMENT_CASES
			
			
		MOVE_BACKWARD:
			LOAD ERROR ;negative = rotate left, positive = rotate right
			JNEG B_SLIGHT_RIGHT
			    ;slight rotation to left
				LOAD RMidLow
				OUT RVELCMD
				ADDI -150
				OUT LVELCMD
				JUMP END_OF_MOVEMENT_CASES
			B_SLIGHT_RIGHT:
				; slight rotation to right
				LOAD RMidLow
				OUT LVELCMD
				ADDI -150
				OUT RVELCMD
				
			JUMP END_OF_MOVEMENT_CASES
			
		END_OF_MOVEMENT_CASES:
			IN XPOS
			SUB ROTATE_DESIRED_X
			STORE L2X
			
			IN YPOS
			SUB ROTATE_DESIRED_Y
			STORE L2Y
			
			CALL L2Estimate
			STORE DISTANCE_TO_MOVE
			OUT SSEG1
			ADDI -85 ;see if distance is within # of zero (# < 6 inches)
	JPOS MOVE_LOOP
	
	LOAD Zero
	OUT LVELCMD
	OUT RVELCMD
RETURN	
	
	
	
	
	
DISTANCE_TO_MOVE: DW &H0000
	

	
	

TEST_VAL: DW &H0011
	
ROTATE_DIRECTION: DW &H0000
RIGHT: DW -1
LEFT: DW 1
RMidLow: DW -250
FMidLow: DW 250

F_ROTATE_SPEED: DW &H0000 ; speed of the wheel whichi s spinning forward while rotating
R_ROTATE_SPEED: DW &H0000 ; speed of thew heelw hich is spinning back while rotating
ROTATE_THRESHOLD: DW &H0000
;*************************************************************************
;        ROTATE_TO_FACE(x, y, speed, threshold): DIRECTION_TO_MOVE_AFTER_ROTATING
;   rotates to face a point and also tells which direction to move after the rotation is done
;   speed: the speeda t which to rotate
;   threshold: how far from goal angle stop rotating
;**************************************************************************
ROTATE_TO_FACE:
	LOAD Zero ;debug
	OUT SSEG2
	
	LOAD FORWARD ;default direciton to move after rotating
	STORE DIRECTION_TO_MOVE_AFTER_ROTATING
	
	CALL SETUP_CALC_ERROR
	CALL CALC_ERROR
	STORE ERROR  ;save result for later so we know which direction to rotate
	;******************************************************************************
	;   now the sign of the value in the accumulator tells us which way to rotate if we want to move forwards towards the target after rotating
	;******************************************************************************
	JNEG RIGHT_ROTATE
		LOAD LEFT
		JUMP ROTATE_STORE_0
	RIGHT_ROTATE:
		LOAD RIGHT
	ROTATE_STORE_0: 
		STORE ROTATE_DIRECTION
	
	LOAD ERROR
	CALL Abs	; Abs(error between current angle and desired angle)
	ADDI -90
	JNEG ROTATE_LOOP ; if ABS(error) < 90, we will go forward after rotating ELSE, go we going backwards
		LOAD ERROR
		JNEG LEFT_ROTATE
			LOAD RIGHT
			JUMP ROTATE_STORE_1
		LEFT_ROTATE:
			LOAD LEFT
		ROTATE_STORE_1: 
			STORE ROTATE_DIRECTION
		;*********************** FLIP DA DESIRED ANGLE WE GONA GO BACKWARDS after rotating
		LOAD BACKWARD ;so we know which way to move towards target after rotating
		STORE DIRECTION_TO_MOVE_AFTER_ROTATING
		
		
		CALL FLIP_ANGLE
			STORE DESIRED_ANGLE ;update desired angle with flipped version since we are going backwards now
			;CALL CALC_ERROR ; calculate new error, since we will have to rotate a different amount than if we were going forwards
			;STORE ERROR   ; store error to be used as a parameter for rotateTo
			
	
	ROTATE_LOOP:  ;now rotate to desired angle
		;LOAD ERROR ;rotate right if error is negative, left if error is positive
		LOAD ROTATE_DIRECTION
		JNEG NEG_ROTATE_CASE
		; POSITIVE CASE ---- ROTATE LEFT
			LOAD F_ROTATE_SPEED
			OUT RVELCMD
			LOAD R_ROTATE_SPEED
			OUT LVELCMD
			JUMP ROTATE_MIDDLE
		NEG_ROTATE_CASE:
			LOAD F_ROTATE_SPEED
			OUT LVELCMD
			LOAD R_ROTATE_SPEED
			OUT RVELCMD
		
		ROTATE_MIDDLE: ; the part where we decide if we should stop
			IN THETA
			SUB DESIRED_ANGLE
			;STORE ROTATE_ERROR
			
			;LOAD ROTATE_DIRECTION ;negative = right, positive = left
			CALL Abs
			SUB ROTATE_THRESHOLD
			JNEG END_OF_ROTATION  ; if abs(current angle - desired angle) < some amt, stop rotating (robot will continue to spin under its rotational momentum
			JUMP ROTATE_LOOP
	
	END_OF_ROTATION:
		LOAD Zero
		OUT LVELCMD
		OUT RVELCMD
		RETURN

ROTATE_ERROR: DW &H0000

;****************************************
;   FLIP ANGLE
;****************************************
FLIP_ANGLE:
	LOAD DESIRED_ANGLE ; else, flip the desired angle, flip the direction
		ADDI -180 ; if desired_angle is in first or second quadrant (0 - 179 degrees)
		JNEG FIRST2QUADRANTS
		; else, desired_angle is in 2nd
			; flip case for second two quadrants
			LOAD DESIRED_ANGLE
			ADDI -180
			JUMP END_OF_ANGLE_FLIPPING
			
		FIRST2QUADRANTS:
			LOAD DESIRED_ANGLE
			ADDI 180
		
		END_OF_ANGLE_FLIPPING: RETURN
;*******************************************************************************
; Mod360: modulo 360
; Returns AC%180 in AC
; Modified from Mod180 by Kevin Johnson.  No licence or copyright applied.
;*******************************************************************************	
Mod360:
	JNEG   Mod360n      ; handle negatives
Mod360p:
	ADDI   -360
	JPOS   Mod360p      ; subtract 360 until negative
	ADDI   360          ; go back positive
	RETURN
Mod360n:
	ADDI   360          ; add 360 until positive
	JNEG   Mod360n
	ADDI   -360         ; go back negative
	RETURN

;*************************************************************************
; SETUP_CALC_ERROR
; calculates desired angle (modifies DESIRED_ANGLE)
;*************************************************************************
SETUP_CALC_ERROR:
	IN XPOS ; find delta x
	STORE X_POS_STORED
	;SUB ROTATE_DESIRED_X
	LOAD ROTATE_DESIRED_X
	SUB X_POS_STORED
	STORE X_DIFF
	
	IN YPOS ;find delta y
	STORE Y_POS_STORED
	LOAD ROTATE_DESIRED_Y
	SUB Y_POS_STORED
	STORE Y_DIFF
	
	; get desired angle
		; store params for ATAN
	LOAD X_DIFF
	STORE AtanX
	LOAD Y_DIFF
	STORE AtanY
	CALL Atan2
	STORE DESIRED_ANGLE ;store desired angle
RETURN

;**********************************************************************
; CALC_ERROR(DESIRED_ANGLE, THETA_STORAGE): signed error in AC
;
;                                 Kevin's error formula: error = (desired - actual + 180)%360 - 180
; **********************************************************************
	
CALC_ERROR:
	IN THETA ;get current robot angle and store it for CALC_ERROR
	STORE THETA_STORAGE
	LOAD DESIRED_ANGLE
	SUB THETA_STORAGE ;desired - actual
	ADDI 180                        ;desired - actual + 180
	CALL Mod360                  ; (desired - actual + 180)%360
	ADDI -180							;(desired -actual + 180)%360 - 180
RETURN

DESIRED_ANGLE:	DW	&H0000
THETA_STORAGE:   DW   &H0000
DIRECTION_TO_MOVE_AFTER_ROTATING:				DW   &H0000
FORWARD:  DW 1 ;representation of forward direction to move after rotating
BACKWARD: DW -1

;for rotateTo
ERROR:          DW   &H0000


;for ROTATE_TO_FACE
	;parameters:
	ROTATE_DESIRED_X:	DW &H0000
	ROTATE_DESIRED_Y: DW &H0000
	;temp vars:
	X_DIFF:	DW &H0000
	Y_DIFF: DW &H0000
	X_POS_STORED: DW &H0000
	Y_POS_STORED: DW &H0000



	
;***************************************************************
;* Subroutines
;***************************************************************

; Subroutine to  (block) for 1 second
Wait1:
	OUT    TIMER
Wloop:
	IN     TIMER
	ADDI   -10         ; 1 second in 10Hz.
	JNEG   Wloop
	RETURN

; Subroutine to wait the number of timer counts currently in AC
WaitAC:
	STORE  WaitTime
	OUT    Timer
WACLoop:
	IN     Timer
	SUB    WaitTime
	JNEG   WACLoop
	RETURN
	WaitTime: DW 0     ; "local" variable.
	
; This subroutine will get the battery voltage,
; and stop program execution if it is too low.
; SetupI2C must be executed prior to this.
BattCheck:
	CALL   GetBattLvl
	JZERO  BattCheck   ; A/D hasn't had time to initialize
	SUB    MinBatt
	JNEG   DeadBatt
	ADD    MinBatt     ; get original value back
	RETURN
; If the battery is too low, we want to make
; sure that the user realizes it...
DeadBatt:
	LOAD   Four
	OUT    BEEP        ; start beep sound
	CALL   GetBattLvl  ; get the battery level
	OUT    SSEG1       ; display it everywhere
	OUT    SSEG2
	OUT    LCD
	LOAD   Zero
	ADDI   -1          ; 0xFFFF
	OUT    LEDS        ; all LEDs on
	OUT    XLEDS
	CALL   Wait1       ; 1 second
	Load   Zero
	OUT    BEEP        ; stop beeping
	LOAD   Zero
	OUT    LEDS        ; LEDs off
	OUT    XLEDS
	CALL   Wait1       ; 1 second
	JUMP   DeadBatt    ; repeat forever
	
; Subroutine to read the A/D (battery voltage)
; Assumes that SetupI2C has been run
GetBattLvl:
	LOAD   I2CRCmd     ; 0x0190 (write 0B, read 1B, addr 0x90)
	OUT    I2C_CMD     ; to I2C_CMD
	OUT    I2C_RDY     ; start the communication
	CALL   BlockI2C    ; wait for it to finish
	IN     I2C_DATA    ; get the returned data
	RETURN

; Subroutine to configure the I2C for reading batt voltage
; Only needs to be done once after each reset.
SetupI2C:
	CALL   BlockI2C    ; wait for idle
	LOAD   I2CWCmd     ; 0x1190 (write 1B, read 1B, addr 0x90)
	OUT    I2C_CMD     ; to I2C_CMD register
	LOAD   Zero        ; 0x0000 (A/D port 0, no increment)
	OUT    I2C_DATA    ; to I2C_DATA register
	OUT    I2C_RDY     ; start the communication
	CALL   BlockI2C    ; wait for it to finish
	RETURN
	
; Subroutine to block until I2C device is idle
BlockI2C:
	LOAD   Zero
	STORE  Temp        ; Used to check for timeout
BI2CL:
	LOAD   Temp
	ADDI   1           ; this will result in ~0.1s timeout
	STORE  Temp
	JZERO  I2CError    ; Timeout occurred; error
	IN     I2C_RDY     ; Read busy signal
	JPOS   BI2CL       ; If not 0, try again
	RETURN             ; Else return
I2CError:
	LOAD   Zero
	ADDI   &H12C       ; "I2C"
	OUT    SSEG1
	OUT    SSEG2       ; display error message
	JUMP   I2CError

; Subroutines to send AC value through the UART,
; Calling UARTSend2 will send both bytes of AC
; formatted for default base station code:
; [ AC(15..8) | AC(7..0)]
; Calling UARTSend1 will only send the low byte.
; Note that special characters such as \lf are
; escaped with the value 0x1B, thus the literal
; value 0x1B must be sent as 0x1B1B, should it occur.
UARTSend2:
	STORE  UARTTemp
	SHIFT  -8
	ADDI   -27   ; escape character
	JZERO  UEsc1
	ADDI   27
	OUT    UART_DAT
	JUMP   USend2
UEsc1:
	ADDI   27
	OUT    UART_DAT
	OUT    UART_DAT
USend2:
	LOAD   UARTTemp
UARTSend1:
	AND    LowByte
	ADDI   -27   ; escape character
	JZERO  UEsc2
	ADDI   27
	OUT    UART_DAT
	RETURN
UEsc2:
	ADDI   27
	OUT    UART_DAT
	OUT    UART_DAT
	RETURN
	UARTTemp: DW 0

; Subroutine to send a newline to the computer log
UARTNL:
	LOAD   NL
	OUT    UART_DAT
	SHIFT  -8
	OUT    UART_DAT
	RETURN
	NL: DW &H0A1B

; Subroutine to send a space to the computer log
UARTNBSP:
	LOAD   NBSP
	OUT    UART_DAT
	SHIFT  -8
	OUT    UART_DAT
	RETURN
	NBSP: DW &H201B

; Subroutine to clear the internal UART receive FIFO.
UARTClear:
	IN     UART_DAT
	JNEG   UARTClear
	RETURN

; Subroutine to tell the server that this position is one
; of the destinations.  Use AC=0 for generic indication,
; or AC=#1-12 for specific indication
IndicateDest:
	; AC contains which destination this is
	AND    LowNibl    ; keep only #s 0-15
	STORE  IDNumber
	LOADI  1
	STORE  IDFlag     ; set flag for indication
	RETURN
	IDNumber: DW 0
	IDFlag: DW 0
	

; Timer interrupt, used to send position data to the server
CTimer_ISR:
	CALL   UARTNL ; newline
	IN     XPOS
	CALL   UARTSend2
	IN     YPOS
	CALL   UARTSend2
	LOAD   IDFlag ; check if user has request a destination indication
	JPOS   CTIndicateDest ; if yes, do it; otherwise...
	RETI   ; return from interrupt
CTIndicateDest:
	LOAD   IDNumber
	CALL   UARTSend1 ; send the indicated destination
	LOADI  0
	STORE  IDFlag
	RETI

; Configure the interrupt timer and enable interrupts
StartLog:
	; See supporting information on the powersof2 site for how
	; SCOMP's communication system works.
	CALL   UARTNL      ; send a newline to separate data
	LOADI  0
	STORE  IDFlag      ; clear any pending flag
	LOADI  50
	OUT    CTIMER      ; configure timer for 0.01*50=0.5s interrupts
	CLI    &B0010      ; clear any pending interrupt from timer
	SEI    &B0010      ; enable interrupt from timer (source 1)
	RETURN

; Disable the interrupt timer and interrupts
StopLog:
	CLI    &B0010      ; disable interrupt source 1 (timer)
	LOADI  0
	OUT    CTIMER      ; reset configurable timer
	RETURN

;******************************************************************************;
; Atan2: 4-quadrant arctangent calculation                                     ;
; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ;
; Original code by Team AKKA, Spring 2015.                                     ;
; Based on methods by Richard Lyons                                            ;
; Code updated by Kevin Johnson to use software mult and div                   ;
; No license or copyright applied.                                             ;
; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ;
; To use: store dX and dY in global variables AtanX and AtanY.                 ;
; Call Atan2                                                                   ;
; Result (angle [0,359]) is returned in AC                                     ;
; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ;
; Requires additional subroutines:                                             ;
; - Mult16s: 16x16->32bit signed multiplication                                ;
; - Div16s: 16/16->16R16 signed division                                       ;
; - Abs: Absolute value                                                        ;
; Requires additional constants:                                               ;
; - One:     DW 1                                                              ;
; - NegOne:  DW -1                                                              ;
; - LowByte: DW &HFF                                                           ;
;******************************************************************************;
Atan2:
	LOAD   AtanY
	CALL   Abs          ; abs(y)
	STORE  AtanT
	LOAD   AtanX        ; abs(x)
	CALL   Abs
	SUB    AtanT        ; abs(x) - abs(y)
	JNEG   A2_sw        ; if abs(y) > abs(x), switch arguments.
	LOAD   AtanX        ; Octants 1, 4, 5, 8
	JNEG   A2_R3
	CALL   A2_calc      ; Octants 1, 8
	JNEG   A2_R1n
	RETURN              ; Return raw value if in octant 1
A2_R1n: ; region 1 negative
	ADDI   360          ; Add 360 if we are in octant 8
	RETURN
A2_R3: ; region 3
	CALL   A2_calc      ; Octants 4, 5            
	ADDI   180          ; theta' = theta + 180
	RETURN
A2_sw: ; switch arguments; octants 2, 3, 6, 7 
	LOAD   AtanY        ; Swap input arguments
	STORE  AtanT
	LOAD   AtanX
	STORE  AtanY
	LOAD   AtanT
	STORE  AtanX
	JPOS   A2_R2        ; If Y positive, octants 2,3
	CALL   A2_calc      ; else octants 6, 7
	XOR    NegOne
	ADDI   1            ; negate the angle
	ADDI   270          ; theta' = 270 - theta
	RETURN
A2_R2: ; region 2
	CALL   A2_calc      ; Octants 2, 3
	XOR    NegOne
	ADDI   1            ; negate the angle
	ADDI   90           ; theta' = 90 - theta
	RETURN
A2_calc:
	; calculates R/(1 + 0.28125*R^2)
	LOAD   AtanY
	STORE  d16sN        ; Y in numerator
	LOAD   AtanX
	STORE  d16sD        ; X in denominator
	CALL   A2_div       ; divide
	LOAD   dres16sQ     ; get the quotient (remainder ignored)
	STORE  AtanRatio
	STORE  m16sA
	STORE  m16sB
	CALL   A2_mult      ; X^2
	STORE  m16sA
	LOAD   A2c
	STORE  m16sB
	CALL   A2_mult
	ADDI   256          ; 256/256+0.28125X^2
	STORE  d16sD
	LOAD   AtanRatio
	STORE  d16sN        ; Ratio in numerator
	CALL   A2_div       ; divide
	LOAD   dres16sQ     ; get the quotient (remainder ignored)
	STORE  m16sA        ; <= result in radians
	LOAD   A2cd         ; degree conversion factor
	STORE  m16sB
	CALL   A2_mult      ; convert to degrees
	STORE  AtanT
	SHIFT  -7           ; check 7th bit
	AND    One
	JZERO  A2_rdwn      ; round down
	LOAD   AtanT
	SHIFT  -8
	ADDI   1            ; round up
	RETURN
A2_rdwn:
	LOAD   AtanT
	SHIFT  -8           ; round down
	RETURN
A2_mult: ; multiply, and return bits 23..8 of result
	CALL   Mult16s
	LOAD   mres16sH
	SHIFT  8            ; move high word of result up 8 bits
	STORE  mres16sH
	LOAD   mres16sL
	SHIFT  -8           ; move low word of result down 8 bits
	AND    LowByte
	OR     mres16sH     ; combine high and low words of result
	RETURN
A2_div: ; 16-bit division scaled by 256, minimizing error
	LOADI  9            ; loop 8 times (256 = 2^8)
	STORE  AtanT
A2_DL:
	LOAD   AtanT
	ADDI   -1
	JPOS   A2_DN        ; not done; continue shifting
	CALL   Div16s       ; do the standard division
	RETURN
A2_DN:
	STORE  AtanT
	LOAD   d16sN        ; start by trying to scale the numerator
	SHIFT  1
	XOR    d16sN        ; if the sign changed,
	JNEG   A2_DD        ; switch to scaling the denominator
	XOR    d16sN        ; get back shifted version
	STORE  d16sN
	JUMP   A2_DL
A2_DD:
	LOAD   d16sD
	SHIFT  -1           ; have to scale denominator
	STORE  d16sD
	JUMP   A2_DL
AtanX:      DW 0
AtanY:      DW 0
AtanRatio:  DW 0        ; =y/x
AtanT:      DW 0        ; temporary value
A2c:        DW 72       ; 72/256=0.28125, with 8 fractional bits
A2cd:       DW 14668    ; = 180/pi with 8 fractional bits

;*******************************************************************************
; Mult16s:  16x16 -> 32-bit signed multiplication
; Based on Booth's algorithm.
; Written by Kevin Johnson.  No licence or copyright applied.
; Warning: does not work with factor B = -32768 (most-negative number).
; To use:
; - Store factors in m16sA and m16sB.
; - Call Mult16s
; - Result is stored in mres16sH and mres16sL (high and low words).
;*******************************************************************************
Mult16s:
	LOADI  0
	STORE  m16sc        ; clear carry
	STORE  mres16sH     ; clear result
	LOADI  16           ; load 16 to counter
Mult16s_loop:
	STORE  mcnt16s      
	LOAD   m16sc        ; check the carry (from previous iteration)
	JZERO  Mult16s_noc  ; if no carry, move on
	LOAD   mres16sH     ; if a carry, 
	ADD    m16sA        ;  add multiplicand to result H
	STORE  mres16sH
Mult16s_noc: ; no carry
	LOAD   m16sB
	AND    One          ; check bit 0 of multiplier
	STORE  m16sc        ; save as next carry
	JZERO  Mult16s_sh   ; if no carry, move on to shift
	LOAD   mres16sH     ; if bit 0 set,
	SUB    m16sA        ;  subtract multiplicand from result H
	STORE  mres16sH
Mult16s_sh:
	LOAD   m16sB
	SHIFT  -1           ; shift result L >>1
	AND    c7FFF        ; clear msb
	STORE  m16sB
	LOAD   mres16sH     ; load result H
	SHIFT  15           ; move lsb to msb
	OR     m16sB
	STORE  m16sB        ; result L now includes carry out from H
	LOAD   mres16sH
	SHIFT  -1
	STORE  mres16sH     ; shift result H >>1
	LOAD   mcnt16s
	ADDI   -1           ; check counter
	JPOS   Mult16s_loop ; need to iterate 16 times
	LOAD   m16sB
	STORE  mres16sL     ; multiplier and result L shared a word
	RETURN              ; Done
c7FFF: DW &H7FFF
m16sA: DW 0 ; multiplicand
m16sB: DW 0 ; multipler
m16sc: DW 0 ; carry
mcnt16s: DW 0 ; counter
mres16sL: DW 0 ; result low
mres16sH: DW 0 ; result high

;*******************************************************************************
; Div16s:  16/16 -> 16 R16 signed division
; Written by Kevin Johnson.  No licence or copyright applied.
; Warning: results undefined if denominator = 0.
; To use:
; - Store numerator in d16sN and denominator in d16sD.
; - Call Div16s
; - Result is stored in dres16sQ and dres16sR (quotient and remainder).
; Requires Abs subroutine
;*******************************************************************************
Div16s:
	LOADI  0
	STORE  dres16sR     ; clear remainder result
	STORE  d16sC1       ; clear carry
	LOAD   d16sN
	XOR    d16sD
	STORE  d16sS        ; sign determination = N XOR D
	LOADI  17
	STORE  d16sT        ; preload counter with 17 (16+1)
	LOAD   d16sD
	CALL   Abs          ; take absolute value of denominator
	STORE  d16sD
	LOAD   d16sN
	CALL   Abs          ; take absolute value of numerator
	STORE  d16sN
Div16s_loop:
	LOAD   d16sN
	SHIFT  -15          ; get msb
	AND    One          ; only msb (because shift is arithmetic)
	STORE  d16sC2       ; store as carry
	LOAD   d16sN
	SHIFT  1            ; shift <<1
	OR     d16sC1       ; with carry
	STORE  d16sN
	LOAD   d16sT
	ADDI   -1           ; decrement counter
	JZERO  Div16s_sign  ; if finished looping, finalize result
	STORE  d16sT
	LOAD   dres16sR
	SHIFT  1            ; shift remainder
	OR     d16sC2       ; with carry from other shift
	SUB    d16sD        ; subtract denominator from remainder
	JNEG   Div16s_add   ; if negative, need to add it back
	STORE  dres16sR
	LOADI  1
	STORE  d16sC1       ; set carry
	JUMP   Div16s_loop
Div16s_add:
	ADD    d16sD        ; add denominator back in
	STORE  dres16sR
	LOADI  0
	STORE  d16sC1       ; clear carry
	JUMP   Div16s_loop
Div16s_sign:
	LOAD   d16sN
	STORE  dres16sQ     ; numerator was used to hold quotient result
	LOAD   d16sS        ; check the sign indicator
	JNEG   Div16s_neg
	RETURN
Div16s_neg:
	LOAD   dres16sQ     ; need to negate the result
	XOR    NegOne
	ADDI   1
	STORE  dres16sQ
	RETURN	
d16sN: DW 0 ; numerator
d16sD: DW 0 ; denominator
d16sS: DW 0 ; sign value
d16sT: DW 0 ; temp counter
d16sC1: DW 0 ; carry value
d16sC2: DW 0 ; carry value
dres16sQ: DW 0 ; quotient result
dres16sR: DW 0 ; remainder result

;*******************************************************************************
; Abs: 2's complement absolute value
; Returns abs(AC) in AC
; Written by Kevin Johnson.  No licence or copyright applied.
;*******************************************************************************
Abs:
	JPOS   Abs_r
	XOR    NegOne       ; Flip all bits
	ADDI   1            ; Add one (i.e. negate number)
Abs_r:
	RETURN

;*******************************************************************************
; Mod180: modulo 180
; Returns AC%180 in AC
; Written by Kevin Johnson.  No licence or copyright applied.
;*******************************************************************************	
Mod180:
	JNEG   Mod180n      ; handle negatives
Mod180p:
	ADDI   -180
	JPOS   Mod180p      ; subtract 180 until negative
	ADDI   180          ; go back positive
	RETURN
Mod180n:
	ADDI   180          ; add 180 until positive
	JNEG   Mod180n
	ADDI   -180         ; go back negative
	RETURN
	
;*******************************************************************************
; L2Estimate:  Pythagorean distance estimation
; Written by Kevin Johnson.  No licence or copyright applied.
; Warning: this is *not* an exact function.  I think it's most wrong
; on the axes, and maybe at 45 degrees.
; To use:
; - Store X and Y offset in L2X and L2Y.
; - Call L2Estimate
; - Result is returned in AC.
; Result will be in same units as inputs.
; Requires Abs and Mult16s subroutines.
;*******************************************************************************
L2Estimate:
	; take abs() of each value, and find the largest one
	LOAD   L2X
	CALL   Abs
	STORE  L2T1
	LOAD   L2Y
	CALL   Abs
	SUB    L2T1
	JNEG   GDSwap    ; swap if needed to get largest value in X
	ADD    L2T1
CalcDist:
	; Calculation is max(X,Y)*0.961+min(X,Y)*0.406
	STORE  m16sa
	LOADI  246       ; max * 246
	STORE  m16sB
	CALL   Mult16s
	LOAD   mres16sH
	SHIFT  8
	STORE  L2T2
	LOAD   mres16sL
	SHIFT  -8        ; / 256
	AND    LowByte
	OR     L2T2
	STORE  L2T3
	LOAD   L2T1
	STORE  m16sa
	LOADI  104       ; min * 104
	STORE  m16sB
	CALL   Mult16s
	LOAD   mres16sH
	SHIFT  8
	STORE  L2T2
	LOAD   mres16sL
	SHIFT  -8        ; / 256
	AND    LowByte
	OR     L2T2
	ADD    L2T3     ; sum
	RETURN
GDSwap: ; swaps the incoming X and Y
	ADD    L2T1
	STORE  L2T2
	LOAD   L2T1
	STORE  L2T3
	LOAD   L2T2
	STORE  L2T1
	LOAD   L2T3
	JUMP   CalcDist
L2X:  DW 0
L2Y:  DW 0
L2T1: DW 0
L2T2: DW 0
L2T3: DW 0
	
;***************************************************************
;* Variables
;***************************************************************
Temp:  DW 0 ; "Temp" is not a great name, but can be useful
Temp2: DW 0
Temp3: DW 0
CDX: DW 0      ; current desired X
CDY: DW 0      ; current desired Y
CDT: DW 0      ; current desired angle
CX:  DW 0      ; sampled X
CY:  DW 0      ; sampled Y
CT:  DW 0      ; sampled theta

;***************************************************************
;* Constants
;* (though there is nothing stopping you from writing to these)
;***************************************************************
NegOne:   DW -1
Zero:     DW 0
One:      DW 1
Two:      DW 2
Three:    DW 3
Four:     DW 4
Five:     DW 5
Six:      DW 6
Seven:    DW 7
Eight:    DW 8
Nine:     DW 9
Ten:      DW 10

; Some bit masks.
; Masks of multiple bits can be constructed by ORing these
; 1-bit masks together.
Mask0:    DW &B00000001
Mask1:    DW &B00000010
Mask2:    DW &B00000100
Mask3:    DW &B00001000
Mask4:    DW &B00010000
Mask5:    DW &B00100000
Mask6:    DW &B01000000
Mask7:    DW &B10000000
LowByte:  DW &HFF      ; binary 00000000 1111111
LowNibl:  DW &HF       ; 0000 0000 0000 1111

; some useful movement values
OneMeter: DW 952       ; ~1m in 1.05mm units
HalfMeter: DW 476      ; ~0.5m in 1.05mm units
OneFoot:  DW 290       ; ~1ft in 1.05mm robot units
TwoFeet:  DW 581       ; ~2ft in 1.05mm units
Deg90:    DW 90        ; 90 degrees in odometer units
Deg180:   DW 180       ; 180
Deg270:   DW 270       ; 270
Deg360:   DW 360       ; can never actually happen; for math only
FSlow:    DW 100       ; 100 is about the lowest velocity value that will move
RSlow:    DW -100
FMid:     DW 350       ; 350 is a medium speed
RMid:     DW -350
FFast:    DW 500       ; 500 is almost max speed (511 is max)
RFast:    DW -500

MinBatt:  DW 130       ; 13.0V - minimum safe battery voltage
I2CWCmd:  DW &H1190    ; write one i2c byte, read one byte, addr 0x90
I2CRCmd:  DW &H0190    ; write nothing, read one byte, addr 0x90

;***************************************************************
;* IO address space map
;***************************************************************
SWITCHES: EQU &H00  ; slide switches
LEDS:     EQU &H01  ; red LEDs
TIMER:    EQU &H02  ; timer, usually running at 10 Hz
XIO:      EQU &H03  ; pushbuttons and some misc. inputs
SSEG1:    EQU &H04  ; seven-segment display (4-digits only)
SSEG2:    EQU &H05  ; seven-segment display (4-digits only)
LCD:      EQU &H06  ; primitive 4-digit LCD display
XLEDS:    EQU &H07  ; Green LEDs (and Red LED16+17)
BEEP:     EQU &H0A  ; Control the beep
CTIMER:   EQU &H0C  ; Configurable timer for interrupts
LPOS:     EQU &H80  ; left wheel encoder position (read only)
LVEL:     EQU &H82  ; current left wheel velocity (read only)
LVELCMD:  EQU &H83  ; left wheel velocity command (write only)
RPOS:     EQU &H88  ; same values for right wheel...
RVEL:     EQU &H8A  ; ...
RVELCMD:  EQU &H8B  ; ...
I2C_CMD:  EQU &H90  ; I2C module's CMD register,
I2C_DATA: EQU &H91  ; ... DATA register,
I2C_RDY:  EQU &H92  ; ... and BUSY register
UART_DAT: EQU &H98  ; UART data
UART_RDY: EQU &H98  ; UART status
SONAR:    EQU &HA0  ; base address for more than 16 registers....
DIST0:    EQU &HA8  ; the eight sonar distance readings
DIST1:    EQU &HA9  ; ...
DIST2:    EQU &HAA  ; ...
DIST3:    EQU &HAB  ; ...
DIST4:    EQU &HAC  ; ...
DIST5:    EQU &HAD  ; ...
DIST6:    EQU &HAE  ; ...
DIST7:    EQU &HAF  ; ...
SONALARM: EQU &HB0  ; Write alarm distance; read alarm register
SONARINT: EQU &HB1  ; Write mask for sonar interrupts
SONAREN:  EQU &HB2  ; register to control which sonars are enabled
XPOS:     EQU &HC0  ; Current X-position (read only)
YPOS:     EQU &HC1  ; Y-position
THETA:    EQU &HC2  ; Current rotational position of robot (0-359)
RESETPOS: EQU &HC3  ; write anything here to reset odometry to 0
