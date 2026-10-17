using System;
using System.Collections.Generic;

namespace KalingPlay {
    public sealed class Item {
        public double X, Y, Radius, Speed;
        public int Kind;
        public bool Removed;
    }

    // Pure deterministic game clock. No windows, IO, timers or save mutations.
    public sealed class Session {
        readonly Random random;
        public string Mode, Phase = "ready", Message = "", Food = "cookie", Result = "";
        public double Time, Remaining, ActorX = 400, TargetX = 400, ActorY = 395, FlashUntil;
        public bool Chasing;
        public int Score, Combo, Caught, Missed, Beat, Perfect, Round = 1, Wins, Fish = -1, ActionRow;
        public bool Completed, Committed, Paused, LastCorrect, BeatResolved;
        public readonly List<Item> Items = new List<Item>();
        public readonly double[] Boxes = {220, 400, 580};
        public int WinningBox, ChosenBox = -1, SwapA, SwapB, SwapCount;
        public double PhaseTime, BiteAt, SwapFromA, SwapFromB;
        double nextSpawn;

        public Session(string mode, int seed) { Mode = mode; random = new Random(seed); }
        public void Start() {
            Time = 0; PhaseTime = 0; Completed = false; Committed = false; Paused = false; Result = ""; Score = Combo = Caught = Missed = Beat = Perfect = Wins = 0;
            Round = 1; ActorX = TargetX = 400; Chasing = false; ActionRow = 0; FlashUntil = 0; Items.Clear(); BeatResolved = false; Fish = -1;
            if (Mode == "bubble") { Phase = "playing"; Remaining = 30; for(int i=0;i<7;i++) SpawnBubble(); Message = "點破泡泡，陪夥伴追著跳！"; }
            else if (Mode == "snack") { Phase = "playing"; Remaining = 30; nextSpawn = .3; Message = "移動滑鼠接餅乾，閃過灰色石頭。"; }
            else if (Mode == "boxes") StartBoxRound();
            else if (Mode == "fishing") { Phase = "waiting"; BiteAt = 2.5 + random.NextDouble()*3; Message = "浮標安靜漂著……等它沉下去再拉竿。"; }
            else if (Mode == "rhythm") { Phase = "playing"; Remaining = 14; Message = "光圈碰到金環時點一下，共十拍。"; }
            else if (Mode == "picnic") { Phase = "unpack"; Remaining = 20; Message = "把野餐墊鋪好，點心也帶來了。"; }
            else { Phase = "ready"; Message = ""; }
        }
        public void Cancel() { if(!Completed) { Phase="cancelled"; Items.Clear(); Result=""; } }
        void Finish(string result, string message) {
            if(Completed || Phase=="cancelled") return;
            Completed=true; Phase="done"; Result=result; Message=message; ActionRow=3; FlashUntil=Time+3;
        }
        void SpawnBubble() { Items.Add(new Item {X=70+random.NextDouble()*660,Y=90+random.NextDouble()*230,Radius=20+random.NextDouble()*14,Speed=5+random.NextDouble()*7}); }
        void StartBoxRound() {
            Phase="peek"; PhaseTime=Time; WinningBox=random.Next(3); ChosenBox=-1; SwapCount=0;
            Boxes[0]=220; Boxes[1]=400; Boxes[2]=580; Message="第 "+Round+" / 3 輪：看清楚，我躲在這個箱子！";
        }
        void StartSwap() {
            SwapA=random.Next(3);do{SwapB=random.Next(3);}while(SwapB==SwapA);
            SwapFromA=Boxes[SwapA];SwapFromB=Boxes[SwapB];PhaseTime=Time;
        }
        public void Move(double x) { if(!Paused && Mode=="snack" && Phase=="playing") ActorX=Math.Max(65,Math.Min(735,x)); }
        public void Click(double x, double y) {
            if(Paused || Completed || Phase=="ready" || Phase=="cancelled") return;
            if(Mode=="bubble" && Phase=="playing") {
                Item hit=null; foreach(var i in Items) if(!i.Removed && (i.X-x)*(i.X-x)+(i.Y-y)*(i.Y-y)<=i.Radius*i.Radius) {hit=i;break;}
                if(hit==null) { Combo=0; Message="泡泡溜走了，再瞄準一次。"; return; }
                hit.Removed=true; Combo++; Score+=10+Math.Min(5,Combo)*2; Caught++; TargetX=Math.Max(80,Math.Min(720,hit.X)); Chasing=true;
                Message=Combo+" 連擊！啵！"; SpawnBubble();
            }
            else if(Mode=="boxes" && Phase=="guess") {
                int index=-1;for(int i=0;i<3;i++) if(Math.Abs(x-Boxes[i])<72 && y>=225 && y<=390) index=i;
                if(index<0)return;ChosenBox=index;LastCorrect=index==WinningBox;if(LastCorrect){Wins++;Score+=100;}
                Phase="reveal";PhaseTime=Time;Message=LastCorrect?"找到我了！":"在另一個箱子，下一輪再試。";
            }
            else if(Mode=="fishing") Pull();
            else if(Mode=="rhythm" && Phase=="playing" && !BeatResolved && Beat<10) {
                double distance=Math.Abs(Time-(1+Beat*1.25));BeatResolved=true;
                if(distance<=.14){Score+=100;Perfect++;Message="完美！";ActionRow=4;FlashUntil=Time+.6;}
                else if(distance<=.30){Score+=50;Message="接到了！";ActionRow=3;FlashUntil=Time+.6;}
                else{Missed++;Message="太早了，跟著光圈再試。";}
            }
        }
        public void Pull() {
            if(Paused || Mode!="fishing" || Completed || Phase=="cancelled")return;
            if(Phase=="bite") { Fish=random.Next(4);Score=1;Finish("fish","釣到了！這隻小魚收進魚冊。" ); }
            else if(Phase=="waiting")Finish("early","拉得太早了，魚還沒咬鉤。再下一竿吧。" );
        }
        public void Step(double dt) {
            if(Paused || dt<=0 || dt>1 || Double.IsNaN(dt) || Double.IsInfinity(dt) || Completed || Phase=="ready" || Phase=="cancelled")return;
            Time+=dt;if(Time>FlashUntil)ActionRow=0;
            if(Mode=="bubble") {
                Remaining=Math.Max(0,30-Time);
                if(Chasing){double distance=TargetX-ActorX,step=430*dt;
                    if(Math.Abs(distance)<=step){ActorX=TargetX;Chasing=false;ActionRow=4;FlashUntil=Time+.65;}
                    else{ActorX+=Math.Sign(distance)*step;ActionRow=distance>0?1:2;}
                }
                foreach(var i in Items){i.Y-=i.Speed*dt;if(i.Y<55)i.Y=345;}
                Items.RemoveAll(i=>i.Removed);if(Remaining==0)Finish("bubble","泡泡追逐完成！得分 "+Score+"。" );
            }
            else if(Mode=="snack") {
                Remaining=Math.Max(0,30-Time);
                if(Time>=nextSpawn){nextSpawn=Time+.70;Items.Add(new Item {X=65+random.NextDouble()*670,Y=50,Radius=23,Speed=125+random.NextDouble()*50,Kind=random.Next(5)==0?1:0});}
                foreach(var i in Items){double previous=i.Y;i.Y+=i.Speed*dt;
                    if(previous<348 && i.Y>=348 && Math.Abs(i.X-ActorX)<55){i.Removed=true;
                        if(i.Kind==0){Caught++;Combo++;Score+=10+Math.Min(5,Combo)*2;ActionRow=12;Message="接住第 "+Caught+" 塊！";}
                        else{Score=Math.Max(0,Score-20);Combo=0;ActionRow=5;Message="是小石頭！要閃開喔。";}
                        FlashUntil=Time+.55;
                    }else if(i.Y>440){i.Removed=true;if(i.Kind==0){Missed++;Combo=0;}}
                }
                Items.RemoveAll(i=>i.Removed);if(Remaining==0)Finish("snack","接點心完成！接住 "+Caught+" 塊，得分 "+Score+"。" );
            }
            else if(Mode=="boxes") {
                if(Phase=="peek" && Time-PhaseTime>=1.5){Phase="shuffle";StartSwap();Message="箱子要交換位置囉……";}
                else if(Phase=="shuffle"){
                    double p=Math.Min(1,(Time-PhaseTime)/.55),ease=p*p*(3-2*p);Boxes[SwapA]=SwapFromA+(SwapFromB-SwapFromA)*ease;Boxes[SwapB]=SwapFromB+(SwapFromA-SwapFromB)*ease;
                    if(p>=1){SwapCount++;if(SwapCount>=4){Phase="guess";Message="我在哪個箱子？點一個看看！";}else StartSwap();}
                }else if(Phase=="reveal" && Time-PhaseTime>=1.5){if(Round>=3)Finish("boxes","三輪找到 "+Wins+" 次！" );else{Round++;StartBoxRound();}}
            }
            else if(Mode=="fishing") {
                if(Phase=="waiting" && Time>=BiteAt){Phase="bite";PhaseTime=Time;Message="浮標沉了！現在拉竿！";ActionRow=6;}
                else if(Phase=="bite" && Time-PhaseTime>1.25)Finish("missed","小魚游走了，再下一竿吧。" );
            }
            else if(Mode=="rhythm") {
                Remaining=Math.Max(0,13.1-Time);double target=1+Beat*1.25;
                if(!BeatResolved && Time>target+.30){BeatResolved=true;Missed++;Message="錯過這一拍，準備下一拍。";}
                if(Time>target+.5){Beat++;BeatResolved=false;if(Beat>=10)Finish("rhythm","十拍完成！完美 "+Perfect+" 次，得分 "+Score+"。" );}
            }
            else if(Mode=="picnic") {
                Remaining=Math.Max(0,20-Time);
                if(Time<2){Phase="unpack";ActionRow=3;Message="野餐墊鋪好了，今天一起慢慢來。";}
                else if(Time<7){Phase="eat";ActionRow=Food=="pudding"?13:12;Message=Food=="pudding"?"先吃一口甜甜的布丁。":"咔滋，分享一塊香香的餅乾。";}
                else if(Time<11){Phase="tea";ActionRow=14;Message="喝口茶，看看遠方的小雲。";}
                else if(Time<16){Phase="clouds";ActionRow=15;Message="這朵雲，好像一隻綠水靈。";}
                else if(Time<20){Phase="nap";ActionRow=16;Message="借這片草地，打個小盹。";}
                else Finish("picnic","今天的野餐，收進我們的日記。" );
            }
        }
    }
}
