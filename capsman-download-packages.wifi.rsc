#!rsc by RouterOS
# RouterOS script: capsman-download-packages.wifi
# Copyright (c) 2018-2024 Christian Hesse <mail@eworm.de>
#                         Michael Gisbers <michael@gisbers.de>
# https://git.eworm.de/cgit/routeros-scripts/about/COPYING.md
#
# download and cleanup packages for CAP installation from CAPsMAN
# https://git.eworm.de/cgit/routeros-scripts/about/doc/capsman-download-packages.md
#
# !! Do not edit this file, it is generated from template!

:local 0 "capsman-download-packages.wifi";
:global GlobalFunctionsReady;
:while ($GlobalFunctionsReady != true) do={ :delay 500ms; }

:global CleanFilePath;
:global DownloadPackage;
:global LogPrintExit2;
:global MkDir;
:global ScriptLock;
:global WaitFullyConnected;

$ScriptLock $0;
$WaitFullyConnected;

:local PackagePath [ $CleanFilePath [ /interface/wifi/capsman/get package-path ] ];
:local InstalledVersion [ /system/package/update/get installed-version ];
:local Updated false;

:if ([ :len $PackagePath ] = 0) do={
  $LogPrintExit2 warning $0 ("The CAPsMAN package path is not defined, can not download packages.") true;
}

:if ([ :len [ /file/find where name=$PackagePath type="directory" ] ] = 0) do={
  :if ([ $MkDir $PackagePath ] = false) do={
    $LogPrintExit2 warning $0 ("Creating directory at CAPsMAN package path (" . \
      $PackagePath . ") failed!") true;
  }
  $LogPrintExit2 info $0 ("Created directory at CAPsMAN package path (" . $PackagePath . \
    "). Please place your packages!") false;
}

:foreach Package in=[ /file/find where type=package \
      package-version!=$InstalledVersion name~("^" . $PackagePath) ] do={
  :local File [ /file/get $Package ];
  :if ($File->"package-architecture" = "mips") do={
    :set ($File->"package-architecture") "mipsbe";
  }
  :if ([ $DownloadPackage ($File->"package-name") $InstalledVersion \
       ($File->"package-architecture") $PackagePath ] = true) do={
    :set Updated true;
    /file/remove $Package;
  }
}

:if ([ :len [ /file/find where type=package name~("^" . $PackagePath) ] ] = 0) do={
  $LogPrintExit2 info $0 ("No packages available, downloading default set.") false;
  :foreach Arch in={ "arm"; "arm64" } do={
    :local Packages { "arm"={ "routeros"; "wifi-qcom"; "wifi-qcom-ac" };
                    "arm64"={ "routeros"; "wifi-qcom" } };
    :foreach Package in=($Packages->$Arch) do={
      :if ([ $DownloadPackage $Package $InstalledVersion $Arch $PackagePath ] = true) do={
        :set Updated true;
      }
    }
  }
}

:if ($Updated = true) do={
  :local Script ([ /system/script/find where source~"\n# provides: capsman-rolling-upgrade\n" ]->0);
  :if ([ :len $Script ] > 0) do={
    /system/script/run $Script;
  } else={
    /interface/wifi/capsman/remote-cap/upgrade [ find where version!=$InstalledVersion ];
  }
}
