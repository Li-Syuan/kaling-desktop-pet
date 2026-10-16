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
            string[] all={"listen","wave","sword","doze","stretch"};
            var choices=new List<string>(); foreach(string g in all) if(!recent.Contains(g)) choices.Add(g);
            Gesture=choices[random.Next(choices.Count)]; GestureAge=0; recent.Enqueue(Gesture);
            while(recent.Count>2) recent.Dequeue();
        }
    }
}
