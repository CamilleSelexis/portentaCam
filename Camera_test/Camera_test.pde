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
final int lx = 125; //90,230
final int ly = 60; //100,180
final int cameraBytesPerPixel = 1;
final int pixelCount = imgW * imgH;
final int bytesPerFrame = pixelCount * cameraBytesPerPixel;
final int bytesCropped = lx*ly;
final int n = 1;
final int thres = 4;
int found = 0;
int true_found = 0;
int[] vect = new int[lx+1];
int[] cropy = new int[2];
int[] cropx = new int[2];

float[] avg = new float[lx];
float[] mvt = new float[lx-n];
float[] result = new float[10];
int[] pos = new int[100];
int[] pos_true = new int[10];
byte[] cropped = new byte[ly*lx];
PImage myImage;
PImage img2;
byte[] fb = new byte[bytesPerFrame];
byte[] fb2 = new byte[bytesPerFrame];
void setup() {
  size(640, 480);
  // if you have only ONE serial port active
  myPort = new Serial(this, Serial.list()[0], 115200);          // if you have only ONE serial port active
  cropx[0] = 75;
  cropx[1] = 200;
  cropy[0] = 60;
  cropy[1] = 120;
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
    for(int i = 0; i<true_found-1; i++){
      line(pos_true[i]*2,0,pos_true[i]*2,ly*2);
    }
  }
}

void detectEdges() {

  for(int i = 0; i<lx; i++){
    for(int j = 0; j<ly; j++){
        cropped[j*lx+i] = fb[(j+cropy[0])*imgW+(i+cropx[0])];
    }
  }
  float[][] cropped2D = new float[lx][ly];
  float[][] filter2D = new float[3][3];
  float[][] result2Dx = new float[lx][ly];
  float[][] result2Dy = new float[lx][ly];
  float[][] result2D = new float[lx][ly];
  float[][] gaussian2D = new float[3][3];
  float[][] final2D = new float[lx][ly];
  for(int i = 0; i<lx; i++){
    for(int j = 0; j<ly;j++) {
      cropped2D[i][j] = cropped[j*lx + i];
      //print(cropped2D[i][j]);      print(" ");

    }
    //println("\n");
  }
  gaussian2D[0][0] = 1;gaussian2D[0][1] = 2;gaussian2D[0][2] = 1;
  gaussian2D[1][0] = 2;gaussian2D[1][1] = 4;gaussian2D[1][2] = 2;
  gaussian2D[2][0] = 1;gaussian2D[2][1] = 2;gaussian2D[2][2] = 1;
  for(int i = 0; i<3; i++){
    for(int j = 0; j<3;j++) {
      gaussian2D[i][j] = gaussian2D[i][j]/16;
    } //<>//
  }
  convolution_2D(cropped2D,gaussian2D,result2D);
  cropped2D = result2D;
  filter2D[0][0] = -1;filter2D[0][1] = 0;filter2D[0][2] = 1;
  filter2D[1][0] = -2;filter2D[1][1] = 0;filter2D[1][2] = 2;
  filter2D[2][0] = -1;filter2D[2][1] = 0;filter2D[2][2] = 1;
  convolution_2D(cropped2D,filter2D,result2Dx); //<>//
  //cropped2D = result2D;
  filter2D[0][0] = -1;filter2D[0][1] = -2;filter2D[0][2] = -1;
  filter2D[1][0] = 0;filter2D[1][1] = 0;filter2D[1][2] = 0;
  filter2D[2][0] = 1;filter2D[2][1] = 2;filter2D[2][2] = 1;
  convolution_2D(cropped2D,filter2D,result2Dy);
  //convolution_2D(result2Dy,gaussian2D,result2D);

  float min = 255;
  float max = 0;
  for(int i = 0; i<lx; i++){
    for(int j = 0; j<ly;j++) {
      result2D[i][j] = sqrt(pow(result2Dx[i][j],2)+pow(result2Dy[i][j],2));
      if (result2D[i][j]>max) max = result2D[i][j];
      if (result2D[i][j]<min) min = result2D[i][j];
    }
  }
  non_max_suppression(result2D,final2D);
  cropped2D = final2D;
  for(int i = 0; i<lx; i++){
    for(int j = 0; j<ly;j++) {
        final2D[i][j] = final2D[i][j]*255/max;
    }
  }
  //int thresh = int(max/4);
  //  for(int i = 0; i<lx; i++){
  //  for(int j = 0; j<ly;j++) {
  //    if(final2D[i][j]<thresh){
  //      final2D[i][j] = 0;}
  //  }
  //}
  for(int i = 0; i<lx; i++){
    for(int j = 0; j<ly;j++) {
      cropped[j*lx + i] = byte(final2D[i][j]);
      //print(result2D[i][j]);      print(" ");
    }
    //println("\n");
  }
  
  for(int i = 0; i<lx; i++){
    for(int j = 0; j<ly; j++){

          avg[i] += cropped[j*lx + i]; //Compute avg on the height () to obtain a lx vector
    }
    avg[i] /=ly;
  }
  //------------------
  for(int i = n; i<lx-n-1; i++){ // 2-138 = 136
    mvt[i] = movingAvg(avg,n,i);
  }    //Compute moving avg on the length averaged vector
  found = 0;
  for(int i = 2*n; i<= lx-2*n-1; i++){
    boolean diff1 = abs(mvt[i]-mvt[i+n]) > thres; //Change into i+2
    boolean diff2 = abs(mvt[i]-mvt[i-n]) > thres; // Change into i-2

    if(diff1 && diff2) {
      //print("Found edge at "); println(i);
      pos[found] = i; // Put in pos the x coord of the peak
      found++;
    }
  }
  print("Found ");print(found);println(" Edges");
  true_found = found;
  for(int i = 0; i<found-1; i++){
      if(abs(pos[i]-pos[i+1])<5){
        pos[i] = 0;
        pos[i+1] = (pos[i]+pos[i+1])/2;
        true_found--;
      }
  }
  int k = 0;
  for(int i = 0; i<found;i++){ 
    if(pos[i] != 0) {
      pos_true[k] = pos[i];
      k++;
    }
  }
  
  return; //<>//
  
}


float movingAvg(float in[], int n, int x) {

  float mavg = 0;
  for(int i = x-n;i <=(x+n); i++){
    mavg += in[i];
  }
  mavg = mavg/(2*n+1);
  return mavg;
}
void convolution_2D(float N[][], float M[][], float P[][]) {

// find center position of kernel (half of kernel size)

for (int i = 0; i < lx; ++i)              // rows
{
    for (int j = 0; j < ly; ++j)          // columns
    {
        for (int m = 0; m < 3; ++m)     // kernel rows
        {
            for (int n = 0; n < 3; ++n) // kernel columns
            {
                // index of input signal, used to check boundary
                int ii = i + (m - 1);
                int jj = j + (n - 1);

                // ignore input samples which are out of bound
                if (ii >= 0 && ii < lx && jj >= 0 && jj < ly)
                  P[i][j] += N[ii][jj] * M[m][n];
            }
        }
        //P[i][j] = abs(P[i][j]);
    }
}
}

void non_max_suppression(float A[][], float D[][]){
  //We only check in the X direction
  for(int i = 0; i<lx;i++){
    for(int j = 0; j< ly; j++){
     if(i >0 && i<lx-1){
       if( A[i][j] - A[i-1][j]> 0 && A[i][j]-A[i+1][j]>0){
         D[i][j] = A[i][j];

       }
       else{
         D[i][j] = 0;
       }
      }
      else{
        D[i][j] = 0;
      }
    }
  }
}
