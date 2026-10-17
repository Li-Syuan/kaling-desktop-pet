using System;
using System.Collections.Generic;
using System.Globalization;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace KalingWorld {
    public sealed class ActorArt {
        public string Id,Name;
        public Dictionary<string,ImageSource> Frames=new Dictionary<string,ImageSource>();
        public int[] Counts;
        public ImageSource[] RenDaily,Signature;
    }
    public sealed class Stage : FrameworkElement {
        public Session Session;
        public List<ActorArt> Art=new List<ActorArt>();
        public ImageSource BackgroundArt,ForestArt,PondArt,Box,Ball,Poop;
        public ImageSource[] Props,PlayProps;
        public int[] Fish={0,0,0,0},Flowers={0,0,0};
        public List<Point> Messes=new List<Point>();
        public bool Decorating;
        public string PendingFurniture="";
        public event EventHandler Interacted;
        public double PressX,PressY;
        int pressed=-1;bool dragged;
        readonly Dictionary<string,Brush> brushes=new Dictionary<string,Brush>();
        static readonly Typeface Font=new Typeface("Microsoft JhengHei UI");
        Brush B(string c){Brush b;if(!brushes.TryGetValue(c,out b)){b=(SolidColorBrush)new BrushConverter().ConvertFromString(c);b.Freeze();brushes[c]=b;}return b;}
        void Text(DrawingContext d,string t,double x,double y,double size=14,string color="#355246",double width=800){var f=new FormattedText(t??"",CultureInfo.GetCultureInfo("zh-TW"),FlowDirection.LeftToRight,Font,size,B(color),1.0);f.MaxTextWidth=width;d.DrawText(f,new Point(x,y));}
        void Image(DrawingContext d,ImageSource image,double x,double bottom,double width,double height){if(image==null)return;double ratio=Math.Min(width/image.Width,height/image.Height);double w=image.Width*ratio,h=image.Height*ratio;d.DrawImage(image,new Rect(x-w/2,bottom-h,w,h));}
        void Prop(DrawingContext d,int i,double x,double bottom,double width=150,double height=150){if(Props!=null&&i>=0&&i<Props.Length)Image(d,Props[i],x,bottom,width,height);}
        int PropId(string id){return id=="hammock"?0:id=="swing"?1:id=="leaves"?2:id=="basket"?3:id=="aquarium"?4:id=="flowers"?5:id=="stone"?6:id=="shell"?7:id=="mushroom"?15:-1;}
        int Row(Actor a){
            if(a.Moving)return a.Facing<0?2:1;
            switch(a.Action){case "pet":return 11;case "cookie":return 12;case "tea":return 14;case "sit":case "swing":case "polish":return 15;case "doze":return 16;case "wave":return 3;case "jump":return 4;case "peek":case "crouch":return 20;case "push":case "sweep":return 24;case "shake":return 18;case "watch":return 8;case "signature":return a.Id=="kaling"?17:a.Id=="mushroom"?20:a.Id=="ribbon-pig"?18:a.Id=="slime"?4:15;default:return 0;}
        }
        void DrawActor(DrawingContext d,int index){
            Actor a=Session.Actors[index];if(a.Hidden)return;ActorArt art=Art[index];double t=a.Age,x=a.X,y=a.Y,w=a.Id=="ren"||a.Id=="kaling"?180:145;
            double sx=1,sy=1,angle=0,dy=0;int row=Row(a);bool signature=a.Action=="signature";
            if(a.Moving){dy=-Math.Abs(Math.Sin(t*8))*4;if(a.Id=="slime"||a.Id=="mushroom"){dy=-Math.Abs(Math.Sin(t*7))*14;sy=1+.05*Math.Sin(t*14);sx=1-.035*Math.Sin(t*14);}else angle=Math.Sin(t*8)*1.5;
                if(signature&&a.Id=="ribbon-pig"&&Math.Abs(a.TargetX-a.X)<40){angle=-8*a.Facing;dy=0;sx=1.04;}}
            else{
                sy=1+Math.Sin(Session.Time*1.8+index)*.008;
                if(signature&&a.Id=="slime"){
                    double p=(t%2.8)/2.8;if(p<.2){sy=1-.2*Math.Sin(p/.2*Math.PI/2);sx=1+.12*Math.Sin(p/.2*Math.PI/2);}else if(p<.7){double k=(p-.2)/.5;dy=-55*Math.Sin(k*Math.PI);sy=1+.12*Math.Sin(k*Math.PI);sx=1-.06*Math.Sin(k*Math.PI);}else{double k=(p-.7)/.3;sy=1-.16*Math.Sin(k*2*Math.PI)*Math.Exp(-k*3);sx=1+.08*Math.Sin(k*2*Math.PI)*Math.Exp(-k*3);}
                }else if(signature&&a.Id=="mushroom"){sy=1-.13*Math.Pow(Math.Sin(t*1.1),2);angle=Math.Sin(t*1.4)*5;}
                else if(signature&&a.Id=="ribbon-pig"){angle=Math.Sin(t*7)*3;dxWiggle(ref x,t);}
                else if(a.Action=="jump"){dy=-Math.Abs(Math.Sin(t*3))*28;}
                else if(a.Action=="pet"){angle=Math.Sin(Math.Min(1,t)*Math.PI/2)*-4;sy=1-.02*Math.Sin(t*2);}
                else if(a.Action=="swing"){angle=Math.Sin(t*2)*7;dy=-5*Math.Cos(t*2);}
                else if(a.Action=="shake"){angle=Math.Sin(t*18)*4*Math.Max(0,1-t/4);}
                else if(a.Action=="sweep"){angle=Math.Sin(t*3)*3;}
            }
            if(Session.UsingSlot>=0 && !a.Moving && index==Session.InteractionActor){int slot=Session.UsingSlot;string item=Session.Layout[slot];if(item=="leaves")dy=-Math.Abs(Math.Sin(t*2))*7;}
            ImageSource image=null;
            if(a.Id=="ren"&&art.RenDaily!=null&&!a.Moving&&(a.Action=="polish"||signature)){
                int pose;if(a.Action=="polish"){pose=t<.8?0:t<1.4?1:t<4.5?2+(int)(t*2)%2:t<5.3?4:t<6?5:7;}else pose=t<1?0:t<3?6:t<4?5:7;
                image=art.RenDaily[pose];
            }else if(signature&&art.Signature!=null&&!a.Moving){image=art.Signature[Math.Min(5,(int)(t/1.12))];}
            else if(art.Counts!=null){if(signature&&a.Id=="slime")row=0;row=Math.Max(0,Math.Min(art.Counts.Length-1,row));int f=(int)(Session.Time/(a.Moving?.14:.24))%art.Counts[row];if(row==16)f=art.Counts[row]-1;art.Frames.TryGetValue(row+","+f,out image);}
            d.DrawEllipse(B("#26000000"),null,new Point(x,y+1),w*.29,7);
            d.PushTransform(new TranslateTransform(x,y+dy));d.PushTransform(new RotateTransform(angle));d.PushTransform(new ScaleTransform(sx,sy));
            if(image!=null)d.DrawImage(image,new Rect(-w/2,-w*190/192,w,w*208/192));
            if(a.Leaf)Prop(d,12,0,-w*(a.Id=="slime"||a.Id=="ribbon-pig"?.50:a.Id=="mushroom"?.62:.85),30,30);
            if(a.Action=="sweep") {d.PushTransform(new RotateTransform(Math.Sin(t*3)*12,30,-32));Prop(d,9,38,3,65,110);d.Pop();}
            d.Pop();d.Pop();d.Pop();
            if(index==Session.SelectedActor)d.DrawEllipse(null,new Pen(B("#C4B16D"),2),new Point(x,y+4),w*.33,9);
            Text(d,art.Name,x-42,y+12,12,"#3C5548",105);
        }
        static void dxWiggle(ref double x,double t){x+=Math.Sin(t*7)*3;}
        void Furniture(DrawingContext d,int slot){
            if(Session.Dragging&&Session.DragSlot==slot)return;string id=Session.Layout[slot];double x=Session.SlotX[slot],y=Session.SlotY[slot];
            Prop(d,PropId(id),x,y,190,145);
            if(id=="aquarium"&&PlayProps!=null)for(int i=0;i<4;i++)if(Fish[i]>0)Image(d,PlayProps[i],x-45+i*30+Math.Sin(Session.Time+i)*5,y-65+i%2*15,32,25);
            if(id=="flowers"&&PlayProps!=null)for(int i=0;i<3;i++)if(Flowers[i]>0)Image(d,PlayProps[7+i],x-36+i*36,y-35-i%2*35,50,62);
        }
        void Paint(DrawingContext d){
            if(Session==null)return;var s=Session;
            d.PushClip(new RectangleGeometry(new Rect(0,0,900,560),14,14));
            ImageSource backdrop=s.Route=="forest"?ForestArt:s.Route=="pond"?PondArt:BackgroundArt;
            if(backdrop!=null)d.DrawImage(backdrop,new Rect(0,0,900,560));else d.DrawRectangle(B("#DFEAD0"),null,new Rect(0,0,900,560));
            if(s.Weather=="night")d.DrawRectangle(B("#70213559"),null,new Rect(0,0,900,560));
            if(s.Route=="")for(int i=0;i<3;i++)Furniture(d,i);
            if(Decorating&&s.Route=="")for(int i=0;i<6;i++){d.DrawRoundedRectangle(B("#45FFFFFF"),new Pen(B("#8B9F7E"),2),new Rect(Session.SlotX[i]-105,Session.SlotY[i]-55,210,110),10,10);Text(d,"擺設區 "+(i+1),Session.SlotX[i]-32,Session.SlotY[i]-48,12);}
            if(s.Tea)Prop(d,11,485,405,115,60);
            if(s.Food)Prop(d,10,510,435,90,45);
            if(s.Crumbs)for(int i=0;i<9;i++)d.DrawEllipse(B("#BD8A4C"),null,new Point(480+i*11,441+(i%3)*3),2.5,2);
            if(s.BallVisible)Image(d,Ball,s.BallX,s.BallY,42,42);
            foreach(Point p in Messes)Image(d,Poop,p.X,p.Y,36,36);
            if(s.PoopCovered)Prop(d,2,240,435,80,46);
            if(s.Route==""&&s.UsingSlot>=3)Furniture(d,s.UsingSlot);
            if(s.Actors.Count==2&&s.Actors[0].Y>s.Actors[1].Y){DrawActor(d,1);DrawActor(d,0);}else for(int i=0;i<s.Actors.Count&&i<Art.Count;i++)DrawActor(d,i);
            if(s.Route==""){
                if(!(s.Dragging&&s.DragSlot==6))Image(d,Box,s.BoxX,s.BoxY+18,110,72);
                for(int i=3;i<6;i++)if(i!=s.UsingSlot)Furniture(d,i);
            }
            if(s.Story=="sword"&&Array.IndexOf(s.Layout,"leaves")<0)Prop(d,2,s.LeafX,s.LeafY,110,65);
            if(s.LeafBurst)for(int i=0;i<6;i++){double k=(s.PhaseAge+i*.2)%2;Prop(d,12,(s.Story=="sword"?s.LeafX:270)+Math.Sin(i*5)*50,(s.Story=="sword"?s.LeafY-100:360)+k*40,18,22);}
            if(s.Umbrella)Prop(d,8,500,285,255,200);
            if(s.Weather=="rain"||s.Story=="rain")for(int i=0;i<50;i++){double x=(i*157)%900,y=(i*71+s.Time*130)%560;d.DrawLine(new Pen(B("#709BBECA"),1.2),new Point(x,y),new Point(x-4,y+12));}
            if(s.Weather=="snow")for(int i=0;i<40;i++){double x=(i*157)%900,y=(i*71+s.Time*25)%560;d.DrawEllipse(B("#EFFFFFFF"),null,new Point(x+Math.Sin(s.Time+i)*6,y),2.5,2.5);}
            if(s.Dragging){d.PushOpacity(.8);if(s.DragSlot==6)Image(d,Box,s.DragX,s.DragY,110,72);else Prop(d,PropId(s.Layout[s.DragSlot]),s.DragX,s.DragY,190,145);d.Pop();}
            if(s.Route!=""){d.DrawRoundedRectangle(B("#DDFFFAEA"),null,new Rect(22,18,300,56),12,12);Text(d,(s.Route=="forest"?"林間小旅行":"溪畔小旅行")+" · "+Math.Min(3,s.ExpeditionStep+1)+" / 3",38,29,18);}
            d.Pop();
        }
        protected override void OnRender(DrawingContext d){base.OnRender(d);double sx=ActualWidth/900,sy=ActualHeight/560;if(sx<=0||sy<=0)return;d.PushTransform(new ScaleTransform(sx,sy));Paint(d);d.Pop();}
        public BitmapSource Snapshot(){var v=new DrawingVisual();using(var d=v.RenderOpen())Paint(d);var b=new RenderTargetBitmap(900,560,96,96,PixelFormats.Pbgra32);b.Render(v);b.Freeze();return b;}
        Point Logical(Point p){return new Point(p.X*900/Math.Max(1,ActualWidth),p.Y*560/Math.Max(1,ActualHeight));}
        int ActorAt(Point p){if(Session==null)return -1;for(int i=Session.Actors.Count-1;i>=0;i--){var a=Session.Actors[i];if(Math.Abs(p.X-a.X)<75&&p.Y>a.Y-170&&p.Y<a.Y+12&&!a.Hidden)return i;}return -1;}
        int FurnitureAt(Point p,bool front){for(int i=front?5:2;i>=(front?3:0);i--)if(Session.Layout[i]!=""&&Math.Abs(p.X-Session.SlotX[i])<95&&p.Y>=Session.SlotY[i]-145&&p.Y<=Session.SlotY[i])return i;return -1;}
        public void Press(double x,double y){
            if(Session==null||Session.Paused)return;PressX=x;PressY=y;dragged=false;Session.PointerX=x;
            if(Session.Route!=""){pressed=-1;return;}
            if(Decorating){pressed=Session.SlotAt(x,y);if(pressed>=0){if(PendingFurniture!=""){if(Session.Place(PendingFurniture,pressed))Notify();PendingFurniture="";pressed=-1;}else Session.BeginDrag(pressed);}return;}
            if(Math.Abs(x-Session.BoxX)<60&&Math.Abs(y-Session.BoxY)<60){pressed=6;Session.BeginDrag(6);return;}
            pressed=-2;
        }
        public void Move(double x,double y){if(Session==null)return;Session.PointerX=x;if(Session.Dragging){dragged|=Math.Abs(x-PressX)+Math.Abs(y-PressY)>6;Session.DragX=x;Session.DragY=y;InvalidateVisual();}}
        public void Release(double x,double y){
            if(Session==null)return;
            if(Session.Dragging){if(dragged)Session.EndDrag(x,y);else{int ds=Session.DragSlot;Session.Dragging=false;Session.DragSlot=-1;if(ds==6)Session.StartStory("box");}Notify();return;}
            if(pressed==-2){Point point=new Point(x,y);int actor=ActorAt(point),slot=FurnitureAt(point,true);
                if(slot>=0&&slot!=Session.UsingSlot)Session.UseFurniture(slot,Session.SelectedActor);
                else if(actor>=0)Session.Interact("pet",actor);
                else{slot=FurnitureAt(point,false);if(slot>=0)Session.UseFurniture(slot,Session.SelectedActor);else if(y>340&&y<470)Session.Interact("ball",Session.SelectedActor);}Notify();}pressed=-1;
        }
        void Notify(){InvalidateVisual();if(Interacted!=null)Interacted(this,EventArgs.Empty);}
        protected override void OnMouseLeftButtonDown(MouseButtonEventArgs e){base.OnMouseLeftButtonDown(e);Focus();Point p=Logical(e.GetPosition(this));Press(p.X,p.Y);CaptureMouse();e.Handled=true;}
        protected override void OnMouseMove(MouseEventArgs e){base.OnMouseMove(e);Point p=Logical(e.GetPosition(this));Move(p.X,p.Y);}
        protected override void OnMouseLeftButtonUp(MouseButtonEventArgs e){base.OnMouseLeftButtonUp(e);Point p=Logical(e.GetPosition(this));Release(p.X,p.Y);ReleaseMouseCapture();e.Handled=true;}
        protected override void OnLostMouseCapture(MouseEventArgs e){base.OnLostMouseCapture(e);if(Session!=null&&Session.Dragging){Session.Dragging=false;Session.DragSlot=-1;InvalidateVisual();}}
    }
}
