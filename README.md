# Stopwatch-upcounter-and-downcounter-Using-8051-microcontroller

**The aim of this project is to build a stopwatch(millisecond upcounter as well as downcounter) and saving all the stop values in a 2 wire serial EEPROM(BL24C64).**
Six **seven segment displays** have been used to display the counter value.We have used **time division multiplexing technique** in which the SSDs are multiplexed and we send display value to one SSD only.We switch between them over very small duration,this makes it nearly impossible for our eyes to distinguish between them.It also saves us a lot of pins(we can drive all the SSDs using just 8 pins). For implementing this concept,SN74HC138N IC(3-to-8 line decoder) has been used.The 3 input pins(A,B,C) of this IC are responsible for selecting which output is active.The selected output is pulled low,while the remaining outputs are high.
**Timer interrupt** has been implemented(interrupt occurs every 1ms) for proper functioning.There are four switches providing some useful functionalities.The first switch initiates upcounting and stopping.The second switch initiates downcounting and stopping.The third switch reads the latest value written in EEPROM and displays it on our PC(via UART,9600 baud rate).I2C communication has been implemented for the **serial EEPROM interfacing**.The fourth switch resets the counter on being pressed.

**My Role:
(1)Tracing the PCB,analyzing the circuit diagram.
(2)Writing the program in assembly language.**


