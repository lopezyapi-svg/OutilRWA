using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Windows.Forms;

namespace RwaCalculatorInstaller
{
    internal static class Program
    {
        private const string AppName = "RWA Calculator";
        private const string BundleResourceName = "RwaCalculator.Bundle.zip";

        [STAThread]
        private static int Main()
        {
            try
            {
                if (Process.GetProcessesByName("rwa_calculator").Length > 0)
                {
                    MessageBox.Show(
                        "Fermez RWA Calculator avant de lancer l'installation.",
                        AppName,
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Warning
                    );
                    return 1;
                }

                var installRoot = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                    "Programs"
                );
                var installDirectory = Path.Combine(installRoot, AppName);
                var tempDirectory = Path.Combine(
                    Path.GetTempPath(),
                    "rwa_calculator_install_" + Guid.NewGuid().ToString("N")
                );

                Directory.CreateDirectory(tempDirectory);
                Directory.CreateDirectory(installRoot);

                try
                {
                    var archivePath = Path.Combine(tempDirectory, "rwa_calculator_bundle.zip");
                    ExtractBundleArchive(archivePath);

                    if (Directory.Exists(installDirectory))
                    {
                        Directory.Delete(installDirectory, true);
                    }

                    Directory.CreateDirectory(installDirectory);
                    ZipFile.ExtractToDirectory(archivePath, installDirectory);

                    var executablePath = Path.Combine(installDirectory, "rwa_calculator.exe");
                    if (!File.Exists(executablePath))
                    {
                        throw new FileNotFoundException(
                            "L'exécutable principal est introuvable après extraction.",
                            executablePath
                        );
                    }

                    CreateShortcut(
                        Path.Combine(
                            Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),
                            AppName + ".lnk"
                        ),
                        executablePath,
                        installDirectory
                    );
                    CreateShortcut(
                        Path.Combine(
                            Environment.GetFolderPath(Environment.SpecialFolder.Programs),
                            AppName + ".lnk"
                        ),
                        executablePath,
                        installDirectory
                    );

                    Process.Start(
                        new ProcessStartInfo(executablePath)
                        {
                            UseShellExecute = true,
                            WorkingDirectory = installDirectory
                        }
                    );
                    return 0;
                }
                finally
                {
                    if (Directory.Exists(tempDirectory))
                    {
                        Directory.Delete(tempDirectory, true);
                    }
                }
            }
            catch (Exception exception)
            {
                MessageBox.Show(
                    "L'installation a échoué.\r\n\r\n" + exception.Message,
                    AppName,
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error
                );
                return 1;
            }
        }

        private static void ExtractBundleArchive(string archivePath)
        {
            using (var input = Assembly.GetExecutingAssembly()
                       .GetManifestResourceStream(BundleResourceName))
            {
                if (input == null)
                {
                    throw new InvalidOperationException(
                        "L'archive embarquée est introuvable dans l'installateur."
                    );
                }

                using (var output = File.Create(archivePath))
                {
                    input.CopyTo(output);
                }
            }
        }

        private static void CreateShortcut(
            string shortcutPath,
            string targetPath,
            string workingDirectory
        )
        {
            var shellType = Type.GetTypeFromProgID("WScript.Shell");
            if (shellType == null)
            {
                return;
            }

            dynamic shell = Activator.CreateInstance(shellType);
            dynamic shortcut = shell.CreateShortcut(shortcutPath);
            shortcut.TargetPath = targetPath;
            shortcut.WorkingDirectory = workingDirectory;
            shortcut.IconLocation = targetPath + ",0";
            shortcut.Save();
        }
    }
}
