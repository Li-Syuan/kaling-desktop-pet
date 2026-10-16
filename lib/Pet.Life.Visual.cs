using System;
using System.Collections.Generic;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;

// Whole-character art is kept intact. A continuous, very small deformation
// moves the authored silhouette; independently generated body parts are never assembled.
public sealed class RenLifeVisual {
    public readonly RenPoseArt Art;
    readonly BitmapSource[] daily=new BitmapSource[8], actions=new BitmapSource[8];
    readonly DrawingGroup features=new DrawingGroup(), drawing=new DrawingGroup();
    readonly DrawingImage featureImage;
    readonly List<Tile> tiles=new List<Tile>();
    public DrawingImage Image {get;private set;}
    public string LastPose {get;private set;}
    sealed class Tile { public Point A,B,C; public MatrixTransform Transform; }
    public RenLifeVisual(string folder) {
        Art=new RenPoseArt(folder);
        for(int i=0;i<8;i++){daily[i]=Place(Art.Daily[i]);actions[i]=Place(Art.Actions[i]);}
        featureImage=new DrawingImage(features);Image=new DrawingImage(drawing);
        using(var dc=drawing.Open()){dc.DrawRectangle(Brushes.Transparent,null,new Rect(0,0,192,208));}
        for(int y=0;y<8;y++)for(int x=0;x<4;x++){
            double l=x*48,r=l+48,t=y*26,b=t+26;
            AddTile(new Point(l,t),new Point(r,t),new Point(r,b));
            AddTile(new Point(l,t),new Point(r,b),new Point(l,b));
        }
        Render(new RenLifeState(0),true,false);
    }
    BitmapSource Place(RenPose p){
        var v=new DrawingVisual();using(var dc=v.RenderOpen()){
            dc.DrawImage(p.Image,new Rect(84-p.Anchor*p.Scale,200-p.Height*p.Scale,p.Width*p.Scale,p.Height*p.Scale));
        }
        var b=new RenderTargetBitmap(768,832,384,384,PixelFormats.Pbgra32);b.Render(v);b.Freeze();return b;
    }
    void AddTile(Point a,Point b,Point c){
        var g=new StreamGeometry();using(var d=g.Open()){d.BeginFigure(a,true,true);d.LineTo(b,true,false);d.LineTo(c,true,false);}g.Freeze();
        var transform=new MatrixTransform();var group=new DrawingGroup{ClipGeometry=g,Transform=transform};
        using(var dc=group.Open()){dc.DrawImage(featureImage,new Rect(0,0,192,208));}
        RenderOptions.SetEdgeMode(group,EdgeMode.Aliased);drawing.Children.Add(group);
        tiles.Add(new Tile{A=a,B=b,C=c,Transform=transform});
    }
    static Matrix Map(Point a,Point b,Point c,Point qa,Point qb,Point qc){
        double x1=b.X-a.X,y1=b.Y-a.Y,x2=c.X-a.X,y2=c.Y-a.Y,det=x1*y2-y1*x2;
        double u1=qb.X-qa.X,v1=qb.Y-qa.Y,u2=qc.X-qa.X,v2=qc.Y-qa.Y;
        double m11=(u1*y2-u2*y1)/det,m21=(u2*x1-u1*x2)/det;
        double m12=(v1*y2-v2*y1)/det,m22=(v2*x1-v1*x2)/det;
        return new Matrix(m11,m12,m21,m22,qa.X-a.X*m11-a.Y*m21,qa.Y-a.X*m12-a.Y*m22);
    }
    static double Smooth(double t){t=Math.Max(0,Math.Min(1,t));return t*t*(3-2*t);}
    Point Deform(Point p,RenLifeState m,bool quiet,bool petting){
        double amp=quiet?.35:1,breath=Math.Sin(m.Time*2*Math.PI/3.8);
        double pulse=m.Gesture==""?0:Math.Pow(Math.Sin(Math.PI*Math.Min(1,m.GestureAge/4)),2);
        double warmth=petting?1:Math.Min(1,m.Warmth/3);
        double tilt=(m.HeadX*.7+(m.Gesture=="listen"?-1.3*pulse:0)+warmth*(m.PetCount>=3?-1.2:.5))*Math.PI/180;
        double w=1-Smooth((p.Y-120)/80),dx=p.X-84,dy=p.Y-123;
        double x=p.X+w*(dx*(Math.Cos(tilt)-1)-dy*Math.Sin(tilt)+m.HeadX*.45);
        double y=p.Y+w*(dx*Math.Sin(tilt)+dy*(Math.Cos(tilt)-1)-breath*.6*amp+m.HeadY*.5+m.Acknowledge*1.8);
        if(m.Gesture=="doze")y+=w*pulse*1.4;
        // Ear tips and ponytail sway smoothly within the same original drawing.
        x+=Smooth((45-p.Y)/35)*Math.Sin(m.Time*1.7+p.X*.03)*.32*amp;
        x+=Smooth((p.X-125)/45)*Smooth((p.Y-65)/80)*Math.Sin(m.Time*1.5-.7)*.45*amp;
        return new Point(x,y);
    }
    public void Render(RenLifeState m,bool quiet,bool petting){
        double pulse=m.Gesture==""?0:Math.Pow(Math.Sin(Math.PI*Math.Min(1,m.GestureAge/4)),2);
        int gesture=m.Gesture=="stretch"?7:m.Gesture=="wave"?6:-1;
        double blend=gesture>=0 || m.Gesture=="sword" ? Math.Min(1,pulse*5) : 0;
        using(var dc=features.Open()){
            dc.PushOpacity(1-blend);dc.DrawImage(daily[0],new Rect(0,0,192,208));dc.Pop();
            // Same-identity whole poses enter and leave briefly; face blinks only
            // replace a small skin area, so clothing/hair never flicker on blink.
            if(gesture>=0){dc.PushOpacity(blend);dc.DrawImage(daily[gesture],new Rect(0,0,192,208));dc.Pop();}
            else if(m.Gesture=="sword"){dc.PushOpacity(blend);dc.DrawImage(actions[4],new Rect(0,0,192,208));dc.Pop();}
            else{
                if(!quiet && Math.Abs(m.EyeX)+Math.Abs(m.EyeY)>.02){
                    foreach(var eye in new[]{new Rect(64,107,17,12),new Rect(92,107,17,12)}){
                        dc.PushClip(new RectangleGeometry(eye));
                        dc.DrawImage(daily[0],new Rect(m.EyeX*.55,m.EyeY*.25,192,208));dc.Pop();
                    }
                }
                double close=Math.Max(m.Blink,petting?1:Math.Min(1,m.Warmth/5));
                if(m.Gesture=="doze")close=Math.Max(close,pulse);
                if(close>.03){
                    dc.PushClip(new EllipseGeometry(new Point(84,115),30,14));
                    dc.PushOpacity(Smooth(close));dc.DrawImage(daily[1],new Rect(0,0,192,208));dc.Pop();dc.Pop();
                }
            }
        }
        foreach(var t in tiles)t.Transform.Matrix=Map(t.A,t.B,t.C,Deform(t.A,m,quiet,petting),Deform(t.B,m,quiet,petting),Deform(t.C,m,quiet,petting));
        LastPose=petting?"pet":m.Gesture==""?"idle":m.Gesture;
    }
    public BitmapSource Frame(int row,int frame){
        BitmapSource source=daily[0];double dx=0,dy=0,angle=0,sx=1,sy=1;
        double phase=(frame%4)*Math.PI/2, wave=Math.Sin(phase);
        switch(row){
            case 0: source=daily[frame==2?1:0];break;
            case 1: case 2: source=daily[frame%2==0?2:3];dy=-Math.Abs(wave)*1.4;angle=wave*.45;sx=row==1?-1:1;break;
            case 3: source=daily[6];angle=wave*.65;break;
            case 4: source=daily[7];dy=new[]{0.0,-10,-16,-6}[frame%4];break;
            case 5: source=daily[0];angle=-2;break;
            case 6: source=actions[3];angle=wave;break;
            case 7: source=daily[0];angle=1.2;break;
            case 8: source=daily[frame==2?1:0];break;
            case 9: case 10: source=daily[0];angle=Math.Sin((frame+(row-9)*8)*Math.PI/8)*1.4;break;
            case 11: source=daily[1];angle=wave*.7;break;
            case 12: case 13: case 14: source=actions[row-12];dy=wave*.7;angle=wave*.35;break;
            case 15: source=daily[4];sy=1+wave*.004;break;
            case 16: source=daily[5];sy=1+wave*.004;break;
            case 17: source=daily[7];sy=1+wave*.007;break;
            case 18: source=daily[frame%2==0?6:0];angle=wave*3;sx=frame==2?-1:1;break;
            case 19: source=actions[3];dy=-3;angle=wave*2;break;
            case 20: source=daily[6];dy=new[]{18.0,8,0,4}[frame%4];break;
            case 21: source=actions[new[]{4,5,6,7}[frame%4]];break;
            case 22: source=actions[new[]{4,5,6,7}[frame%4]];dx=wave*2;break;
            case 23: source=actions[new[]{4,6,5,7}[frame%4]];break;
        }
        var v=new DrawingVisual();using(var dc=v.RenderOpen()){
            dc.PushTransform(new TranslateTransform(dx,dy));dc.PushTransform(new RotateTransform(angle,84,195));
            dc.PushTransform(new ScaleTransform(sx,sy,96,200));dc.DrawImage(source,new Rect(0,0,192,208));dc.Pop();dc.Pop();dc.Pop();
        }
        var b=new RenderTargetBitmap(192,208,96,96,PixelFormats.Pbgra32);b.Render(v);b.Freeze();return b;
    }
}
