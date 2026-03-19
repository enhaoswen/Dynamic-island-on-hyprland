# Dynamic-island-on-hyprland
- Dynamic Island is a smooth, flexible, and fast interactive island component designed for Hyprland users.

- Based on Quickshell and C++ /Qt 6.

- Pursuting lightweight, smooth anim, and low-latency performance. (Talking about some latency)

## Description:

### usage:

Memory usage: 30-60Mb

CPU usage < 0.1%

#### style 1: normal - only show time

<div align="left">
  <img src="Preview/Preview_1.png" width="450" alt="Preview">
</div>

#### style 2: split - when brightness, volume, bluetooth, etc. changes

<div align="left">
  <img src="Preview/Preview_2.png" width="450" alt="Preview">
</div>

<div align="left">
  <img src="Preview/Preview_3.png" width="450" alt="Preview">
</div>

<div align="left">
  <img src="Preview/Preview_9.png" width="450" alt="Preview">
</div>

#### style 3: long-capsules - when workspace changes

<div align="left">
  <img src="Preview/Preview_5.png" width="450" alt="Preview">
</div>

#### style 4: control-center - when right click

<div align="left">
  <img src="Preview/Preview_7.png" width="450" alt="Preview">
</div>


#### style 5: expanded - when click/ song changes

<div align="left">
  <img src="Preview/Preview_6.png" width="450" alt="Preview">
</div>

### Dependencies:

- Quickshell

- Qt6 (base & declarative)

- Hyprland

- cmake

- gcc

- pactl & pipewire

- MPRIS-compatible player 

- JetBrainsMono Nerd Font (necessary)

- Custom scripts

### Compile & run:

- Download 
```bash
git clone https://github.com/enhaoswen/Dynamic-Island-on-Hyprland.git && cd Dynamic-Island-on-Hyprland
```

> make sure you change the program if is necessary, check important things at the end.


- Build 

```bash
mkdir build && cd build && cmake .. && make -j$(nproc)
mkdir -p ~/.config/quickshell/IslandBackend
mv *.so qmldir ~/.config/quickshell/IslandBackend/
mv ../*.qml ~/.config/quickshell/
```

- Clean 

```bash
cd ../.. && rm -rf Dynamic-Island-on-Hyprland
```

- To run in Hyprland:
```bash
QML2_IMPORT_PATH=~/.config/quickshell quickshell
```

## Important thing

**For custom scripts, please make your own and change the path in shell.qml:465 (check Comment)**
