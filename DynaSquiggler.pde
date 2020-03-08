// DynaSquiggler by Stuart Cupit
// developed using processing 3.5.4
// check source code for global config variables
// add extra libraries toxiclib, controlP5 and the new video2 manually
// not required but useful, on windows i've been using manycam https://manycam.com/ to desaturate
//   adjust contrast and brightness, zoom in, etc 

// to use
// press a lots to add particles
// adjust parameters untill happy with the stippling
// press l to create single line drawing
// (export gcode once working)

// todo
// export gcode

// check key code for the various keys that can be used
// a=add some particles at the mouse position
// l=toggle line mode
// g=grab webcam image to stipple
// s=save screenshot
// r=toggle record screenshot sequence for making videos, check the output folder
// m=toggle show underlying stippling image
// i=toggle on screen controls to change some parameters


import processing.video.*; // uses the video 2 beta from github https://github.com/processing/processing-video/releases
import toxi.geom.*;
import toxi.physics2d.*;
import toxi.physics2d.behaviors.*;
import controlP5.*;

//global configureation variables
boolean useCam = true; // use a webcam or load an image
int whichCam = 0; // indes num of which webcam to use if you have more than 1


Capture cam;
PImage attractionMap; 
PVector screenSize;
float screenSizeAve;
int numBoids = 500;
boolean useGrab = false;
boolean record = false;
boolean lineMode = false;
int frameNum = 0;
boolean drawAttractionMap = false;
ArrayList<Particle> particleList = new ArrayList<Particle>();
ArrayList<pathPoint> pathList = new ArrayList<pathPoint>();
float tightness = -10;
boolean showFrameRate = false;
boolean saved = true;

ControlP5 cp5;
boolean UI = true;
color UILableColour = color(0);


VerletPhysics2D physics;


void setup() {
  size(1200, 1600);
  screenSize = new PVector(1200, 1600);
  screenSizeAve = (screenSize.x + screenSize.y) / 2;
  
  imageMode(CENTER);
  
  physics = new VerletPhysics2D();
      
     
  if (useCam) {
    String[] cameras = Capture.list();
      
    if (cameras.length == 0) {
      println("There are no cameras available for capture.");
      exit();
    } else {
      println("Available cameras:");
      for (int i = 0; i < cameras.length; i++) {
        println(cameras[i]);
      }
      
      // The camera can be initialized directly using an 
      // element from the array returned by list():
      cam = new Capture(this, 320, 240, cameras[whichCam]);
      cam.start();    
      println("width = ", cam.width, " : height = ",  cam.height);
      attractionMap = new PImage((cam.height / 4) * 3, cam.height);
    } 
  } else {
    attractionMap = loadImage("SamplePortrateBlur.png");
    //image(attractionMap, 0, 0);
  }
  
  Particle  p;
  
  p = new Particle(screenSize.x / 2, screenSize.y / 2);
  //particleList.add(p);
  physics.addParticle(p);
  p.atr = new AttractionBehavior2D(p, screenSizeAve * 10, 0.01, 0.01);
  physics.addBehavior(p.atr);
  p.lock();
  
    cp5 = new ControlP5(this);
    int spaceing = 70; 
    int pos = spaceing;
 
    cp5.addSlider("Damping")
     .setSize(300,50)
     .setPosition(20, pos)
     .setRange(0.8, 1.0)
     .setValue(.98)
     .setFont(createFont("arial", 25))
     .getCaptionLabel().setColor(UILableColour);
     ;
     
    pos += spaceing;
    cp5.addSlider("Tightness")
     .setSize(300,50)
     .setPosition(20, pos)
     .setRange(-40, 40)
     .setValue(10)
     .setFont(createFont("arial", 25))
     .getCaptionLabel().setColor(UILableColour);
     ;
     
    pos += spaceing;
    cp5.addSlider("repulsion")
     .setSize(300,50)
     .setPosition(20, pos)
     .setRange(0.1, 3)
     .setValue(1)
     .setFont(createFont("arial", 25))
     .getCaptionLabel().setColor(UILableColour);
     ;
}


void captureEvent(Capture cam) {
  cam.read();
}


void draw() {
  background(255);
   Particle  p;
   int spawnSpread = 100;
   
   if (particleList.size() < numBoids) {
     for (int i = 0; i < 10; i ++) {
       
        p = new Particle(random(mouseX - spawnSpread, mouseX + spawnSpread), random(mouseY - spawnSpread, mouseY + spawnSpread));
        particleList.add(p);
        physics.addParticle(p);
        p.atr = new AttractionBehavior2D(p, 20.0, -0.2, 0.01);
        physics.addBehavior(p.atr);
     }
     print(", " + particleList.size());
   }
   
    if (useCam) {
      if (cam.available() == true) {
        //cam.read();
      } else {
        //println("camera error");
      }
      if (!useGrab) {
        attractionMap.copy(cam, (cam.height / 2) - (((cam.height / 4) * 3) / 2), 0, (cam.height / 2) + (((cam.height / 4) * 3) / 2), cam.height, 0, 0, ((cam.height / 4) * 3), cam.height);
        //attractionMap.filter(GRAY);
        attractionMap.filter(BLUR);
        //ContrastAndBrightness(attractionMap, attractionMap,2,-50);
      }
      
      //attractionMap.resize(int(screenSize.x), int(screenSize.y));
      
      // The following does the same, and is faster when just drawing the image
      // without any additional resizing, transformations, or tint.
      //set(0, 0, cam);
    } 
   
   
  
  if (drawAttractionMap) {
    image(attractionMap, screenSize.x / 2, screenSize.y / 2, screenSize.x, screenSize.y );
  }
 
    //thread("drawParticles");
    thread("updateParticles");
    
    drawParticles();
    //updateParticles();
    
    physics.update();
    
  if (!lineMode) {
 
  } else {
    for (int i = 0; i < 10; i ++) {
      updateLine();
    }
    
    stroke(0,128,255);
    strokeWeight(2);
    noFill();
    
    curveTightness(cp5.getController("Tightness").getValue());
    beginShape();
    for (int i = 0; i < pathList.size(); i ++) {
      //line(pathList.get(i).pos.x, pathList.get(i).pos.y, pathList.get(i - 1).pos.x, pathList.get(i - 1).pos.y);
      //curveVertex(pathList.get(i).pos.x, pathList.get(i).pos.y);
      curveVertex(particleList.get(pathList.get(i).particleIndex).x, particleList.get(pathList.get(i).particleIndex).y);
    }
    endShape();
  }
  
  if (showFrameRate) {
    println("Framerate = " + frameRate);
  }
  
  if (record) {
    if(saved) {
      frameNum ++;
      saved = false;
      thread("save");
    }
  }
}


void save() {
  save("C:/work/DynaSquiggler/DynaSquigglerFrames/frame" + frameNum + ".jpg");
  //println("saving C:/work/DynaSquiggler/DynaSquigglerFrames/frame" + frameNum + ".jpg");
  saved = true;
}


void keyPressed() {
  if(key == 'i') {
    UI = !UI;
    if (!UI) {
      cp5.hide();
    } else {
      cp5.show();
    }
  }
  if(key == 'r') {
    record = !record;
    println("toggling record mode  " + record);
    frameNum = 0;
  }
  if(key == 'g') {
    useGrab = !useGrab;
    println("toggling shapshot mode  " + useGrab);
  }
  if(key == 's') {
    String filename = "squiggler" + "-" + year() + nf(month(), 2) + nf(day(), 2) + "-" + nf(hour(), 2) + nf(minute(), 2) + nf(second(), 2) + ".jpg";
    println("saving ", filename);
    save(filename);
  }
  if(key == ESC) {
    exit();
  }
  if(key == 'm') {
    drawAttractionMap = !drawAttractionMap;
  }
  if(key == 'a') {
    numBoids += 100;
  }
  if(key == 'f') {
    showFrameRate = !showFrameRate;
  }
  if(key == 'l') {
    int currentParticleIndex;
    lineMode = !lineMode;
    Particle  p;
    pathPoint pp;
      
    if (lineMode) {
      println("toggling line mode with " + particleList.size() + " points");
      
      //clear the found flags
      for (int i = 0; i < particleList.size(); i ++) {
        p = particleList.get(i);
        p.found = false;
      }
      
      //choose a random particle to start and store
      currentParticleIndex = int(random(particleList.size()));
  
      pathList.clear();
  
      pp = new pathPoint();
      pathList.add(pp);
      p = particleList.get(currentParticleIndex);
      p.found = true;
      pp.pos.x = p.x;
      pp.pos.y = p.y;
      pp.particleIndex = currentParticleIndex;
    }
  }

}


void updateLine() {
  Particle  p;
  pathPoint pp;
  float dist = 1000;
  float tempDist;
  PVector tempPos = new PVector(); 
  int closestParticleIndex = -1;

  pp = pathList.get(pathList.size() - 1);

  //find the x closest particles
  for (int i = 0; i < particleList.size(); i ++) {
    p = particleList.get(i);
    if (!p.found) {
      tempPos.x = p.x;
      tempPos.y = p.y;
      tempDist = PVector.dist(tempPos, pp.pos);
      if (tempDist < dist) {
        dist = tempDist;
        closestParticleIndex = i;
      }
    }
  }
  
 if (closestParticleIndex != -1) {
    pp = new pathPoint();
    pathList.add(pp);
    p = particleList.get(closestParticleIndex);
    pp.pos.x = p.x;
    pp.pos.y = p.y;
    pp.particleIndex = closestParticleIndex;
    p.found = true;
    println(pathList.size());
  }
}


void drawParticles() {
  Particle  p;
  strokeWeight(0);
  
  if (drawAttractionMap) {
    fill(255, 0, 0);
  } else {
    fill(0, 0, 0);
  }

   for (int i = 0; i < particleList.size(); i ++) {
     p = particleList.get(i);
     p.display();
   }
}


void updateParticles() {
  Particle  p;
  color c;
  float mag;
  float repulsion;
  
   for (int i = 0; i < particleList.size(); i ++) {
     p = particleList.get(i);
   
     float vel = pow(p.getVelocity().x, 2) +  pow(p.getVelocity().y, 2);
     //println(vel);
      
     if (vel > 1) {
       p.scaleVelocity(0.9);
     } else {
       p.scaleVelocity(cp5.getController("Damping").getValue());
     }
     
     
     c = attractionMap.get(int(p.x * (attractionMap.width / screenSize.x)), int(p.y * (attractionMap.height / screenSize.y)));
     //mag = (-0.00102 + (1 - (red(c) / 255)) * 0.00103);
     repulsion = cp5.getController("repulsion").getValue();
     mag = (10 * repulsion) + (((red(c) / 255)) * (35 * repulsion));

     //mag = -0.2;
     p.atr.setRadius(mag);
   }
}


class Particle extends VerletParticle2D{
  AttractionBehavior2D atr;
  boolean found;
  
  Particle(float x, float y){
   super(x, y); 
  }
  
  void display(){
    circle(x, y, 0.005 * screenSizeAve);
    //square(x, y, 0.005 * screenSizeAve);
  }
}


class pathPoint {
  PVector pos = new PVector();
  int particleIndex;
}


//image processing function to enhance contrast
//this doesn't make sense without also adjusting the brightness at the same time
void ContrastAndBrightness(PImage input, PImage output,float cont,float bright)
{
   int w = input.width;
   int h = input.height;
   
   //our assumption is the image sizes are the same
   //so test this here and if it's not true just return with a warning
   if(w != output.width || h != output.height)
   {
     println("error: image dimensions must agree");
     return;
   }
   
   //this is required before manipulating the image pixels directly
   input.loadPixels();
   output.loadPixels();
      
   //loop through all pixels in the image
   for(int i = 0; i < w*h; i++)
   {  
       //get color values from the current pixel (which are stored as a list of type 'color')
       color inColor = input.pixels[i];
       
       //slow version for illustration purposes - calling a function inside this loop
       //is a big no no, it will be very slow, plust we need an extra cast
       //as this loop is being called w * h times, that can be a million times or more!
       //so comment this version and use the one below
       int r = (int) red(input.pixels[i]);
       int g = (int) green(input.pixels[i]);
       int b = (int) blue(input.pixels[i]);
       
       //here the much faster version (uses bit-shifting) - uncomment to try
       //int r = (inColor >> 16) & 0xFF; //like calling the function red(), but faster
       //int g = (inColor >> 8) & 0xFF;
       //int b = inColor & 0xFF;      
       
       //apply contrast (multiplcation) and brightness (addition)
       r = (int)(r * cont + bright); //floating point aritmetic so convert back to int with a cast (i.e. '(int)');
       g = (int)(g * cont + bright);
       b = (int)(b * cont + bright);
       
       //slow but absolutely essential - check that we don't overflow (i.e. r,g and b must be in the range of 0 to 255)
       //to explain: this nest two statements, sperately it would be r = r < 0 ? 0 : r; and r = r > 255 ? 255 : 0;
       //you can also do this with if statements and it would do the same just take up more space
       r = r < 0 ? 0 : r > 255 ? 255 : r;
       g = g < 0 ? 0 : g > 255 ? 255 : g;
       b = b < 0 ? 0 : b > 255 ? 255 : b;
       
       //and again in reverse for illustration - calling the color function is slow so use the bit-shifting version below
       output.pixels[i] = color(r ,g,b);
       //output.pixels[i]= 0xff000000 | (r << 16) | (g << 8) | b; //this does the same but faster
   
   }
   
   //so that we can display the new image we must call this for each image
   input.updatePixels();
   output.updatePixels();
}
