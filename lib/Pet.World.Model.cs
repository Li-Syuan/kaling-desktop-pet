using System;
using System.Collections.Generic;

namespace KalingWorld {
    public sealed class Actor {
        public string Id, Action="idle";
        public double X, Y=420, TargetX, TargetY=420, Age, ActionTime=5, Facing=1;
        public bool Leaf, Hidden;
        public Actor(string id,double x){Id=id;X=TargetX=x;}
        public bool Moving {get{return Math.Abs(TargetX-X)>.8||Math.Abs(TargetY-Y)>.8;}}
        public void Pose(string action,double duration=5){Action=action;Age=0;ActionTime=duration;Hidden=false;}
        public void Step(double dt){
            Age+=dt;bool wasMoving=Moving;
            if(Moving){
                double dx=TargetX-X;
                // Return to the clear horizontal path before approaching another item.
                if(Math.Abs(dx)>.8&&Math.Abs(Y-420)>.8)Y+=Math.Sign(420-Y)*Math.Min(Math.Abs(420-Y),dt*140);
                else if(Math.Abs(dx)>.8){Facing=Math.Sign(dx);X+=Math.Sign(dx)*Math.Min(Math.Abs(dx),dt*140);}
                else{double dy=TargetY-Y;Y+=Math.Sign(dy)*Math.Min(Math.Abs(dy),dt*140);}
            }
            if(wasMoving&&!Moving)Age=0;
            if(Age>ActionTime && Action!="idle"){Pose("idle",999);}
        }
    }
    public sealed class Notice {
        public string Kind, Character, Value;
        public Notice(string kind,string character,string value){Kind=kind;Character=character;Value=value;}
    }
    // The simulation has no file, window or wall-clock dependencies.
    public sealed class Session {
        public static readonly string[] Ids={"ren","kaling","mushroom","ribbon-pig","slime"};
        public static readonly string[] Furniture={"hammock","swing","leaves","basket","aquarium","flowers","stone","shell","mushroom"};
        public static readonly double[] SlotX={145,450,755,145,450,755};
        public static readonly double[] SlotY={330,330,330,535,535,535};
        public readonly List<Actor> Actors=new List<Actor>();
        public readonly Queue<Notice> Events=new Queue<Notice>();
        public string[] Layout={"hammock","flowers","aquarium","leaves","basket","swing"};
        public string Story="", LastStory="", Branch="", Message="點點角色摸摸頭，或把球推過去。", Weather="sun";
        public string Route="", ExpeditionPhase="", Reward="", SelectedHabit="pet";
        public string[] Choices=new string[0];
        public int Phase, Lead, Buddy, ExpeditionStep, ExpeditionScore, SelectedActor, InteractionActor, UsingSlot=-1;
        public double Time, PhaseAge, NextAuto=20, BallX=520, BallY=431, BallVelocity, BoxX=650, BoxY=430;
        public bool Paused, Auto=true, BallVisible, Crumbs, Umbrella, Broom, Cloth, Tea, Food, ExpeditionComplete;
        public bool Dragging, LeafBurst, PoopCovered, BallGuided;
        public int DragSlot=-1;
        public double DragX,DragY,PointerX=450;
        public readonly Dictionary<string,int[]> Habits=new Dictionary<string,int[]>();
        readonly Random random;
        double gestureTime;
        bool gestureActive,ballTouched;
        string pendingHabit="",pendingId="";
        public Session(string primary,string companion,int seed){
            if(Array.IndexOf(Ids,primary)<0)throw new ArgumentException("Unknown primary");
            if(companion!="" && (Array.IndexOf(Ids,companion)<0 || primary==companion))throw new ArgumentException("Invalid companion");
            random=new Random(seed);Actors.Add(new Actor(primary,360));if(companion!="")Actors.Add(new Actor(companion,580));
            foreach(string id in Ids)Habits[id]=new int[4];
        }
        public int Find(string id){for(int i=0;i<Actors.Count;i++)if(Actors[i].Id==id)return i;return -1;}
        public bool Arrived {get{foreach(var a in Actors)if(a.Moving)return false;return true;}}
        public void Cancel(){
            Story="";Branch="";Phase=0;PhaseAge=0;UsingSlot=-1;Crumbs=Umbrella=Broom=Cloth=Tea=Food=LeafBurst=PoopCovered=false;
            BallVelocity=0;BallVisible=false;BallGuided=false;BallY=431;Dragging=false;DragSlot=-1;Route="";ExpeditionPhase="";ExpeditionComplete=false;Reward="";Choices=new string[0];
            gestureActive=false;ballTouched=false;gestureTime=0;pendingHabit="";pendingId="";
            foreach(var a in Actors){a.TargetX=a.X;a.TargetY=420;a.Hidden=false;a.Leaf=false;a.Pose("idle",999);}
            NextAuto=Time+22+random.Next(14);
        }
        public bool StartStory(string kind){
            if(Array.IndexOf(new[]{"sword","snack","leaves","tea","box","rain"},kind)<0)return false;
            Cancel();Story=kind;LastStory=kind;
            Lead=kind=="sword"?Find("ren"):kind=="snack"?Find("ribbon-pig"):kind=="leaves"?Find("mushroom"):-1;
            if(Lead<0)Lead=SelectedActor<Actors.Count?SelectedActor:0;Buddy=Actors.Count==2?1-Lead:Lead;
            if(kind=="sword" && Find("slime")>=0 && Find("slime")!=Lead)Buddy=Find("slime");
            BeginPhase();return true;
        }
        public double LeafX {get{int i=Array.IndexOf(Layout,"leaves");return i<0?735:SlotX[i];}}
        public double LeafY {get{int i=Array.IndexOf(Layout,"leaves");return i<0?445:SlotY[i];}}
        void Pose(int i,string action,double x,double y=420){Actors[i].TargetX=Math.Max(95,Math.Min(805,x));Actors[i].TargetY=y;Actors[i].Pose(action,30);}
        void BeginPhase(){
            PhaseAge=0;Cloth=Broom=Tea=Food=Umbrella=LeafBurst=false;
            if(Branch!=""){
                foreach(var a in Actors){a.Hidden=false;a.TargetX=a.X;a.TargetY=a.Y;}
                if(Branch=="pet"){Actors[SelectedActor].Pose("pet",4);Message="被你摸摸，先把剛才的事放一邊。";}
                else if(Branch=="bait"){Pose(Lead,"cookie",480);if(Actors.Count==2)Pose(Buddy,"watch",640);Food=true;Crumbs=false;Message="聞到新點心，立刻從箱子裡探出頭！";}
                else if(Branch=="box"){Pose(Lead,"peek",BoxX);Message="藏身處被移開了……被你發現啦。";}
                else if(Branch=="clean"){Pose(Lead,"wave",430);Broom=true;Crumbs=false;PoopCovered=false;Message="你先收乾淨了，牠向你點頭道謝。";}
                return;
            }
            switch(Story){
                case "sword":
                    if(Phase==0){Pose(Lead,Actors[Lead].Id=="ren"?"polish":"signature",350);if(Buddy!=Lead)Pose(Buddy,"watch",590);Cloth=true;Message=Actors[Lead].Id=="ren"?"蓮坐下擦劍，身邊的小夥伴好奇地望過來。":"整理好衣角，身邊的小夥伴湊過來。";}
                    if(Phase==1){Pose(Lead,"push",390);if(Buddy!=Lead)Pose(Buddy,"watch",540);BallVisible=true;BallX=420;BallGuided=true;Message="輕輕把鞠球推過去。";}
                    if(Phase==2){Pose(Buddy,"chase",LeafX,LeafY-10);Message="追上球，噗通鑽進落葉堆！";}
                    if(Phase==3){Pose(Buddy,"peek",LeafX,LeafY-55);Actors[Buddy].Leaf=true;LeafBurst=true;Message="冒出來時，頭上多了一片葉子。點牠摸摸看。";}
                    if(Phase==4){Pose(Buddy,"return",Actors.Count==2?470:400);Pose(Lead,"sit",350);Actors[Buddy].Leaf=true;Message="頂著葉子回來，靠著你一起休息。";}
                    break;
                case "snack":
                    if(Phase==0){Food=true;Pose(Lead,"sneak",510);if(Buddy!=Lead)Pose(Buddy,"signature",275);Message="桌上有點心……牠左看看、右看看。";}
                    if(Phase==1){Food=true;Crumbs=true;Pose(Lead,"cookie",510);Message="咔滋！地上留下幾顆餅乾屑。";}
                    if(Phase==2){Pose(Lead,"peek",BoxX);if(Buddy!=Lead)Pose(Buddy,"watch",460);Message="發現有人來了，趕快鑽進箱子。";}
                    if(Phase==3){Actors[Lead].Hidden=true;if(Buddy!=Lead)Pose(Buddy,"watch",BoxX-170);Message="箱子裡傳來裝睡的聲音。搬箱子、摸摸或拿點心都會有反應。";}
                    if(Phase==4){Actors[Lead].Hidden=false;Pose(Lead,"peek",BoxX);if(Buddy!=Lead)Pose(Buddy,"sweep",470);Broom=true;Crumbs=false;Message="悄悄探頭……一起把碎屑掃乾淨。";}
                    break;
                case "leaves":
                    if(Phase==0){Pose(Lead,"sneak",240);Message="牠挑了一個安靜角落，看看你有沒有注意。";}
                    if(Phase==1){Pose(Lead,"crouch",240);Message="蹲一下……葉子沙沙響。";}
                    if(Phase==2){Pose(Lead,"push",250);PoopCovered=true;LeafBurst=true;Message="拿落葉蓋住小秘密，假裝已經收好了。";}
                    if(Phase==3){Pose(Lead,"watch",350);if(Buddy!=Lead)Pose(Buddy,"jump",530);Message="夥伴跳開，回頭看了兩眼。點清理會得到感謝。";}
                    if(Phase==4){Pose(Lead,"sweep",260);Broom=true;PoopCovered=false;Message="還是把葉堆整理乾淨吧。";}
                    break;
                case "tea":
                    Tea=true;if(Phase==0){Pose(Lead,"sit",390);if(Buddy!=Lead)Pose(Buddy,"walk",580);Message="拿出茶杯，替你留了一個位置。";}
                    if(Phase==1){Pose(Lead,"tea",390);if(Buddy!=Lead)Pose(Buddy,"tea",580);Message="喝一口，慢慢來。";}
                    if(Phase==2){Pose(Lead,"sit",390);if(Buddy!=Lead)Pose(Buddy,"doze",580);Message="茶還溫著，旁邊已經開始點頭打盹了。";}break;
                case "box":
                    if(Phase==0){Pose(Lead,"peek",BoxX);if(Buddy!=Lead)Pose(Buddy,"watch",BoxX-230);Message="發現一個剛剛好的紙箱。";}
                    if(Phase==1){Actors[Lead].Hidden=true;if(Buddy!=Lead)Pose(Buddy,"peek",BoxX-150);Message="裡面有人嗎？可以搬動箱子逗牠。";}
                    if(Phase==2){Actors[Lead].Hidden=false;Pose(Lead,"wave",BoxX-180);if(Buddy!=Lead)Pose(Buddy,"peek",BoxX);Message="讓出位置，輪到你躲進去。";}break;
                case "rain":
                    Umbrella=true;if(Phase==0){Pose(Lead,"watch",420);if(Buddy!=Lead)Pose(Buddy,"walk",620);Message="雨來了，先把傘打開。";}
                    if(Phase==1){Pose(Lead,"sit",420);if(Buddy!=Lead)Pose(Buddy,"sit",535);Message="靠近一點，傘下剛好放得下。";}
                    if(Phase==2){Pose(Lead,"wave",420);if(Buddy!=Lead)Pose(Buddy,"shake",535);Message="抖掉水珠，再一起看雨。";}break;
            }
        }
        int PhaseCount {get{return Story=="tea"||Story=="box"||Story=="rain"?3:5;}}
        public void Interact(string action,int actor){
            if(actor<0||actor>=Actors.Count||Paused||Dragging)return;SelectedActor=actor;
            if(Route!="")return;
            if(Story!="" && (action=="pet"||action=="bait"||action=="box"||action=="clean")){
                Branch=action;pendingId=Actors[action=="bait"?Lead:actor].Id;pendingHabit=action=="bait"?"food":action=="clean"?"tidy":"pet";BeginPhase();return;
            }
            Cancel();SelectedActor=InteractionActor=actor;Actor a=Actors[actor];
            if(action=="ball"){BallVisible=true;BallX=Math.Max(120,Math.Min(780,PointerX));BallVelocity=70*Math.Sign(BallX-a.X);a.TargetX=BallX;a.Pose("chase",6);Message="球滾過去了！";gestureTime=6;}
            else if(action=="tea"){Tea=true;a.Pose("tea",5);Message="一起喝一口茶。";gestureTime=5;}
            else if(action=="clean"){Broom=true;a.Pose("sweep",4);Message="一起整理庭院。";gestureTime=4;}
            else if(action=="pet"){a.Pose("pet",3);Message="牠靠近你的手，開心地回應。";gestureTime=3;}
            else if(action=="bait"){Food=true;a.Pose("cookie",5);Message="拿出一塊點心，牠湊過來慢慢吃。";gestureTime=5;}
            else{a.Pose("signature",7);if(a.Id=="ribbon-pig")a.TargetX=Math.Min(760,a.X+100);else if(a.Id=="mushroom")a.TargetX=Math.Max(120,a.X-65);Message="讓你看看牠的小習慣。";gestureTime=7;}
            gestureActive=true;pendingId=a.Id;pendingHabit=action=="ball"?"ball":action=="tea"?"tea":action=="clean"?"tidy":action=="bait"?"food":action=="pet"?"pet":"";
        }
        public bool UseFurniture(int slot,int actor){
            if(slot<0||slot>=6||actor<0||actor>=Actors.Count||Route!=""||Paused)return false;
            string item=Layout[slot];if(item=="")return false;Cancel();SelectedActor=InteractionActor=actor;UsingSlot=slot;
            Actor a=Actors[actor];a.TargetX=SlotX[slot];a.TargetY=SlotY[slot]+(item=="hammock"||item=="swing"?-48:-4);a.Pose(item=="hammock"?"doze":item=="swing"?"swing":item=="leaves"?"peek":item=="basket"?"push":"watch",30);
            gestureTime=10;gestureActive=true;Message=item=="hammock"?"鑽進吊床，慢慢搖晃。":item=="swing"?"坐好，輕輕盪一下。":item=="aquarium"?"看看今天帶回來的小魚。":item=="flowers"?"湊近聞聞親手種的花。":item=="basket"?"挑一顆球，待會一起玩。":item=="leaves"?"探進葉堆，再頂著葉子冒出來。":"看看探險帶回來的小紀念。";
            return true;
        }
        public static int SlotAt(double x,double y){
            for(int i=0;i<6;i++)if(Math.Abs(x-SlotX[i])<=105 && Math.Abs(y-SlotY[i])<=55)return i;return -1;
        }
        public bool Place(string item,int slot){
            if(slot<0||slot>=6||Array.IndexOf(Furniture,item)<0)return false;
            int old=Array.IndexOf(Layout,item);string displaced=Layout[slot];if(old>=0)Layout[old]=displaced;Layout[slot]=item;return true;
        }
        public void BeginDrag(int slot){if(Route!=""||Paused||slot<0||slot>6)return;Dragging=true;DragSlot=slot;DragX=slot==6?BoxX:SlotX[slot];DragY=slot==6?BoxY:SlotY[slot];}
        public bool EndDrag(double x,double y){
            if(!Dragging)return false;int source=DragSlot;Dragging=false;DragSlot=-1;bool ok=false;
            if(source==6){if(x>=120&&x<=780&&y>=395&&y<=445){BoxX=x;BoxY=y;ok=true;if(Story=="snack"||Story=="box"){Branch="box";BeginPhase();}}}
            else{int target=SlotAt(x,y);if(target>=0){string old=Layout[source];Layout[source]=Layout[target];Layout[target]=old;ok=true;Cancel();}}
            Message=ok?"位置放好了。":"這裡要留作通道，已放回原位。";return ok;
        }
        public void StartExpedition(string route){
            if(route!="forest"&&route!="pond")return;Cancel();Route=route;ExpeditionStep=0;ExpeditionScore=0;SetTravel();
        }
        void SetTravel(){
            ExpeditionPhase="walk";PhaseAge=0;Choices=new string[0];
            for(int i=0;i<Actors.Count;i++){Actors[i].TargetX=ExpeditionStep%2==0?620-i*170:270+i*170;Actors[i].TargetY=420;Actors[i].Pose("walk",30);}
            Message="沿著小路慢慢走，看看會遇到什麼。";
        }
        void ShowEncounter(){
            ExpeditionPhase="choice";foreach(var a in Actors)a.Pose("watch",999);
            if(Route=="forest"){
                Message=new[]{"樹根下有一朵奇怪的蘑菇。","忽然飄起小雨，旁邊有一片大葉子。","落葉堆裡閃著一點光。"}[ExpeditionStep];
                Choices=ExpeditionStep==0?new[]{"靠近看看","輕輕打招呼"}:ExpeditionStep==1?new[]{"一起撐葉子","躲進樹洞"}:new[]{"撥開葉子","請夥伴找找"};
            }else{
                Message=new[]{"溪邊的石頭在陽光下發亮。","一隻小魚從水面探頭。","淺水裡有一個漂亮的貝殼。"}[ExpeditionStep];
                Choices=ExpeditionStep==0?new[]{"看看藍色石頭","看看圓潤石頭"}:ExpeditionStep==1?new[]{"蹲下看小魚","輕輕揮手"}:new[]{"撿起貝殼","找找旁邊的石頭"};
            }
        }
        public bool Choose(int choice){
            if(Route==""||ExpeditionPhase!="choice"||choice<0||choice>=Choices.Length||Paused)return false;
            ExpeditionScore+=choice;ExpeditionPhase="reaction";Choices=new string[0];PhaseAge=0;
            for(int i=0;i<Actors.Count;i++)Actors[i].Pose(choice==0?"peek":"wave",4);
            Umbrella=Route=="forest"&&ExpeditionStep==1;LeafBurst=Route=="forest"&&ExpeditionStep==2;
            Message=Route=="forest"?(ExpeditionStep==1?"肩並肩躲好雨，再往前走。":choice==0?"小心靠近，發現藏在角落的小驚喜。":"夥伴回頭招手：這裡也有！"):(choice==0?"水波晃了一下，映出兩個小小的身影。":"牠開心回應，記下這個溪邊的小發現。");return true;
        }
        public void Step(double dt){
            if(Paused||Dragging||dt<=0||dt>1||double.IsNaN(dt)||double.IsInfinity(dt))return;
            Time+=dt;foreach(var a in Actors)a.Step(dt);if(Story!=""&&!Arrived)PhaseAge=0;else PhaseAge+=dt;
            if(UsingSlot>=0&&Layout[UsingSlot]=="leaves"&&Arrived&&Actors[InteractionActor].Age>3)Actors[InteractionActor].Leaf=true;
            if(BallVisible){
                if(BallGuided){double dx=LeafX-BallX,dy=LeafY-15-BallY,len=Math.Sqrt(dx*dx+dy*dy);if(len>.1){double speed=Math.Min(len,dt*130);BallX+=dx/len*speed;BallY+=dy/len*speed;}}
                else{BallX+=BallVelocity*dt;BallVelocity*=Math.Exp(-dt*1.8);if(BallX<100||BallX>800){BallX=Math.Max(100,Math.Min(800,BallX));BallVelocity=0;}}
            }
            if(gestureActive&&pendingHabit=="ball"&&!ballTouched){
                Actor a=Actors[InteractionActor];a.TargetX=Math.Max(95,Math.Min(805,BallX-30*a.Facing));
                if(Math.Abs(a.X-BallX)<40&&Math.Abs(BallVelocity)<20){a.TargetX=a.X;a.Pose("push",3);BallVelocity=70*a.Facing;ballTouched=true;}
            }
            if(Route!=""){
                if(ExpeditionPhase=="walk"&&PhaseAge>=5&&Arrived)ShowEncounter();
                else if(ExpeditionPhase=="reaction"&&PhaseAge>=4){
                    Umbrella=LeafBurst=false;ExpeditionStep++;
                    if(ExpeditionStep>=3){ExpeditionPhase="complete";ExpeditionComplete=true;Reward=Route=="forest"?(ExpeditionScore%2==0?"mushroom":"stone"):(ExpeditionScore%2==0?"shell":"stone");Message="回家囉！帶回一件紀念物，可以擺進庭院。";foreach(var a in Actors)a.Pose("wave",4);Events.Enqueue(new Notice("expedition",Actors[0].Id,Reward));}
                    else SetTravel();
                }return;
            }
            if(Story!=""){
                if(PhaseAge>=(Branch!=""?4:Story=="snack"&&Phase==3||Story=="sword"&&Phase==0?8:5)&&Arrived){
                    if(Branch!=""||Phase+1>=PhaseCount){string finished=Story+(Branch==""?"":"-"+Branch);foreach(var a in Actors)Events.Enqueue(new Notice("story",a.Id,finished));CommitInteraction();Cancel();Message="這段小日常，也一起記下了。";}
                    else{if(Story=="snack"&&Phase==1)Events.Enqueue(new Notice("meal",Actors[Lead].Id,"cookie"));if(Story=="tea"&&Phase==1)foreach(var a in Actors)Events.Enqueue(new Notice("habit",a.Id,"tea"));Phase++;BeginPhase();}
                }return;
            }
            if(gestureActive){if(Arrived&&(pendingHabit!="ball"||ballTouched))gestureTime=Math.Max(0,gestureTime-dt);if(gestureTime<=0&&Arrived){CommitInteraction();gestureActive=false;UsingSlot=-1;Tea=Broom=Food=false;foreach(var a in Actors){a.TargetY=420;a.Pose("idle",999);}}}
            if(Auto&&Time>=NextAuto&&gestureTime<=0&&Arrived){
                if(random.Next(3)==0){int slot=random.Next(6);if(Layout[slot]!=""){UseFurniture(slot,random.Next(Actors.Count));return;}}
                int[] h=Habits[Actors[random.Next(Actors.Count)].Id];int max=0;for(int i=1;i<4;i++)if(h[i]>h[max])max=i;
                string[] choices={"sword","snack","leaves","tea","box","rain"};
                string kind=h[max]>=3&&random.Next(3)==0?(max==1?"tea":max==2?"sword":max==3?"leaves":"box"):choices[random.Next(choices.Length)];
                if(Weather=="rain"&&LastStory!="rain")kind="rain";if(kind==LastStory)kind=choices[(Array.IndexOf(choices,kind)+1)%choices.Length];StartStory(kind);
            }
        }
        void CommitInteraction(){if(pendingHabit!=""){Events.Enqueue(new Notice(pendingHabit=="food"?"meal":"habit",pendingId,pendingHabit=="food"?"cookie":pendingHabit));pendingHabit="";pendingId="";}}
    }
}
