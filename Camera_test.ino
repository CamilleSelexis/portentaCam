/*
Decapeur Software V2.5 by Jérémie Pochon & Camille Aussems
Selexis Genève 17.01.2022
To run on an Arduino Portenta H7 with a vision shield
M7 core
In coordination with Move_on_M4 on M4 core
Vision not yet verified
*/

#include <Portenta_Ethernet.h>
#include <Ethernet.h>
#include <camera.h>
#include <math.h>
#include <stdio.h>

#include "Arduino.h"
#include "RPC.h"
using namespace rtos;

#include <stdint.h>

#define mvt_in  digitalWrite(LEDG,LOFF);digitalWrite(LEDR,LON)
#define mvt_out digitalWrite(LEDR,LOFF);digitalWrite(LEDG,LON)

#define motorON   digitalWrite(D9,HIGH);delay(1)
#define motorOFF  digitalWrite(D9,LOW)

#define pin_crydom  D7 //Relay

const int LON = LOW; // Voltage level is inverted for the LED
const int LOFF = HIGH;

const int Cgear = 139;         //C motor gearbox
const float Ctrans = 1.25;       //C secondary gear ratio
const int Cmicrosteps = 2;     //Microsteps
long stp1tour;       //Number of step in one C rotation.

bool isInit = false;          //Est-ce que la machine est initialisée
bool *PisInit = &isInit;      //Est uniquement initialisée false, puis est passée en true par la routine init.

bool C_start=false;            //Start of the C rotation when tightening
bool* CstartPoint = &C_start; //Pointer to Cstart

volatile bool M4work = false;          //Cette variable est vrai lorsque le M4 effectue une tache
volatile bool *Pworking = &M4work;     //N'est pas utilisé pour le moment mais pourrait être utile

int baud = 115200;          //Baud rate of the serial comunication

CameraClass cam;
uint8_t fb[320*240];        //Buffer for the image capture
uint8_t *Pfb = fb; 

const uint8_t cropx[2] = {100,180};    //Size of the cropped image
const uint8_t cropy[2] = {90,230};
const uint8_t ly = cropy[1]-cropy[0]; //Length of the cropped dimmensions
const uint8_t lx = cropx[1]-cropx[0];

//Light depending parameters for the image detection (will probably need a tweek for each environement)
//Try to change thres and n to have the minimum amount of markers detected while never having 0 of them.
const uint8_t thres = 4;         //Threshold of image detection 2->10
const uint8_t n = 2;             //Size of the moving average 1->2 -> 1 gives 3, 2 gives 5 etc...

//Once set calibration should stay the same
const long calibration = 500;    //Rotation offset

 //Ethernet related ---------------------


//-------------------------------------------//
void setup(){
  bootM4();
  RPC.begin(); 
  Serial.begin(baud); //Begin serial communication aka discussion through usb
  Serial.println("Serial Coms started. RPC starting...");
  pin_init();       //Initialise the pin modes, initial values and interrupts
  digitalWrite(LEDB,LON);

  stp1tour = ceil(200*Cgear*Ctrans*Cmicrosteps);  //number of step in a rotation of C axis: 34750

  cam.begin(CAMERA_R320x240, 15);   //initialise the camera
  cam.standby(true);                //Put it in standby mode
                 //Initialise the RPC coms, also boots the M4
  
//Gives the local IP through serial com

  digitalWrite(LEDB,LOFF);
  digitalWrite(LEDG,LON);      //Green Led while available
  Serial.println("End of init");
} //End of setup loop


//---------------------LOOP---------------------//

void loop() {
  long C_pos = finalPos();
  Serial.println(C_pos);

  delay(1000);
}

void pin_init(){
 pinMode(LEDB, OUTPUT);       //Setting up the led
 pinMode(LEDG,OUTPUT);
 pinMode(D9, OUTPUT);          //Motors X,Z,C,M en/dis-able
 digitalWrite(D9,LOW);        
 pinMode(pin_crydom,OUTPUT);           //Steady-state relay control
 digitalWrite(pin_crydom,LOW);
 pinMode(A0,INPUT);      //Photo-detector - C axis zero (on M4)
 pinMode(A2,INPUT);      //Contacteur - M axis zero (on M4)
 pinMode(D0,INPUT);      //Baumer Z axis zero (on M4)
 pinMode(D6,INPUT);      //Baumer X axis zero (on M4)
}

void M4working(bool working){
  *Pworking = working;
}
