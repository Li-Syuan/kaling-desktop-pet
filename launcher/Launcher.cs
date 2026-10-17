using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;
[assembly: AssemblyTitle("楓之谷桌面夥伴")]
[assembly: AssemblyVersion("2.0.0.0")]
[assembly: AssemblyFileVersion("2.0.0.0")]
internal static class Launcher {
    const string Version="2.0.0";
    const string Updates="https://github.com/Li-Syuan/kaling-desktop-pet/releases/latest";
    static string Q(string s){return "\""+s.Replace("\"","")+"\"";}
    [STAThread] static int Main(string[] args){
        bool test=args.Length>0&&args[0]=="--self-test";
        try{
            if(args.Length==1&&args[0]=="--version"){Console.WriteLine(Version);return 0;}
            if(args.Length==1&&args[0]=="--updates"){Process.Start(new ProcessStartInfo(Updates){UseShellExecute=true});return 0;}
            if(args.Length>0&&!test)throw new ArgumentException("可使用 --self-test、--version 或 --updates。");
            string root=AppDomain.CurrentDomain.BaseDirectory,script=Path.Combine(root,"pet.ps1");
            if(!File.Exists(script)||!Directory.Exists(Path.Combine(root,"assets"))||!File.Exists(Path.Combine(root,"lib","Pet.World.ps1")))throw new IOException("請先把整個 ZIP 全部解壓縮，再從資料夾啟動 Start.exe。請勿只複製 EXE。");
            string exe=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),@"WindowsPowerShell\v1.0\powershell.exe");
            if(!File.Exists(exe))throw new FileNotFoundException("找不到 Windows PowerShell，請確認 Windows 功能已啟用。",exe);
            string arguments="-NoProfile -STA -ExecutionPolicy Bypass -File "+Q(script),folder="";
            if(test){
                if(args.Length!=1&&!(args.Length==3&&args[1]=="--test-data"))throw new ArgumentException("自我檢查用法：Start.exe --self-test [--test-data 資料夾]");
                folder=args.Length==3?Path.GetFullPath(args[2]):Path.Combine(Path.GetTempPath(),"KalingPet-ExeTest-"+Guid.NewGuid().ToString("N"));
                Directory.CreateDirectory(folder);arguments+=" -SelfTest -TestDataDirectory "+Q(folder);
            }
            var info=new ProcessStartInfo(exe,arguments){WorkingDirectory=root,UseShellExecute=false,CreateNoWindow=true,WindowStyle=ProcessWindowStyle.Hidden,RedirectStandardOutput=test,RedirectStandardError=test};
            using(var child=Process.Start(info)){
                if(!test)return 0;
                var stderr=child.StandardError.ReadToEndAsync();string stdout=child.StandardOutput.ReadToEnd();child.WaitForExit();
                File.WriteAllText(Path.Combine(folder,"launcher-test.log"),stdout+Environment.NewLine+stderr.Result);
                Console.WriteLine("Self-test output: "+folder);return child.ExitCode;
            }
        }catch(Exception ex){if(test){Console.Error.WriteLine(ex.Message);}else{MessageBox.Show(ex.Message,"楓之谷桌面夥伴 "+Version,MessageBoxButtons.OK,MessageBoxIcon.Information);}return 1;}
    }
}
