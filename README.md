# Dynamic-island-on-hyprland
- Dynamic Island is a smooth, flexible, and fast interactive island component designed for Hyprland users.

- Based on Quickshell and C++ /Qt 6.

- Pursuting lightweight, smooth anim, and low-latency performance. 
### usage:

Memory usage: < 100 Mb (PSS)

CPU usage < 2%

## Description:


https://github.com/user-attachments/assets/306535e1-1a50-4a0f-a979-d056fa510c9e


#### Clock Mode

<div align="left">
  <img src="Preview/Preview_1.png" width="450" alt="Preview">
</div>

#### System Notifications

<div align="left">
  <img src="Preview/Preview_2.png" width="450" alt="Preview">
</div>

####  Workspace Indicator

<div align="left">
  <img src="Preview/Preview_5.png" width="450" alt="Preview">
</div>

#### Lyrics

<div align="left">
  <img src="Preview/Preview_6.png" width="450" alt="Preview">
</div>

#### Control Center

<div align="left">
  <img src="Preview/Preview_3.png" width="450" alt="Preview">
</div>


####  Music Player
<div align="left">
  <img src="Preview/Preview_4.png" width="450" alt="Preview">
</div>

### Dependencies:

#### Build-time Dependencies (Compiling the backend)
- CMake (>= 3.16)

- C++17 Compiler (GCC or Clang)

- Qt6 SDK: Specifically Core, Qml, Network, and DBus modules

- libudev-dev: Required for monitoring battery status via udev

#### Runtime Environment

- Hyprland

- Quickshell

- pactl

- wpctl

- UPower DBus service and access to /sys/class/power_supply

#### Assets & Scripts

- JetBrainsMono Nerd Font (For icons and mono text)

- Inter & Inter Display (For UI text)

- custom scripts

>Please rewrite the script path in UserConfig.qml

### Compile & run:

- Download 
```bash
git clone https://github.com/enhaoswen/Dynamic-Island-on-Hyprland.git && cd Dynamic-Island-on-Hyprland
```

> make sure you change the program if is necessary, check important things at the end.


- Build 

```bash
mkdir -p build && cd build && cmake .. && make -j$(nproc)
mkdir -p ~/.config/quickshell/dynamic_island
mv *.so qmldir ~/.config/quickshell/dynamic_island/
cp ../*.qml ~/.config/quickshell/dynamic_island/
```

- Clean 

```bash
cd ../.. && rm -rf Dynamic-Island-on-Hyprland
```

- To run in Hyprland:
```bash
QML2_IMPORT_PATH=~/.config/quickshell quickshell -p ~/.config/quickshell/dynamic_island/main.qml
```

## Important thing

- **For custom scripts, please make your own and change the path in UserConfig.qml**

- **The backend is hardcoded to read /sys/class/backlight/intel_backlight/. If you are using AMD or a different backlight driver, please update the path (SysBackend.cpp:353).**

- **The status of caps lock is currently polled via hyprctl devices. Ensure hyprctl is in your $PATH.**
