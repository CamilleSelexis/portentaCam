/*
  This sketch reads a raw Stream of RGB565 pixels
  from the Serial port and displays the frame on
  the window.
  Use with the Examples -> CameraCaptureRawBytes Arduino sketch.
  This example code is in the public domain.
*/

import processing.serial.*;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;

Serial myPort;

// must match resolution used in the sketch
final int imgW = 320;
final int imgH = 240;
final int lx = 140; //90,230
final int ly = 60; //100,180
final int cameraBytesPerPixel = 1;
final int pixelCount = imgW * imgH;
final int bytesPerFrame = pixelCount * cameraBytesPerPixel;
final int bytesCropped = lx*ly;
final int n = 2;
final int thres = 4;
int[] vect = new int[lx+1];
int[] cropy = new int[2];
int[] cropx = new int[2];

float[] avg = new float[lx];
float[] mvt = new float[lx];
float[] result = new float[10];
int[] pos = new int[100];

byte[] cropped = new byte[ly*lx];
PImage myImage;
PImage img2;
byte[] fb = new byte[bytesPerFrame];
byte[] fb2 = new byte[bytesPerFrame];
int found = 0;
void setup() {
  size(640, 480);
  // if you have only ONE serial port active
  myPort = new Serial(this, Serial.list()[0], 115200);          // if you have only ONE serial port active
  cropx[0] = 90;
  cropx[1] = 230;
  cropy[0] = 90;
  cropy[1] = 150;
  // if you know the serial port name
  //myPort = new Serial(this, "COM6", 115200); 
  String[] args = {"TwoFrameTest"};// Windows
  SecondApplet sa = new SecondApplet();
  PApplet.runSketch(args, sa);
  // wait for full frame of bytes
  myPort.buffer(bytesPerFrame);  
  myImage = createImage(imgW, imgH, ALPHA);
  // Let the Arduino sketch know we're ready to receive data
  PImage img = myImage.copy();
  img.resize(640, 480);
  image(img, 0, 0);
  myPort.write('1');
}

void draw() {
  // Time out after 1.5 seconds and ask for new data
  myPort.write('1');
  delay(50);
  //while(myPort.available()<135){println(myPort.available());delay(1);}
  // read the received bytes
  myPort.readBytes(fb);
  fb2 = fb;
  // Access raw bytes via byte buffer  
  ByteBuffer bb = ByteBuffer.wrap(fb);

  int i = 0;

  while (bb.hasRemaining()) {
    // read 8-bit pixel
    byte pixelValue = bb.get();
    // set pixel color
    myImage.pixels[i++] = color(Byte.toUnsignedInt(pixelValue));    
  }
  
  myImage.updatePixels();
  

  PImage img = myImage.copy();

  img.resize(640, 480);
  image(img, 0, 0);
  stroke(255);
  line(cropx[0]*2,cropy[0]*2,cropx[0]*2,cropy[1]*2);
  line(cropx[0]*2,cropy[0]*2,cropx[1]*2,cropy[0]*2);
  line(cropx[0]*2,cropy[1]*2,cropx[1]*2,cropy[1]*2);
  line(cropx[1]*2,cropy[0]*2,cropx[1]*2,cropy[1]*2);
  delay(50);
  myPort.clear();
}
public class SecondApplet extends PApplet {

  public void settings() {
    size(lx*2, ly*2);
    img2 = createImage(lx, ly, ALPHA);
  }
  public void draw() {
  detectEdges();

    ByteBuffer bb2 = ByteBuffer.wrap(cropped);
  
    int l = 0;
  
    while (bb2.hasRemaining()) {
      // read 8-bit pixel
      byte pixelValue = bb2.get();
      // set pixel color
      img2.pixels[l++] = color(Byte.toUnsignedInt(pixelValue));    
    }
    
    img2.updatePixels();
    PImage img = img2.copy();
    img.resize(lx*2, ly*2);
    image(img, 0, 0);
    stroke(255);
    for(int i = 0; i<found-1; i++){
      line(pos[i]*2,0,pos[i]*2,ly*2);
    }
  }
}

void detectEdges() {

  for(int i = 0; i<lx; i++){
    for(int j = 0; j<ly; j++){
        cropped[j*lx+i] = fb[(j+cropy[0])*320+(i+cropx[0])];
          avg[i] += fb[(j+cropy[0])*320+(i+cropx[0])]; //Compute avg on the length () to obtain a 1xly vector
    }
  }
  for(int i = 0; i<lx; i++){
    avg[i] /= ly; //
  }
  //------------------
  for(int i = n; i<lx-n; i++){ // 2-138 = 136
    mvt[i-n] = movingAvg(avg,n,i);
  }    //Compute moving avg on the length averaged vector
  found = 0;
  for(int i = 2*n; i<= lx-2*n-1; i++){
    boolean diff1 = abs(mvt[i]-mvt[i+2]) > thres; //Change into i+2
    boolean diff2 = abs(mvt[i]-mvt[i-2]) > thres; // Change into i-2

    if(diff1 && diff2) {
      print("Found edge at "); println(i);
      pos[found] = i; // Put in pos the x coord of the peak
      found++;
    }
  }
  print("Found ");print(found-1);println(" Edges");
  return;
  
}

float movingAvg(float in[], int n, int x) {

  float mavg = 0;
  for(int i = x-n;i <=(x+n); i++){
    mavg += in[i];
  }
  mavg = mavg/(2*n+1);
  return mavg;
}
