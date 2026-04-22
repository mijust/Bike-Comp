#include "DisplayManager.h"
#include <string.h>
#include <stdio.h>

DisplayManager::DisplayManager()
    : display(SHARP_SCK, SHARP_MOSI, SHARP_SS, DISPLAY_WIDTH, DISPLAY_HEIGHT),
      currentMode(MODE_SPEED) {
    memset(mapBuffer, 0xFF, sizeof(mapBuffer)); // Fill with WHITE initially
}

void DisplayManager::init() {
    display.begin();
    display.clearDisplay();
    display.refresh();
}

void DisplayManager::updateMap(const uint8_t* mapData, size_t size) {
    if (size <= sizeof(mapBuffer)) {
        memcpy(mapBuffer, mapData, size);
    }
}

void DisplayManager::nextMode() {
    currentMode = static_cast<DisplayMode>((currentMode + 1) % 3);
}

void DisplayManager::render(float speed, int heartRate, float elevation) {
    display.clearDisplay();

    // Draw the background map
    display.drawBitmap(0, 0, mapBuffer, DISPLAY_WIDTH, DISPLAY_HEIGHT, BLACK, WHITE);

    // Draw the overlay widget
    drawWidget(speed, heartRate, elevation);

    display.refresh();
}

void DisplayManager::drawWidget(float speed, int heartRate, float elevation) {
    // Bottom right corner coordinates for the circular widget
    int16_t xCenter = DISPLAY_WIDTH - 40;
    int16_t yCenter = DISPLAY_HEIGHT - 40;
    int16_t radius = 35;

    // Clear a filled circle for the background of the widget
    display.fillCircle(xCenter, yCenter, radius, WHITE);

    // Draw an outline
    display.drawCircle(xCenter, yCenter, radius, BLACK);
    display.drawCircle(xCenter, yCenter, radius - 1, BLACK); // Thicker outline

    // Draw content depending on mode
    display.setTextColor(BLACK);
    display.setTextSize(2);

    char valueStr[10];
    char labelStr[10];

    switch (currentMode) {
        case MODE_SPEED:
            snprintf(valueStr, sizeof(valueStr), "%.1f", speed);
            snprintf(labelStr, sizeof(labelStr), "km/h");
            break;
        case MODE_HEARTRATE:
            snprintf(valueStr, sizeof(valueStr), "%d", heartRate);
            snprintf(labelStr, sizeof(labelStr), "bpm");
            break;
        case MODE_ELEVATION:
            snprintf(valueStr, sizeof(valueStr), "%.0f", elevation);
            snprintf(labelStr, sizeof(labelStr), "m");
            break;
    }

    // Simple text centering estimation
    int16_t valX = xCenter - (strlen(valueStr) * 6 * 2) / 2;
    int16_t valY = yCenter - 10;

    display.setCursor(valX, valY);
    display.print(valueStr);

    display.setTextSize(1);
    int16_t labX = xCenter - (strlen(labelStr) * 6 * 1) / 2;
    int16_t labY = yCenter + 10;

    display.setCursor(labX, labY);
    display.print(labelStr);
}
