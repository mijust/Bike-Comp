#ifndef DISPLAYMANAGER_H
#define DISPLAYMANAGER_H

#include <Adafruit_GFX.h>
#include <Adafruit_SharpMem.h>

// Sharp Memory Display Pins for Seeed XIAO nRF52840
#define SHARP_SCK  SCK
#define SHARP_MOSI MOSI
#define SHARP_SS   D0

#define DISPLAY_WIDTH  400
#define DISPLAY_HEIGHT 240

// Colors for Sharp Memory Display
#define BLACK 0
#define WHITE 1

enum DisplayMode {
    MODE_SPEED,
    MODE_HEARTRATE,
    MODE_ELEVATION
};

class DisplayManager {
public:
    DisplayManager();
    void init();

    // Updates the map bitmap buffer
    void updateMap(const uint8_t* mapData, size_t size);

    // Switch between the three modes
    void nextMode();

    // Render the screen with the current map and widget data
    void render(float speed, int heartRate, float elevation);

private:
    Adafruit_SharpMem display;
    DisplayMode currentMode;

    // Store the raw map data (400x240 pixels = 400 * 240 / 8 bytes = 12000 bytes)
    uint8_t mapBuffer[12000];

    void drawWidget(float speed, int heartRate, float elevation);
};

#endif
