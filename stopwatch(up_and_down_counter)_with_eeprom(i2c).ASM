A_IN				BIT		P2.6			;3 inputs of 3-to-8 decoder
B_IN				BIT		P2.7
C_IN				BIT		P2.4
BUZZER_PIN			BIT		P2.5			;different pin functionalities
SW1_PIN				BIT		P2.1
SW2_PIN				BIT		P2.2
SW3_PIN				BIT		P2.3
SW4_PIN				BIT		P2.0
SDA_PIN				BIT		P1.0
SCL_PIN				BIT		P1.1
WP_PIN				BIT		P1.2

COUNTER_BIT			BIT		20H.0			;flag bit to monitor 1 ms delay
BEEP_ON				BIT		20H.1			;flag bit to control buzzer operation
SW1_PRESSED			BIT		20H.2			;flag bit to control switch1 routine
SW2_PRESSED			BIT		20H.3			;flag bit to control switch2 routine
SW3_PRESSED			BIT		20H.4			;flag bit to control switch3 routine
SW4_PRESSED			BIT		20H.5			;flag bit to control switch4 routine
RESET_READY			BIT		20H.6			;switch4 can sense only when this flag is raised
UPCOUNT_READY			BIT		20H.7			;switch1 can sense only when this flag is raised
DOWNCOUNT_READY			BIT		21H.0			;switch2 can sense only when this flag is raised
DISP_EEPROM_READY		BIT		21H.1			;switch3 can sense only when this flag is raised
ERROR_BIT			BIT		21H.2			;this flag is raised whenever an error occurs in i2c comm 
	
DISP_COUNTER			EQU		30H			;(1 byte)to keep track of the display no. to which data has been sent(0-5)
DISP_DATA			EQU		31H			;(6 bytes)used to store the hex values to be sent to P0 for the 6 displays(6 bytes)
DISP_REG			EQU		37H			;(6 bytes)to keep track of the digits to be displayed on the 6 displays
DIGIT				EQU		3EH			;(1 byte)to store digit to be displayed
COUNTER_REG			EQU		3FH			;(3 bytes)to store counter value in packed form
SEC_ONES			EQU		42H			;(2 bytes)to temporarily store unit's and ten's place digits of seconds
BUZ_COUNTER			EQU		44H			;(1 byte)flag bit to control buzzer's operation
SW1_COUNTER			EQU		45H			;(1 byte)flag bit to control switch1 operation
SW2_COUNTER			EQU		46H			;(1 byte)flag bit to control switch2 operation
SW3_COUNTER			EQU		47H			;(1 byte)flag bit to control switch3 operation
SW4_COUNTER			EQU		48H			;(1 byte)flag bit to control switch4 operation
SERIAL_REG			EQU		49H			;(7 bytes)to store the hex values corresponding to the counter value to be transmitted serially
FIRST_WORD_ADDR			EQU		50H			;(1 byte)to store first word address for i2c comm
SECOND_WORD_ADDR		EQU		51H			;(1 byte)to store second word address for i2c comm
READ_ADDR_1STWORD		EQU		52H			;(1 byte)to store first word adrress for i2c comm(for sequential read)
READ_ADDR_2NDWORD		EQU		53H			;(1 byte)to store second word address for i2c comm(for sequential read)
DEVICE_ADDR			EQU		54H			;(1 byte)to store device address(7 bit address followed by R/W bit)
DATA_BYTE			EQU		55H			;to store the data byte received or to be transmitted via i2c comm			
TRIALS				EQU		56H			;to store the no. of trials for i2c comm
DECIMAL_ASCII			EQU		2EH			;ascii code for decimal point			

CSEG
		ORG		0000H
		LJMP		MAIN

		ORG		000BH
		LJMP		ISR_T0

		ORG		0030H					;bypass vector table
MAIN:	CLR			BUZZER_PIN
		CLR		BEEP_ON
		CLR		RESET_READY
		;CLR		SW1_PRESSED
		MOV		BUZ_COUNTER,#0
		MOV		DISP_COUNTER,#0
		MOV		P0,#0FFH
		MOV		TMOD,#21H				;Timer0,Mode1(16-bit) and Timer1,Mode2(8-bit auto-reload)
		MOV		TH0,#0F8H				;load initial count value for Timer0
		MOV		TL0,#0CDH
		MOV		TH1,#-6					;load initial count value for Timer1(will be used for serial comm)
		MOV		SCON,#50H				;Serial Mode1(1 start and 1 stop bit),REN enabled
		MOV		IE,#82H					;enable Timer0 interrupt
		SETB		TR0					;start Timer0
		SETB		TR1					;start Timer1
;------------starting of power on display sequence(scrolling of 0-9 once)----------------		
		MOV		DISP_REG,#0AH
		MOV		DISP_REG+1,#0AH
		MOV		DISP_REG+2,#0AH
		MOV		DISP_REG+3,#0AH
		MOV		DISP_REG+4,#0AH
		MOV		DISP_REG+5,#0AH
		LCALL		LOAD_DISP_DATA
		LCALL		DELAY

		MOV		DIGIT,#0
REPEAT1:	
		LCALL		SHIFT_DIGIT
		MOV		DISP_REG,DIGIT
		LCALL		LOAD_DISP_DATA
		LCALL		DELAY
		INC		DIGIT
		MOV		A,DIGIT
		CJNE		A,#10,REPEAT1

		
		MOV		R4,#6
REPEAT2:
		LCALL		SHIFT_DIGIT
		MOV		DISP_REG,#0AH
		LCALL		LOAD_DISP_DATA
		LCALL		DELAY
		DJNZ		R4,REPEAT2
		
		
;--------starting of millisecond counter-----------
MOV		FIRST_WORD_ADDR,#00H
MOV		SECOND_WORD_ADDR,#00H
LOOP001:
		CLR		RESET_READY
		CLR		DISP_EEPROM_READY
		SETB		BEEP_ON
		SETB		SW1_PIN
		SETB		SW2_PIN
		SETB		SW3_PIN
		SETB		SW4_PIN
		MOV		COUNTER_REG,#0		;MSB
		MOV		COUNTER_REG+1,#0
		MOV		COUNTER_REG+2,#0	;LSB
		LCALL		UNPACK_COUNT
		LCALL		LOAD_DISP_DATA
		ANL		DISP_DATA+3,#0BFH
		MOV		SEC_ONES,#0
		MOV		SEC_ONES+1,#0

		CLR		SW1_PRESSED
		CLR		SW2_PRESSED
		CLR		SW3_PRESSED
		CLR		SW4_PRESSED
		CLR		COUNTER_BIT
		SETB		UPCOUNT_READY
		SETB		DOWNCOUNT_READY
;----------------------------------------------------------------------
INITIAL_WAIT:		
		;JNB		SW1_PRESSED,INITIAL_WAIT		;initial START 
		;CLR		SW1_PRESSED
		JB		SW1_PRESSED,LOOP002
		JB		SW2_PRESSED,LOOP003
		SJMP		INITIAL_WAIT
LOOP002:CLR			DOWNCOUNT_READY
		CLR		SW1_PRESSED
		SJMP		LOOP004
LOOP003:CLR			UPCOUNT_READY
		CLR		SW2_PRESSED
;-----------------------------------------------------------------------
		
		
LOOP004:	JNB		COUNTER_BIT,LOOP004
		CLR		COUNTER_BIT
;---------either upcount or downcount depending on the switch pressed-----------
		JNB		DOWNCOUNT_READY,LOOP005
		LCALL		UPDATE_DOWNCOUNTER
LOOP005:JNB			UPCOUNT_READY,LOOP006
		LCALL		UPDATE_UPCOUNTER
;-------------------------------------------------------------------------------

LOOP006:LCALL	UNPACK_COUNT
		LCALL		REMOVE_LEADING_ZEROS
		LCALL		CHECK_SEC_DELAY
		LCALL		LOAD_DISP_DATA
		ANL		DISP_DATA+3,#0BFH
;---------------------------------------------------		
		JNB		SW1_PRESSED,LOOP007			;Stop counter on corresponding switch press
		CLR		SW1_PRESSED
		SJMP		LOOP008
LOOP007:	JNB		SW2_PRESSED,LOOP004
		CLR		SW2_PRESSED
;---------------------------------------------------

;If counter stopped,come here(we can either start downcounter/upcounter,reset.While we have stopped,we can also press SW3 to display latest content written in eeprom)
LOOP008:
		SETB	BUZZER_PIN
		MOV	READ_ADDR_1STWORD,FIRST_WORD_ADDR		;Update read address(will be used in case switch3 is pressed
		MOV	READ_ADDR_2NDWORD,SECOND_WORD_ADDR
		LCALL	LOAD_SERIAL_REG
		LCALL	SERIAL_TRANSFER
		LCALL	STORE_COUNTER_IN_EEPROM				;writing the counter value in eeprom after stopping
		SETB	UPCOUNT_READY
		SETB	DOWNCOUNT_READY
LOOP009:
		SETB	DISP_EEPROM_READY
		SETB	RESET_READY
		JNB	SW3_PRESSED,LOOP010	
		CLR	SW3_PRESSED			
		LCALL	DISP_EEPROM_DATA				;reading the latest counter value written in eeprom and displaying it on PC
LOOP010:
		JNB	SW4_PRESSED,LOOP011				;if SW4_PRESSED=1,then Reset by jumping to LOOP001
		CLR	DISP_EEPROM_READY
		LJMP	LOOP001
LOOP011:JB		SW1_PRESSED,LOOP012
		JB	SW2_PRESSED,LOOP013
		SJMP	LOOP009						;Wait till SW1 or SW2 is pressed
LOOP012:								;come here if SW1 is pressed
		CLR	DOWNCOUNT_READY
		CLR	SW1_PRESSED
		SJMP	LOOP014
LOOP013:								;come here if SW2 is pressed
		CLR	UPCOUNT_READY
		CLR	SW2_PRESSED
;-----------------------------------------
LOOP014:
		CLR	DISP_EEPROM_READY
		CLR	COUNTER_BIT
		LJMP	LOOP004

;-------------end of MAIN------------------
STORE_COUNTER_IN_EEPROM:						;byte write 7 times
			CLR		WP_PIN
			MOV		TRIALS,#5
			MOV		DEVICE_ADDR,#0A6H
LOOP015:	
			MOV		FIRST_WORD_ADDR,READ_ADDR_1STWORD
			MOV		SECOND_WORD_ADDR,READ_ADDR_2NDWORD
			MOV		R0,#SERIAL_REG+6
			MOV		R7,#7
LOOP016:		LCALL		START_EEPROM
			
			MOV		A,DEVICE_ADDR
			LCALL		SEND_BYTE			;sending device address
			JB		ERROR_BIT,LOOP017
			
			MOV		A,FIRST_WORD_ADDR
			LCALL		SEND_BYTE			;sending first word address
			JB		ERROR_BIT,LOOP017
			
			MOV		A,SECOND_WORD_ADDR
			LCALL		SEND_BYTE			;sending second word address
			JB		ERROR_BIT,LOOP017
			
			MOV		DATA_BYTE,@ R0
			MOV		A,DATA_BYTE
			LCALL		SEND_BYTE			;sending data byte
			JB		ERROR_BIT,LOOP017
			
			LCALL		STOP_EEPROM
			LCALL		EEPROM_DELAY
			DEC		R0
			LCALL		INC_ADDRESS
			DJNZ		R7,LOOP016
			RET		
LOOP017:		LCALL		STOP_EEPROM			
			JNB		ERROR_BIT,EXIT_STORE_COUNTER	;If error flag is not raised,then simply return
			DJNZ		TRIALS,LOOP015			;try again for a specific no. of times
			MOV		FIRST_WORD_ADDR,READ_ADDR_1STWORD	;if all the trials go into vain,make sure to update first word and second word address
			MOV		SECOND_WORD_ADDR,READ_ADDR_2NDWORD
			LCALL		TRANSMISSION_FAILED		;else,after all the failed trials,display a failure message
			LCALL		WRITE_FAILED
			MOV		SBUF,#0DH
			LCALL		XMIT_BYTE
			MOV		SBUF,#0AH
			LCALL		XMIT_BYTE	
EXIT_STORE_COUNTER:	
			RET
;------------------------------------------
DISP_EEPROM_DATA:
			SETB	WP_PIN
			MOV	TRIALS,#5
										;Sequential Read
			;--------------------				;Dummy write
LOOP018:	LCALL	START_EEPROM
			
			MOV		DEVICE_ADDR,#0A6H
			MOV		A,DEVICE_ADDR
			LCALL		SEND_BYTE			;sending device address
			JB		ERROR_BIT,LOOP022
			
			MOV		A,READ_ADDR_1STWORD
			LCALL		SEND_BYTE			;sending first word address
			JB		ERROR_BIT,LOOP022
			
			MOV		A,READ_ADDR_2NDWORD
			LCALL		SEND_BYTE			;sending second word address
			JB		ERROR_BIT,LOOP022
			;--------------------
			LCALL		START_EEPROM
			MOV		R7,#6
			
			MOV		DEVICE_ADDR,#0A7H
			MOV		A,DEVICE_ADDR
			LCALL		SEND_BYTE			;sending device address
			JB		ERROR_BIT,LOOP022
			
			LCALL		DISP_EEPROM_MESSAGE
LOOP019:		LCALL		RECEIVE_BYTE
			MOV		A,DATA_BYTE
			CJNE		A,#3AH,LOOP020			;if the data byte read=3AH(signifying empty i.e. 30H||0AH),no need to display it on PC
			SJMP		LOOP021
LOOP020:		MOV		SBUF,A				;if data byte is not empty but a digit,display it via serial comm
			LCALL		XMIT_BYTE
LOOP021:		LCALL		ACK
			DJNZ		R7,LOOP019
			LCALL		RECEIVE_BYTE
			MOV		SBUF,DATA_BYTE
			LCALL		XMIT_BYTE
			LCALL		NACK
			LCALL		STOP_EEPROM
			MOV		SBUF,#0DH
			LCALL		XMIT_BYTE
			MOV		SBUF,#0AH
			LCALL		XMIT_BYTE
			RET
LOOP022:		LCALL		STOP_EEPROM
			JNB		ERROR_BIT,EXIT_DISP_EEPROM_DATA	;If error flag is not raised,then simply return
			DJNZ		TRIALS,LOOP018			;try again for a specific no. of times
			MOV		FIRST_WORD_ADDR,READ_ADDR_1STWORD	;if all the trials go into vain,make sure to update first word and second word address
			MOV		SECOND_WORD_ADDR,READ_ADDR_2NDWORD
			LCALL		TRANSMISSION_FAILED		;else,after all the failed trials,display a failure message
			LCALL		READ_FAILED
			MOV		SBUF,#0DH
			LCALL		XMIT_BYTE
			MOV		SBUF,#0AH
			LCALL		XMIT_BYTE	
EXIT_DISP_EEPROM_DATA:	
			RET
;--------------------------------------------
SERIAL_TRANSFER:
		CLR		REN
		CLR		TI
		MOV		R0,#SERIAL_REG+6
LOOP060:	MOV		A,@ R0
		CJNE		A,#3AH,LOOP061				;if A not equal to 3AH,then continue by jumping to LOOP061
		SJMP		LOOP063					;else,we've got a leading zero,therefore simply return
LOOP061:	MOV		SBUF,A
		LCALL		XMIT_BYTE
LOOP063:	DEC		R0
		CJNE		R0,#SERIAL_REG-1,LOOP060		;repeat the process till transmission of 7 bytes of SERIAL_REG is complete
		MOV		SBUF,#0DH
		LCALL		XMIT_BYTE
		MOV		SBUF,#0AH
		LCALL		XMIT_BYTE
		RET
;-------------------------------------------		
XMIT_BYTE:		
		CLR		TI					;clear TI flag to get ready for next character transfer
LOOP062:	JNB		TI,LOOP062				;wait for TI flag to be set(i.e. till completion of serial transfer of 1 character)
		CLR		TI					;clear TI flag to get ready for next character transfer
		RET

;-------------------------------------------
LOAD_SERIAL_REG:
		MOV		R0,#DISP_REG
		MOV		R1,#SERIAL_REG
LOOP070:	MOV		A,@ R0
		ORL		A,#30H					;ANDing with 30H to get ASCII value of the digit stored in R1,storing this value in accumulator
		MOV		@ R1,A					;and then loading it to R1
		INC		R0
		INC		R1
		CJNE		R0,#DISP_REG+3,LOOP071			;if R0=#DISP_REG+3,we need to load the ascii value of the decimal point next
		MOV		@ R1,#DECIMAL_ASCII
		INC		R1
LOOP071:	CJNE		R0,#DISP_REG+6,LOOP070
		RET
;------------------------------------------
REMOVE_LEADING_ZEROS:							;make sure to not display leading zeros(in case disp_reg+5 and/or disp_reg+4 contains 0)
		MOV		R0,#DISP_REG+5
LOOP080:	MOV		A,@ R0
		CJNE		A,#00,EXIT_SUBROUTINE
		MOV		@ R0,#0AH
		DEC		R0
		CJNE		R0,#DISP_REG+3,LOOP080
EXIT_SUBROUTINE:
		RET
		

;------------------------------------------
CHECK_SEC_DELAY:							;Beep after every 1 second
		MOV		A,SEC_ONES
		CJNE		A,DISP_REG+3,LOOP081			;1 second is detected whenever digit at seconds' ones' place changes
		RET
LOOP081:
		MOV		SEC_ONES,DISP_REG+3
		SETB		BEEP_ON					;set the beep_on flag every second
		RET


;------------------------------------------

UNPACK_COUNT:								;unpack counter_reg's content and load disp_reg
		MOV		R0,#COUNTER_REG
		MOV		R1,#DISP_REG+5
LOOP090:	MOV		A,@ R0
		SWAP		A
		ANL		A,#0FH
		MOV		@ R1,A
		DEC		R1
		MOV		A,@ R0
		ANL		A,#0FH
		MOV		@ R1,A
		DEC		R1
		INC		R0
		CJNE		R0,#COUNTER_REG+3,LOOP090
		RET
;---------------------------------------------
UPDATE_UPCOUNTER:							;updating counter register in case of upcounter
		CLR		C
		MOV		A,COUNTER_REG+2
		ADDC		A,#1
		DA		A
		MOV		COUNTER_REG+2,A
		MOV		A,COUNTER_REG+1
		ADDC		A,#0
		DA		A
		MOV		COUNTER_REG+1,A
		MOV		A,COUNTER_REG
		ADDC		A,#0
		DA		A
		MOV		COUNTER_REG,A
		RET

;-----------------------------------------------
UPDATE_DOWNCOUNTER:							;updating counter register in case of downcounter
		CLR		C
		MOV		A,COUNTER_REG+2
		SUBB		A,#1
		MOV		COUNTER_REG+2,A
		MOV		A,COUNTER_REG+1
		SUBB		A,#0
		MOV		COUNTER_REG+1,A
		MOV		A,COUNTER_REG
		SUBB		A,#0
		MOV		COUNTER_REG,A
		
		
;------   BCD correction   --------		
		MOV		R0,#COUNTER_REG
		
LOOP091:	MOV		A,@ R0
		ANL		A,#0FH					;fetching the lower nibble
		CJNE		A,#0FH,LOOP092
		CLR		C
		SUBB		A,#6					;modifying lower nibble if required
		MOV		R2,A					;temporarily store lower nibble in R2
		MOV		A,@ R0
		ANL		A,#0F0H					;masking the lower nibble of the content that R0 points to
		ORL		A,R2
		MOV		@ R0,A					;updating content of the location pointed by R0
		
LOOP092:	MOV		A,@ R0
		ANL		A,#0F0H					;fetching the upper nibble
		CJNE		A,#0F0H,LOOP093
		CLR		C
		SUBB		A,#60H					;modifying upper nibble if required
		MOV		R2,A					;temporarily store the upper nibble in R2
		MOV		A,@ R0
		ANL		A,#0FH					;masking the upper nibble of the content that R0 points to
		ORL		A,R2
		MOV		@ R0,A					;updating content of the location pointed by R0
LOOP093:	INC		R0
		CJNE		R0,#COUNTER_REG+3,LOOP091
				
		RET
;-----------------------------------------------

SHIFT_DIGIT:
		MOV		DISP_REG+5,DISP_REG+4
		MOV		DISP_REG+4,DISP_REG+3
		MOV		DISP_REG+3,DISP_REG+2
		MOV		DISP_REG+2,DISP_REG+1
		MOV		DISP_REG+1,DISP_REG
		RET

DELAY:		MOV		R5,#5
LOOP100:	MOV		R6,#0
LOOP101:	MOV		R7,#0
LOOP102:	DJNZ		R7,LOOP102
		DJNZ		R6,LOOP101
		DJNZ		R5,LOOP100
		RET
;------------------------------------------------


LOAD_DISP_DATA:								;load disp_data register
		MOV		R0,#DISP_DATA
		MOV		R1,#DISP_REG
		MOV		DPTR,#TABLE2
LOOP103:	MOV		A,@ R1
		MOVC		A,@ A+DPTR				;A contains the hex databyte that is to be loaded in disp_data space location
		MOV		@ R0,A					;perform loading disp_data location using Table2 data and disp_reg 
		INC		R0
		INC		R1
		CJNE		R1,#DISP_REG+6,LOOP103
		RET
;-------------------------------------------------				
					
ISR_T0:			PUSH		PSW
			PUSH		ACC
			CLR		TF0				;clear Timer0 flag bit
			MOV		TH0,#0F8H			;load initial count value
			MOV		TL0,#0CDH
			SETB		COUNTER_BIT			;set counter bit flag
									;monitor the status of other flag bits and act accordingly
			JNB		RESET_READY,CONTINUE_ISR1
			LCALL		SW4_ROUTINE
CONTINUE_ISR1:
			JNB		UPCOUNT_READY,CONTINUE_ISR2
			LCALL		SW1_ROUTINE
CONTINUE_ISR2:
			JNB		DOWNCOUNT_READY,CONTINUE_ISR3
			LCALL		SW2_ROUTINE
CONTINUE_ISR3:
			JNB		DISP_EEPROM_READY,CONTINUE_ISR4
			LCALL		SW3_ROUTINE
CONTINUE_ISR4:
			LCALL		DISPLAY_ROUTINE
			LCALL		BUZZER_SERVICE
EXIT_ISR:		POP		ACC
			POP		PSW
			RETI					
;---------------------------------------------
SW1_ROUTINE:
			JNB	SW1_PIN,LOOP110						;if SW1=0(pressed),jump to LOOP110
			MOV	SW1_COUNTER,#40						;if SW1=1(not pressed),reset SW1_COUNTER
			RET								;and return
LOOP110:		MOV	A,SW1_COUNTER
			CJNE	A,#0,LOOP111						;if SW1_COUNTER not equals 0,then jump to LOOP111
			RET								;if SW1_COUNTER=0,then return

LOOP111:		DJNZ	SW1_COUNTER,EXIT_SW1_ROUTINE				;and jump to EXIT if it is not equal to 0
			SETB	SW1_PRESSED						;if it is reduced to 0,set SW1_PRESSED flag bit
			SETB	BEEP_ON

EXIT_SW1_ROUTINE:
			RET
;---------------------------------------------
SW2_ROUTINE:
			JNB	SW2_PIN,LOOP120						;if SW2=0(pressed),jump to LOOP120
			MOV	SW2_COUNTER,#40						;if SW2=1(not pressed),reset SW2_COUNTER
			RET								;and return
LOOP120:		MOV	A,SW2_COUNTER
			CJNE	A,#0,LOOP121						;if SW2_COUNTER not equals 0,then jump to LOOP121
			RET								;if SW2_COUNTER=0,then return

LOOP121:		DJNZ	SW2_COUNTER,EXIT_SW2_ROUTINE				;and jump to EXIT if it is not equal to 0
			SETB	SW2_PRESSED						;if it is reduced to 0,set SW1_PRESSED flag bit
			SETB	BEEP_ON

EXIT_SW2_ROUTINE:
			RET

;---------------------------------------------

SW3_ROUTINE:
			JNB	SW3_PIN,LOOP130						;if SW3=0(pressed),jump to LOOP130
			MOV	SW3_COUNTER,#40						;if SW3=1(not pressed),reset SW4_COUNTER
			RET								;and return
LOOP130:		MOV	A,SW3_COUNTER
			CJNE	A,#0,LOOP131						;if SW3_COUNTER not equals 0,then jump to LOOP131
			RET								;if SW3_COUNTER=0,then return

LOOP131:		DJNZ	SW3_COUNTER,EXIT_SW3_ROUTINE				;and jump to EXIT if it is not equal to 0
			SETB	SW3_PRESSED						;if it is reduced to 0,set SW4_PRESSED flag bit
			SETB	BEEP_ON

EXIT_SW3_ROUTINE:
			RET

;---------------------------------------------

SW4_ROUTINE:
			JNB	SW4_PIN,LOOP140						;if SW4=0(pressed),jump to LOOP140
			MOV	SW4_COUNTER,#40						;if SW4=1(not pressed),reset SW4_COUNTER
			RET								;and return
LOOP140:		MOV	A,SW4_COUNTER
			CJNE	A,#0,LOOP141						;if SW4_COUNTER not equals 0,then jump to LOOP141
			RET								;if SW4_COUNTER=0,then return

LOOP141:		DJNZ	SW4_COUNTER,EXIT_SW4_ROUTINE				;and jump to EXIT if it is not equal to 0
			SETB	SW4_PRESSED						;if it is reduced to 0,set SW4_PRESSED flag bit
			SETB	BEEP_ON

EXIT_SW4_ROUTINE:
			RET

;---------------------------------------------
BUZZER_SERVICE:										;buzzer service according to the status of beep_on flag bit
			JNB	BEEP_ON,RESET_BUZZER_SERVICE
			SETB	BUZZER_PIN
			DJNZ	BUZ_COUNTER,EXIT_BUZZER_SERVICE				;if beep_on is set,turn on the buzzer for a short while
			CLR	BUZZER_PIN
			CLR	BEEP_ON
RESET_BUZZER_SERVICE:			
			MOV	BUZ_COUNTER,#40
EXIT_BUZZER_SERVICE:
			RET

;---------------------------------------------

DISPLAY_ROUTINE:
			PUSH	00H
			PUSH	01H
			PUSH	05H
			MOV	P0,#0FFH				
			LCALL	TO_BIN
			MOV 	A,#DISP_DATA
			ADD	A,DISP_COUNTER
			MOV	R0,A
			MOV	P0,@ R0
			INC	DISP_COUNTER
			MOV	A,DISP_COUNTER
			CJNE	A,#6,EXIT_DISPLAY_ROUTINE
			MOV	DISP_COUNTER,#0H
EXIT_DISPLAY_ROUTINE:
			POP	05H
			POP	01H
			POP	00H
			RET

;-----------------------------------------------
TO_BIN:								;decide which one of the 6 seven-segment displays will be activated
								;depending upon the status of A,B,C(inputs of 3-to-8 decoder) 
			CLR		A_IN			;initially set the decoder's inputs to 0
			CLR		B_IN
			CLR		C_IN
			MOV		R5,DISP_COUNTER
			INC		R5
			MOV		A,R5			;make A=R5
			MOV		B,#2			;base 2 since we want to convert to binary
			DIV		AB			;perform A/B, quotient and remainder stored in A and B resp.
			MOV		R1,A			;temporarily store A in R1
			MOV		A,B			;copy B in A for some computation
			CJNE		A,#1,NEXT1		;if A not equals 1,jump to NEXT1(A here has a copy of B)
			SETB		A_IN			;if A=1 then make a=1 as well(A here has a copy of B)
NEXT1:			MOV		B,#2			;load base 2 again
			MOV		A,R1			;load back the original value into A
			DIV		AB			;perform A/B, quotient and remainder stored in A and B resp.
			MOV		R1,A			;temporarily store A in R1
			MOV		A,B			;copy B in A for some computation
			CJNE		A,#1,NEXT2		;if A not equals 1,jump to NEXT2(A here has a copy of B)
			SETB		B_IN			;if A=1 then make b=1 as well(A here has a copy of B)
NEXT2:			MOV		A,R1			;load back the original value into A
			CJNE		A,#1,NEXT3		;if A not equals 1,jump to NEXT3
			SETB		C_IN			;if A=1 then make c=1 as well
NEXT3:			RET					;return from subroutine


;------------------------------------------------
START_EEPROM:							;START--> sda high to low while scl is high
			SETB	SDA_PIN
			SETB	SCL_PIN
			JNB	SDA_PIN,START_EEPROM
			JNB	SCL_PIN,START_EEPROM
			CLR	SDA_PIN
			LCALL	NOP_5
			CLR	SCL_PIN
			LCALL	NOP_5
			RET
;-------------------------------------------------
STOP_EEPROM:							;STOP-->  sda low to high while scl is high
			CLR	SDA_PIN
			LCALL	NOP_5
			SETB	SCL_PIN
			LCALL	NOP_5
			SETB	SDA_PIN
			RET
;-------------------------------------------------
SEND_BYTE:
			MOV	R3,#8				;since 1 byte is to be transferred
			CLR	C
LOOP150:	
			LCALL	NOP_5
			RLC	A				;this step ensures that CY flag is loaded with MSB
			MOV	SDA_PIN,C
			LCALL	NOP_5
			SETB	SCL_PIN
			LCALL	NOP_5
			CLR	SCL_PIN				;high-to-low clock pulse gives a falling edge(required for transfer in i2c)
			DJNZ	R3,LOOP150
			SETB	SDA_PIN
			LCALL	NOP_5
			SETB	SCL_PIN
			LCALL	NOP_5
			MOV	C,SDA_PIN			;get the ACK bit sent by slave(EEPROM)
			LCALL	NOP_5
			CLR	SCL_PIN				;ACK bit received in 9th clock pulse
			MOV	ERROR_BIT,C			;get the ACK bit
			RET
;----------------------------------------------------

RECEIVE_BYTE:
			SETB	SDA_PIN				
			MOV	R3,#8				;since 1 byte is to be transferred
LOOP151:		MOV	C,SDA_PIN			;receives 1 bit from slave
			RLC	A				;since msb comes in first
			LCALL	NOP_5
			SETB	SCL_PIN
			LCALL	NOP_5
			CLR	SCL_PIN				;high-to-low clock pulse gives a falling edge(required from transfer in i2c)
			LCALL	NOP_5
			DJNZ	R3,LOOP151
			MOV	DATA_BYTE,A			;save the data byte received
			RET
;------------------------------------------------------			
NACK:			SETB	SDA_PIN
			JNB	SDA_PIN,NACK
			SETB	SCL_PIN
			LCALL	NOP_5
			CLR	SCL_PIN
			RET
;------------------------------------------------------
ACK:			CLR	SDA_PIN
			JB	SDA_PIN,ACK
			SETB	SCL_PIN
			LCALL	NOP_5
			CLR	SCL_PIN
			RET			

;------------------------------------------------------
INC_ADDRESS:							;Range of EEPROM address:0000H to 1FFFH(64K bits)
			CLR	C
			MOV	A,SECOND_WORD_ADDR
			ADD	A,#1
			MOV	SECOND_WORD_ADDR,A
			JC	LOOP152
			RET
LOOP152:		MOV	A,FIRST_WORD_ADDR
			ADDC	A,#0
			CJNE	A,#20H,LOOP153
			MOV	FIRST_WORD_ADDR,#00H
			RET
LOOP153:		MOV	FIRST_WORD_ADDR,A
			RET
;-------------------------------------------------------
NOP_5:			NOP
			NOP
			NOP
			NOP
			NOP
			RET
;-------------------------------------------------------
TRANSMISSION_FAILED:
			MOV	DPTR,#FAIL_MESSAGE
			SJMP	LOOP154

;-------------------------------------------------------
WRITE_FAILED:
			MOV	DPTR,#WRITE_FAIL_MESSAGE
			SJMP	LOOP154
;-------------------------------------------------------
READ_FAILED:
			MOV	DPTR,#READ_FAIL_MESSAGE
			SJMP	LOOP154
;-------------------------------------------------------
DISP_EEPROM_MESSAGE:
			MOV	DPTR,#EEPROM_MESSAGE
LOOP154:		CLR	A
			MOVC	A,@ A+DPTR
LOOP155:		MOV	SBUF,A
			LCALL	XMIT_BYTE
			INC	DPTR
			CLR	A
			MOVC	A,@ A+DPTR
			CJNE	A,#0,LOOP155	
			RET
;-------------------------------------------------------
EEPROM_DELAY:		
			MOV	R1,#255
LOOP156:		MOV	R2,#255
LOOP157:		DJNZ	R2,LOOP157
			DJNZ	R1,LOOP156	
			RET
;-------------------------------------------------------		
TABLE2:			DB	44H,7DH,0C8H,68H,71H,62H,42H,07CH,40H,70H,0FFH	;hex values to be sent to seven segment display for displaying digits 0-9,and no display
FAIL_MESSAGE:		DB	"TRANSMISSION FAILED!",0
EEPROM_MESSAGE:		DB	"Latest counter value written in EEPROM:",0
WRITE_FAIL_MESSAGE:	DB	"(During EEPROM Write)",0
READ_FAIL_MESSAGE:	DB	"(During EEPROM Read)",0
					END
