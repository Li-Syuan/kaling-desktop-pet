using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;

// Lossless sprite extraction from transparent authored sheets. Isolated alpha
// components are separated in memory; files on disk remain the generated source.
public sealed class RenPose {
    public BitmapSource Image;
    public int X,Y,Width,Height,Pixels;
    public double Anchor, Scale;
}
public sealed class RenPoseArt {
    public RenPose[] Daily, Actions;
    public RenPoseArt(string folder) {
        var day=Read(System.IO.Path.Combine(folder,"daily.png"));
        var rest=Read(System.IO.Path.Combine(folder,"rest.png"));
        if(day.Length!=7 || rest.Length!=2)throw new ArgumentException("Unexpected Ren source layout");
        Daily=new[]{day[0],day[1],day[2],day[3],rest[0],rest[1],day[5],day[6]};
        Actions=Read(System.IO.Path.Combine(folder,"actions.png"));
        if(Daily.Length!=8 || Actions.Length!=8) throw new ArgumentException("Ren sheets must each contain eight separate whole poses: "+Daily.Length+"/"+Actions.Length);
        // Anchors are head centers in source coordinates. All poses retain the
        // same head scale; sitting/sleeping are NOT enlarged to standing height.
        double[] da={145,503,865,1268,370,1490,937,1298};
        double[] aa={153,600,1034,1495,158,575,1103,1504};
        for(int i=0;i<8;i++){Daily[i].Anchor=da[i]-Daily[i].X;Daily[i].Scale=.365;Actions[i].Anchor=aa[i]-Actions[i].X;Actions[i].Scale=.365;}
        Daily[4].Scale=.196;Daily[5].Scale=.196;
    }
    public static RenPose[] Read(string path) {
        var b=new BitmapImage();b.BeginInit();b.CacheOption=BitmapCacheOption.OnLoad;b.UriSource=new Uri(path);b.EndInit();b.Freeze();
        var src=new FormatConvertedBitmap(b,PixelFormats.Bgra32,null,0);int w=src.PixelWidth,h=src.PixelHeight;
        var bytes=new byte[w*h*4];src.CopyPixels(bytes,w*4,0);
        var used=new bool[w*h];var queue=new int[w*h];var found=new List<RenPose>();
        for(int pos=0;pos<w*h;pos++){
            if(used[pos] || bytes[pos*4+3]<18)continue;
            int end=1,start=0,minX=pos%w,maxX=minX,minY=pos/w,maxY=minY;queue[0]=pos;used[pos]=true;
            while(start<end){
                int p=queue[start++],x=p%w,y=p/w;minX=Math.Min(minX,x);maxX=Math.Max(maxX,x);minY=Math.Min(minY,y);maxY=Math.Max(maxY,y);
                for(int dy=-1;dy<=1;dy++)for(int dx=-1;dx<=1;dx++){
                    int xx=x+dx,yy=y+dy;if(xx<0||yy<0||xx>=w||yy>=h)continue;
                    int n=yy*w+xx;if(!used[n]&&bytes[n*4+3]>=18){used[n]=true;queue[end++]=n;}
                }
            }
            if(end<3000)continue;
            int cw=maxX-minX+1,ch=maxY-minY+1;var pixels=new byte[cw*ch*4];
            // Keep only this sprite, avoiding a neighboring ponytail inside its bounding box.
            for(int n=0;n<end;n++){int p=queue[n],q=((p/w-minY)*cw+p%w-minX)*4;Buffer.BlockCopy(bytes,p*4,pixels,q,4);}
            var image=BitmapSource.Create(cw,ch,96,96,PixelFormats.Bgra32,null,pixels,cw*4);image.Freeze();
            found.Add(new RenPose{Image=image,X=minX,Y=minY,Width=cw,Height=ch,Pixels=end});
        }
        return found.OrderBy(p=>(p.Y+p.Height/2)<h/2?0:1).ThenBy(p=>p.X).ToArray();
    }
    public string Describe(){
        return string.Join("\n",Daily.Select((p,i)=>"D"+i+" "+p.X+","+p.Y+","+p.Width+","+p.Height+" pixels="+p.Pixels)
        .Concat(Actions.Select((p,i)=>"A"+i+" "+p.X+","+p.Y+","+p.Width+","+p.Height+" pixels="+p.Pixels)).ToArray());
    }
}
