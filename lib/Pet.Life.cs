using System;
using System.Collections.Generic;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;

// One elapsed-time model owns ambient motion. It never moves the desktop window,
// changes a care value, dispatches an attack, or extends inactivity timers.
public sealed class RenLifeState {
    readonly Random random;
    readonly Queue<string> recent = new Queue<string>();
    public double Time, EyeX, EyeY, HeadX, HeadY, Blink, Warmth, Acknowledge;
    public double NextBlink, NextGesture, GestureAge, Dwell, LeaveHold;
    public string Gesture = "";
    public int PetCount;
    public double LastPet = -100, BlinkStart = -10;
    double targetX, targetY;
    bool wasNear;
    public RenLifeState(int seed) {
        random = new Random(seed); NextBlink = Range(2,5); NextGesture = Range(20,35);
    }
    double Range(double a, double b) { return a + random.NextDouble() * (b-a); }
    static double Ease(double v, double target, double dt, double tau) {
        return v + (target-v) * (1-Math.Exp(-dt/tau));
    }
    public void Interrupt() {
        Gesture = ""; GestureAge = 0; NextGesture = Time + Range(20,50);
    }
    public void ResetAttention() {
        EyeX=EyeY=HeadX=HeadY=targetX=targetY=Dwell=LeaveHold=0; wasNear=false;
    }
    public void Press() { Interrupt(); Acknowledge = .3; }
    public void Pet() {
        Interrupt(); PetCount = Time-LastPet < 8 ? PetCount+1 : 1;
        LastPet=Time; Warmth=6; Acknowledge=.35;
    }
    public void Snack() { Interrupt(); Warmth=3; }
    public void Step(double dt, double x, double y, bool near, bool look,
                     bool autonomous, bool quiet, bool visible, bool busy) {
        // A debugger pause, suspend, hidden window or delayed dispatcher cannot
        // fast-forward dozens of gestures or create a burst on return.
        if (!visible || dt <= 0 || dt > .25) return;
        Time += dt; Warmth=Math.Max(0,Warmth-dt); Acknowledge=Math.Max(0,Acknowledge-dt);
        if(Time >= NextBlink) { BlinkStart=Time; NextBlink=Time+Range(2.8,6.8); }
        double blinkAge=Time-BlinkStart;
        Blink=blinkAge >= 0 && blinkAge < .18 ? Math.Sin(blinkAge/.18*Math.PI) : 0;
        if(quiet || !look || busy) { near=false; LeaveHold=0; Dwell=0; }
        if(near) {
            Dwell += dt; LeaveHold=.65;
            targetX=Math.Max(-1,Math.Min(1,x)); targetY=Math.Max(-1,Math.Min(1,y));
        } else {
            Dwell=0; LeaveHold=Math.Max(0,LeaveHold-dt);
            if(LeaveHold<=0) { targetX=0; targetY=0; }
        }
        if(near && !wasNear) Dwell=0;
        wasNear=near;
        EyeX=Ease(EyeX,targetX,dt,.10); EyeY=Ease(EyeY,targetY,dt,.12);
        HeadX=Ease(HeadX,(Dwell>.32 || !near) ? targetX : 0,dt,.32);
        HeadY=Ease(HeadY,(Dwell>.32 || !near) ? targetY : 0,dt,.38);
        if(busy || quiet || !autonomous) {
            if(Gesture!="") Interrupt();
            // Re-enable with breathing room; do not fire a stale deadline.
            NextGesture=Math.Max(NextGesture,Time+8);
            return;
        }
        if(Gesture!="") {
            GestureAge+=dt;
            if(GestureAge>=4) { Gesture=""; GestureAge=0; NextGesture=Time+Range(20,50); }
        } else if(Time>=NextGesture) {
            string[] all={"listen","sleeve","sword","doze","stretch"};
            var choices=new List<string>(); foreach(string g in all) if(!recent.Contains(g)) choices.Add(g);
            Gesture=choices[random.Next(choices.Count)]; GestureAge=0; recent.Enqueue(Gesture);
            while(recent.Count>2) recent.Dequeue();
        }
    }
}

// Retained WPF DrawingImage: one visible actor, reusable crops and drawing tree.
// Independent ears/eyes/head/hair share the same body-space coordinates.
public sealed class RenLifeVisual {
    readonly Dictionary<string,BitmapSource> parts = new Dictionary<string,BitmapSource>();
    readonly DrawingGroup drawing = new DrawingGroup();
    public DrawingImage Image { get; private set; }
    public RenLifeVisual(string path) {
        var atlas=new BitmapImage(); atlas.BeginInit(); atlas.CacheOption=BitmapCacheOption.OnLoad;
        atlas.UriSource=new Uri(path); atlas.EndInit(); atlas.Freeze();
        if(atlas.PixelWidth!=1536 || atlas.PixelHeight!=1024) throw new ArgumentException("Invalid Ren life parts");
        Crop(atlas,"body",91,47,372,343); Crop(atlas,"head",592,65,338,322);
        Crop(atlas,"hair",1178,26,255,373); Crop(atlas,"earL",223,429,112,215);
        Crop(atlas,"earR",704,429,110,215); Crop(atlas,"eyes",1092,488,392,83);
        Crop(atlas,"closed",67,820,388,53); Crop(atlas,"soft",569,810,399,67);
        Image=new DrawingImage(drawing);
    }
    void Crop(BitmapSource atlas,string name,int x,int y,int w,int h) {
        var p=new CroppedBitmap(atlas,new Int32Rect(x,y,w,h));p.Freeze();parts[name]=p;
    }
    void Part(DrawingContext dc,string name,double x,double y,double w,double h) {
        dc.DrawImage(parts[name],new Rect(x,y,w,h));
    }
    static Geometry Polygon(params double[] xy) {
        var g=new StreamGeometry(); using(var c=g.Open()) {
            c.BeginFigure(new Point(xy[0],xy[1]),true,true);
            for(int i=2;i<xy.Length;i+=2)c.LineTo(new Point(xy[i],xy[i+1]),true,false);
        } g.Freeze(); return g;
    }
    // Sleeve boundaries overlap under the torso, keeping shoulder seams covered.
    static readonly Geometry leftArm=Polygon(43,110,77,110,76,145,43,151);
    static readonly Geometry rightArm=Polygon(116,110,151,110,151,151,117,145);
    static readonly Geometry torso=Polygon(76,106,117,106,117,145,151,151,151,204,43,204,43,151,76,145);
    public void Render(RenLifeState m,bool quiet,bool petting) {
        double breath=Math.Sin(m.Time*Math.PI*2/3.8), amp=quiet?.5:1;
        double pulse=m.Gesture==""?0:Math.Pow(Math.Sin(Math.PI*Math.Min(1,m.GestureAge/4)),2);
        double nod=m.Gesture=="doze"?pulse*3.2:0;
        double tilt=m.HeadX*2.2 + (m.Gesture=="listen"?-4*pulse:0);
        double relax=petting?1:Math.Min(1,m.Warmth/3);
        tilt+=relax*(m.PetCount>=3?-3:1.6);
        double headY=breath*.55*amp + m.HeadY*.9 + nod;
        double sleeve=m.Gesture=="sleeve"?pulse*5:0;
        double sword=m.Gesture=="sword"?pulse*4:0;
        double stretch=m.Gesture=="stretch"?pulse:0;
        using(var dc=drawing.Open()) {
            dc.DrawRectangle(Brushes.Transparent,null,new Rect(0,0,192,208));
            dc.PushClip(new RectangleGeometry(new Rect(0,0,192,208)));
            dc.PushTransform(new RotateTransform(Math.Sin(m.Time*1.5-.8)*1.0*amp,126,76));
            Part(dc,"hair",113,53,65,139);dc.Pop();
            dc.PushTransform(new ScaleTransform(1,1+breath*.006*amp+stretch*.018,96,200));
            dc.PushClip(leftArm);dc.PushTransform(new RotateTransform(-sleeve-stretch*4,77,113));
            Part(dc,"body",44,106,104,96);dc.Pop();dc.Pop();
            dc.PushClip(rightArm);dc.PushTransform(new RotateTransform(sword+stretch*4,116,113));
            Part(dc,"body",44,106,104,96);dc.Pop();dc.Pop();
            dc.PushClip(torso);Part(dc,"body",44,106,104,96);dc.Pop();dc.Pop();
            dc.PushTransform(new TranslateTransform(m.HeadX*.7,headY-m.Acknowledge*2));
            dc.PushTransform(new RotateTransform(tilt,96,116));
            double ear=Math.Sin(m.Time*1.7)*.7*amp + (m.Gesture=="listen"?pulse*6:0) + relax*2;
            dc.PushTransform(new RotateTransform(-ear,77,60));Part(dc,"earL",64,8,25,54);dc.Pop();
            dc.PushTransform(new RotateTransform(ear*.7,100,60));Part(dc,"earR",93,8,25,54);dc.Pop();
            Part(dc,"head",48,48,96,91.46);
            string eyes=m.Blink>.55 || nod>2.4 ? "closed" : relax>.25?"soft":"eyes";
            // Eye sockets move a fraction before the head; bounds stay in the face.
            double ex=66+m.EyeX*1.4, ey=100+m.EyeY*.8;
            if(eyes=="closed")Part(dc,eyes,ex,ey+4,61,8.3);
            else if(eyes=="soft")Part(dc,eyes,ex,ey+1.8,61,10.2);
            else Part(dc,eyes,ex,ey+m.Blink*3,61,12.9-m.Blink*6);
            dc.Pop();dc.Pop();dc.Pop();
        }
    }
}
