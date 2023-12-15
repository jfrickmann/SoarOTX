F3K.lua

The script works with your own model setup; it does not require that you use my templates. It is a standalone application that is easy to setup with your existing models. It works with both OpenTX 2.3 and EdgeTX on radios with X7 board variants and the small BW screen (QX7, TX12, Boxer, Zorro, Pocket, T8, T12, T-Pro, T-Lite, Xlite, X9lite etc.).

To use the script, copy F3K.lua over to /SCRIPTS/TELEMETRY/ on your radio's SD-card, and setup a Lua custom screen using it.

When I tested it on my old TX12, I got a memory error the first time that the script loaded. If that happens to you, just keep calm, and turn the radio off and on again - it will probably be fine. The first time that the radio loads a new script, it compiles it to a .luac file, and that consumes some extra memory. Once the .luac file has been saved, it will not do it again.

You need to add the following three INPUTs to your model:

  Lau: source is the Launch switch, used for starting and stopping the timers.
  Win: source is a switch that you assign to report the remaining window time. This is useful e.g. for "Last Flights" tasks when you are waiting to make the last launch.
  Pok: source is a dial for setting the time target for Poker.

The names of the INPUTs must be exactly as shown above, as the script is scanning for these names.

The script provides its own timers. That way you don't have to setup Global Variables and Logical switches etc. to let the script control the model's timers. The drawback is that you cannot see the timers on the radio's main screen; you have to open the script's telemetry screen and start a task. To avoid having the radio's timers giving duplicate time calls and running out of sync with the script, you should turn them off.

As always, there are two modes for the flight timer: normal and QR. In normal mode, you pull and release Launch to start, and pull and release again to stop the timer. In QR (quick relaunch) mode, it stops when you pull, and starts again immediately when you release Launch. That way, you can be a tip catching, fast relaunching pro. You toggle QR by MENU/MODEL/SHIFT/RIGHT, depending on the radio model. After starting the flight timer, there is a 10 sec. "grace period" where you can pull and release Launch again to stop the timer and cancel the flight. If you landed out and want to score a 0, then push EXIT/RETURN.

If you are flying when the window expires, then the flight timer will freeze when EoW (end of window) is on, which is the default. Then you can land and pull Launch to record the score, or give yourself a 0 if you landed out. You toggle EoW by long pressing MENU/MODEL/SHIFT/RIGHT.

You can start the window timer in two ways - either pull Launch, or push ENTER. If you push ENTER, then you get a 10 sec. countdown before the window starts. You can pause and restart the window by pressing ENTER between flights.

When the window is paused or expired, then you can leave the task by pressing EXIT/RETURN. It will ask if you want to save the scores. It will keep scores for up to 20 rounds, and you can find the score browser at the bottom of the task menu.