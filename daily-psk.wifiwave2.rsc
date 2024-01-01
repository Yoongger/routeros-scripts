#!rsc by RouterOS
# RouterOS script: daily-psk.wifiwave2
# Copyright (c) 2013-2024 Christian Hesse <mail@eworm.de>
#                         Michael Gisbers <michael@gisbers.de>
# https://git.eworm.de/cgit/routeros-scripts/about/COPYING.md
#
# update daily PSK (pre shared key)
# https://git.eworm.de/cgit/routeros-scripts/about/doc/daily-psk.md
#
# !! Do not edit this file, it is generated from template!

:local 0 "daily-psk.wifiwave2";
:global GlobalFunctionsReady;
:while ($GlobalFunctionsReady != true) do={ :delay 500ms; }

:global DailyPskMatchComment;
:global DailyPskQrCodeUrl;
:global Identity;

:global FormatLine;
:global LogPrintExit2;
:global ScriptLock;
:global SendNotification2;
:global SymbolForNotification;
:global UrlEncode;
:global WaitForFile;
:global WaitFullyConnected;

$ScriptLock $0;
$WaitFullyConnected;

# return pseudo-random string for PSK
:local GeneratePSK do={
  :local Date [ :tostr $1 ];

  :global DailyPskSecrets;

  :global ParseDate;

  :set Date [ $ParseDate $Date ];

  :local A ((14 - ($Date->"month")) / 12);
  :local B (($Date->"year") - $A);
  :local C (($Date->"month") + 12 * $A - 2);
  :local WeekDay (7000 + ($Date->"day") + $B + ($B / 4) - ($B / 100) + ($B / 400) + ((31 * $C) / 12));
  :set WeekDay ($WeekDay - (($WeekDay / 7) * 7));

  :return (($DailyPskSecrets->0->(($Date->"day") - 1)) . \
    ($DailyPskSecrets->1->(($Date->"month") - 1)) . \
    ($DailyPskSecrets->2->$WeekDay));
}

:local Seen ({});
:local Date [ /system/clock/get date ];
:local NewPsk [ $GeneratePSK $Date ];

:foreach AccList in=[ /interface/wifiwave2/access-list/find where comment~$DailyPskMatchComment ] do={
  :local SsidRegExp [ /interface/wifiwave2/access-list/get $AccList ssid-regexp ];
  :local Configuration ([ /interface/wifiwave2/configuration/find where ssid~$SsidRegExp ]->0);
  :local Ssid [ /interface/wifiwave2/configuration/get $Configuration ssid ];
  :local OldPsk [ /interface/wifiwave2/access-list/get $AccList passphrase ];
  :local Skip 0;

  :if ($NewPsk != $OldPsk) do={
    $LogPrintExit2 info $0 ("Updating daily PSK for " . $Ssid . " to " . $NewPsk . " (was " . $OldPsk . ")") false;
    /interface/wifiwave2/access-list/set $AccList passphrase=$NewPsk;

    :if ([ :len [ /interface/wifiwave2/actual-configuration/find where configuration.ssid=$Ssid ] ] > 0) do={
      :if ($Seen->$Ssid = 1) do={
        $LogPrintExit2 debug $0 ("Already sent a mail for SSID " . $Ssid . ", skipping.") false;
      } else={
        :local Link ($DailyPskQrCodeUrl . \
            "?scale=8&level=1&ssid=" . [ $UrlEncode $Ssid ] . "&pass=" . [ $UrlEncode $NewPsk ]);
        $SendNotification2 ({ origin=$0; \
          subject=([ $SymbolForNotification "calendar" ] . "daily PSK " . $Ssid); \
          message=("This is the daily PSK on " . $Identity . ":\n\n" . \
            [ $FormatLine "SSID" $Ssid ] . "\n" . \
            [ $FormatLine "PSK" $NewPsk ] . "\n" . \
            [ $FormatLine "Date" $Date ] . "\n\n" . \
            "A client device specific rule must not exist!"); link=$Link });
        :set ($Seen->$Ssid) 1;
      }
    }
  }
}
