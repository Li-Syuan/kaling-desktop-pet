using System;
using System.Collections.Generic;
using System.Globalization;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace KalingPlay {
    public sealed class Stage : FrameworkElement {
        public Session Session;
        public Dictionary<string,ImageSource> Frames = new Dictionary<string,ImageSource>();
        public int[] Counts;
        public ImageSource[] Props;
        public ImageSource Box, PhotoSource;
        public string Weather="sun", Mode="bubble", CharacterName="", Caption="今天，也一起度過了。", FrameColor="cream";
        public string[] JournalLines=new string[0], StampLabels=new string[0];
        public int[] GardenStages={4,4,4}, FishCounts={0,0,0,0}, Flowers={0,0,0};
        public double[] GardenGrowth={0,0,0}, GardenWater={0,0,0};
        public bool[] GardenPlanted={false,false,false};
        public int SelectedPot, PhotoRow;
        public double Clock;
        public event EventHandler Interacted;
        public BitmapSource Snapshot() {
            var visual=new DrawingVisual();using(var context=visual.RenderOpen())OnRender(context);
            var bitmap=new RenderTargetBitmap(800,460,96,96,PixelFormats.Pbgra32);bitmap.Render(visual);bitmap.Freeze();return bitmap;
        }
        static readonly Typeface Typeface=new Typeface("Microsoft JhengHei UI");
        static Brush B(string c) { var b=(SolidColorBrush)new BrushConverter().ConvertFromString(c);b.Freeze();return b; }
        static void Rect(DrawingContext d,double x,double y,double w,double h,string color,double radius=0) {d.DrawRoundedRectangle(B(color),null,new Rect(x,y,w,h),radius,radius);}
        static void Line(DrawingContext d,double x,double y,double xx,double yy,string color,double width=2) {d.DrawLine(new Pen(B(color),width),new Point(x,y),new Point(xx,yy));}
        static void Text(DrawingContext d,string value,double x,double y,double size=16,string color="#334A41",double width=720) {
            var t=new FormattedText(value??"",CultureInfo.GetCultureInfo("zh-TW"),FlowDirection.LeftToRight,Typeface,size,B(color),1.0);t.MaxTextWidth=width;d.DrawText(t,new Point(x,y));
        }
        void Prop(DrawingContext d,int index,double x,double y,double w,double h) {
            if(Props==null || index<0 || index>=Props.Length || Props[index]==null)return;
            var im=Props[index];double s=Math.Min(w/im.Width,h/im.Height);d.DrawImage(im,new Rect(x+(w-im.Width*s)/2,y+(h-im.Height*s)/2,im.Width*s,im.Height*s));
        }
        void Actor(DrawingContext d,double x,double bottom,int row,double width=172) {
            if(Counts==null || Frames.Count==0)return;row=Math.Max(0,Math.Min(Counts.Length-1,row));
            int f=(int)(Clock/(row==16?.65:.24))%Counts[row];if(row==16)f=Counts[row]-1;
            ImageSource image;if(!Frames.TryGetValue(row+","+f,out image))return;
            double height=width*208/192;d.DrawImage(image,new Rect(x-width/2,bottom-height,width,height));
        }
        void Sky(DrawingContext d) {
            string top=Weather=="night"?"#182A49":Weather=="rain"?"#C5D7DB":Weather=="snow"?"#DDECF4":"#CFEDE7";
            d.DrawRectangle(new LinearGradientBrush((Color)ColorConverter.ConvertFromString(top),(Color)ColorConverter.ConvertFromString(Weather=="night"?"#506283":"#FFF7E6"),90),null,new Rect(0,0,800,460));
            if(Weather=="sun") {d.DrawEllipse(B("#FFE5A0"),null,new Point(684,78),38,38);Cloud(d,130,80);Cloud(d,430,55);}
            if(Weather=="night"){
                d.DrawEllipse(B("#FFECC5"),null,new Point(686,75),30,30);
                for(int i=0;i<24;i++){double x=30+(i*137)%740,y=20+(i*63)%200,r=1.4+(i%3)*.5;d.DrawEllipse(B("#F9EECA"),null,new Point(x,y),r,r);}
            } else if(Weather=="rain" || Weather=="snow") {
                Cloud(d,150,65);Cloud(d,450,55);Cloud(d,690,80);
                for(int i=0;i<38;i++){double x=20+(i*97)%770,y=(i*53+Clock*(Weather=="rain"?90:23))%335;
                    if(Weather=="rain")Line(d,x,y,x-5,y+13,"#779FAC",1.5);else d.DrawEllipse(B("#FFFFFF"),null,new Point(x+Math.Sin(Clock+i)*7,y),2.4,2.4);
                }
            }
            d.DrawEllipse(B(Weather=="night"?"#5B796E":"#BAD4A5"),null,new Point(170,420),430,115);
            d.DrawEllipse(B(Weather=="night"?"#4F6D65":"#A4C895"),null,new Point(660,440),420,135);
            Rect(d,0,420,800,40,Weather=="night"?"#455C55":"#A0BD82");
        }
        void Cloud(DrawingContext d,double x,double y) {
            Brush b=B(Weather=="rain"?"#A6BAC5":"#FAFFF8");double drift=Math.Sin(Clock*.08+x)*8;
            d.DrawEllipse(b,null,new Point(x+drift,y),40,14);d.DrawEllipse(b,null,new Point(x-14+drift,y-8),22,19);d.DrawEllipse(b,null,new Point(x+14+drift,y-12),24,23);
        }
        void DrawBoxes(DrawingContext d) {
            var s=Session;bool reveal=s.Phase=="peek" || s.Phase=="reveal" || s.Completed;
            if(reveal)Actor(d,s.Boxes[s.WinningBox],302,s.LastCorrect?3:20,128);
            for(int i=0;i<3;i++){
                double y=285;if(s.Phase=="shuffle" && (i==s.SwapA || i==s.SwapB))y+=Math.Sin(Math.PI*Math.Min(1,(s.Time-s.PhaseTime)/.55))*(i==s.SwapA?-20:20);
                if(Box!=null)d.DrawImage(Box,new Rect(s.Boxes[i]-67,y,134,100));
                if(s.Phase=="guess")Text(d,"點我",s.Boxes[i]-24,390,14);
                if(s.Phase=="reveal" && s.ChosenBox==i)Text(d,s.LastCorrect?"找到了！":"這裡沒有",s.Boxes[i]-40,405,14);
            }
        }
        protected override void OnRender(DrawingContext d) {
            base.OnRender(d);double scale=Math.Min(ActualWidth/800,ActualHeight/460);if(scale<=0)return;
            d.PushTransform(new ScaleTransform(scale,scale));d.PushClip(new RectangleGeometry(new Rect(0,0,800,460),20,20));
            if(PhotoSource!=null){double fit=Math.Min(800/PhotoSource.Width,460/PhotoSource.Height);double pw=PhotoSource.Width*fit,ph=PhotoSource.Height*fit;Rect(d,0,0,800,460,"#F6F1E5");d.DrawImage(PhotoSource,new Rect((800-pw)/2,(460-ph)/2,pw,ph));d.Pop();d.Pop();return;}
            Sky(d);var s=Session;
            if(Mode=="garden") {
                Actor(d,97,426,15,120);
                for(int i=0;i<3;i++){
                    if(i==SelectedPot)Rect(d,178+i*195,155,180,262,"#80FFFFFF",18);
                    Prop(d,GardenStages[i],190+i*195,180,155,178);Text(d,"花盆 "+(i+1),232+i*195,361,14);
                    Rect(d,208+i*195,386,125,6,"#D6DBCA",3);Rect(d,208+i*195,386,125*GardenGrowth[i]/240,6,"#6E9E71",3);
                    Text(d,GardenGrowth[i]>=240?"開花了，可以收成！":!GardenPlanted[i]?"挑一顆種子吧":GardenWater[i]>0?"有水，正在長大":"等你來澆水",197+i*195,403,12,width:170);
                }
                Text(d,"陪伴時慢慢長大，離開也不會枯萎。",32,30,18);
            } else if(Mode=="fishing") {
                d.DrawEllipse(B("#83C8D7"),new Pen(B("#DFF2DA"),7),new Point(475,313),245,92);
                for(int i=0;i<6;i++)Line(d,310+i*55,300+(i%3)*22,338+i*55,300+(i%3)*22,"#BCEAF0",2);
                Actor(d,195,380,15);Line(d,210,260,373,177,"#72543A",5);Line(d,373,177,475,291,"#DFE6D3",1);
                double bob=s!=null && s.Phase=="bite"?18:Math.Sin(Clock*2)*3;Prop(d,11,456,270+bob,35,49);
                if(s!=null && s.Phase=="bite")Text(d,"！拉竿！",430,220,24,"#BF634C");
                if(s!=null && s.Completed && s.Fish>=0)Prop(d,s.Fish,353,160,155,116);
                for(int i=0;i<4;i++){Prop(d,i,510+i*65,22,50,42);Text(d,"×"+FishCounts[i],521+i*65,66,12);}
            } else if(Mode=="boxes" && s!=null && s.Phase!="ready")DrawBoxes(d);
            else if(Mode=="picnic") {
                Prop(d,13,208,298,380,135);Prop(d,12,560,308,100,100);
                Actor(d,400,375,s==null?15:s.ActionRow);
                if(s!=null && s.Phase=="unpack")Prop(d,14,290,325,50,50);
            } else if(Mode=="photo") {
                Prop(d,7,82,273,110,145);Prop(d,8,627,270,113,145);Actor(d,400,368,PhotoRow,225);
                string border=FrameColor=="rose"?"#F3C3CF":FrameColor=="mint"?"#BDDFC9":"#F9EBCD";
                d.DrawRoundedRectangle(null,new Pen(B(border),22),new Rect(11,11,778,438),18,18);
                Rect(d,112,382,576,52,"#EFFFFFF8",14);Text(d,Caption,136,394,19,"#65544D",535);
                Text(d,CharacterName+" · 我們的小日子",28,27,15,Weather=="night"?"#FFF3D5":"#334A41");
            } else if(Mode=="journal") {
                Actor(d,95,250,15,130);Text(d,"紀念章 "+StampLabels.Length+" / 12",25,265,16);
                for(int i=0;i<Math.Min(12,StampLabels.Length);i++){Text(d,"◆ "+StampLabels[i],24+(i%2)*92,296+(i/2)*22,11,width:95);}
                Rect(d,215,23,560,409,"#EFFFFAF0",18);
                if(JournalLines.Length==0)Text(d,"一起玩一局，寫下第一篇回憶。",248,90,19);
                for(int i=0;i<Math.Min(8,JournalLines.Length);i++)Text(d,JournalLines[i],240,42+i*46,13,width:510);
            } else if(Mode=="weather") {
                Rect(d,100,70,600,280,"#44FFFFFF",20);d.DrawRoundedRectangle(null,new Pen(B("#EAD9B6"),16),new Rect(100,70,600,280),20,20);
                Line(d,400,70,400,350,"#EAD9B6",12);Actor(d,400,443,15,200);
                Text(d,Weather=="night"?"星光亮起，今晚也有我陪你。":Weather=="rain"?"聽雨的日子，一起慢慢來。":Weather=="snow"?"窗外下雪了，靠近一點就暖了。":"陽光剛好，一起曬曬太陽。",168,30,18,Weather=="night"?"#FFF3D5":"#334A41");
            } else {
                int row=s==null?0:s.ActionRow;double x=s==null?400:s.ActorX,bottom=425;
                if(Mode=="bubble" && row==4)bottom-=Math.Abs(Math.Sin(Clock*7))*15;
                Actor(d,x,bottom,row);
                if(s!=null && Mode=="bubble")foreach(var i in s.Items)if(!i.Removed){
                    d.DrawEllipse(B("#4FFFFFFF"),new Pen(B("#EEFFFFFF"),2),new Point(i.X,i.Y),i.Radius,i.Radius);
                    d.DrawEllipse(B("#DDFFFFFF"),null,new Point(i.X-i.Radius*.28,i.Y-i.Radius*.3),i.Radius*.18,i.Radius*.12);
                }
                if(s!=null && Mode=="snack")foreach(var i in s.Items)if(!i.Removed)Prop(d,i.Kind==0?14:15,i.X-24,i.Y-24,48,48);
                if(s!=null && Mode=="rhythm" && s.Phase=="playing") {
                    double distance=1+s.Beat*1.25-s.Time,r=45+Math.Max(-.3,distance)*80;
                    d.DrawEllipse(null,new Pen(B("#DDB367"),6),new Point(400,160),45,45);
                    d.DrawEllipse(null,new Pen(B("#FFF8DC"),4),new Point(400,160),Math.Max(15,r),Math.Max(15,r));
                    Text(d,(Math.Min(9,s.Beat)+1)+" / 10",375,146,18);Text(d,"點畫面或按空白鍵",320,240,17);
                }
            }
            if(s!=null && s.Phase!="ready" && Mode!="photo" && Mode!="garden" && Mode!="weather" && Mode!="journal"){
                Rect(d,18,17,194,41,"#DFFFFFF5",12);Text(d,s.Remaining>0?"得分 "+s.Score+"   ·   "+Math.Ceiling(s.Remaining)+" 秒":"得分 "+s.Score,33,26,16);
                if(s.Completed){bool retry=s.Result=="early" || s.Result=="missed";Rect(d,215,60,370,65,"#F2FFF8E8",18);Text(d,retry?"再下一竿吧":"完成了！",345,70,21);Text(d,retry?"小魚還在池塘裡等你":"成績與回憶已收進日記",285,99,13);}
            }
            d.Pop();d.Pop();
        }
        protected override void OnMouseMove(MouseEventArgs e) {base.OnMouseMove(e);if(Session!=null){var p=e.GetPosition(this);Session.Move(p.X*800/ActualWidth);InvalidateVisual();}}
        protected override void OnMouseDown(MouseButtonEventArgs e) {
            base.OnMouseDown(e);if(e.ChangedButton!=MouseButton.Left)return;Focus();var p=e.GetPosition(this);double x=p.X*800/ActualWidth,y=p.Y*460/ActualHeight;
            if(Mode=="garden" && x>=178 && x<763 && y>=155)SelectedPot=Math.Min(2,(int)((x-178)/195));
            else if(Session!=null)Session.Click(x,y);
            if(Interacted!=null)Interacted(this,EventArgs.Empty);InvalidateVisual();e.Handled=true;
        }
        protected override void OnKeyDown(KeyEventArgs e) {base.OnKeyDown(e);if(e.Key==Key.Space && Session!=null && (Mode=="rhythm" || Mode=="fishing")){Session.Click(400,160);if(Interacted!=null)Interacted(this,EventArgs.Empty);InvalidateVisual();e.Handled=true;}}
    }
}
