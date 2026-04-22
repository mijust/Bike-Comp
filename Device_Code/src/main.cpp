#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_BMP280.h>
#include <bluefruit.h>
#include "DisplayManager.h"

// Pins
#define REED_PIN D1
#define BTN1_PIN D2
#define BTN2_PIN D3

// Constants
#define DEFAULT_WHEEL_CIRCUMFERENCE 2.100 // in meters (2100 mm)
#define DEEP_SLEEP_TIMEOUT_MS 300000      // 5 minutes of inactivity

// Globals
DisplayManager displayManager;
Adafruit_BMP280 bmp;

// BLE Services
BLEUart bleuart;

// State Variables
float wheelCircumference = DEFAULT_WHEEL_CIRCUMFERENCE;
float currentSpeed = 0.0;
int currentHeartRate = 0;
float currentElevation = 0.0;

// Debouncing and Timing
volatile unsigned long lastReedTriggerTime = 0;
volatile unsigned long lastSpeedCalcTime = 0;
unsigned long lastActivityTime = 0;
unsigned long lastDisplayUpdateTime = 0;

// Map Reception
uint8_t mapRxBuffer[12000];
size_t mapRxIndex = 0;

// Interrupt Service Routines
void reedSwitchISR() {
    unsigned long now = millis();
    // Simple software debounce: ignore triggers within 50ms
    if (now - lastReedTriggerTime > 50) {
        // Calculate speed based on time since last trigger
        if (lastReedTriggerTime > 0) {
            unsigned long duration = now - lastReedTriggerTime;
            // Speed in km/h: (meters / ms) * 3600 = km/h
            currentSpeed = (wheelCircumference / duration) * 3600.0;
        }
        lastReedTriggerTime = now;
        lastSpeedCalcTime = now;
        lastActivityTime = now;
    }
}

void btn1ISR() {
    unsigned long now = millis();
    lastActivityTime = now;
}

void btn2ISR() {
    unsigned long now = millis();
    lastActivityTime = now;
}

void setupBLE() {
    Bluefruit.begin();
    Bluefruit.setTxPower(4); // Set transmit power
    Bluefruit.setName("BikeComp");

    // Configure and start BLE Uart Service
    bleuart.begin();

    // Setup Advertising
    Bluefruit.Advertising.addFlags(BLE_GAP_ADV_FLAGS_LE_ONLY_GENERAL_DISC_MODE);
    Bluefruit.Advertising.addTxPower();
    Bluefruit.Advertising.addService(bleuart);
    Bluefruit.ScanResponse.addName();

    // Start Advertising
    Bluefruit.Advertising.restartOnDisconnect(true);
    Bluefruit.Advertising.setInterval(32, 244); // in units of 0.625 ms
    Bluefruit.Advertising.setFastTimeout(30);   // number of seconds in fast mode
    Bluefruit.Advertising.start(0);             // 0 = Don't stop advertising
}

void setup() {
    Serial.begin(115200);

    // Initialize Display
    displayManager.init();

    // Initialize Pins
    pinMode(REED_PIN, INPUT_PULLUP);
    pinMode(BTN1_PIN, INPUT_PULLUP);
    pinMode(BTN2_PIN, INPUT_PULLUP);

    attachInterrupt(digitalPinToInterrupt(REED_PIN), reedSwitchISR, FALLING);
    attachInterrupt(digitalPinToInterrupt(BTN1_PIN), btn1ISR, FALLING);
    attachInterrupt(digitalPinToInterrupt(BTN2_PIN), btn2ISR, FALLING);

#ifndef MOCK_MODE
    // Initialize BMP280
    if (!bmp.begin()) {
        Serial.println(F("Could not find a valid BMP280 sensor, check wiring!"));
    }
    // BMP280 Configuration
    bmp.setSampling(Adafruit_BMP280::MODE_NORMAL,
                    Adafruit_BMP280::SAMPLING_X2,
                    Adafruit_BMP280::SAMPLING_X16,
                    Adafruit_BMP280::FILTER_X16,
                    Adafruit_BMP280::STANDBY_MS_500);
#endif

    setupBLE();

    lastActivityTime = millis();
}

void enterDeepSleep() {
    Serial.println("Entering Deep Sleep...");

    // Configure wake up pins
    nrf_gpio_cfg_sense_input(g_ADigitalPinMap[REED_PIN], NRF_GPIO_PIN_PULLUP, NRF_GPIO_PIN_SENSE_LOW);
    nrf_gpio_cfg_sense_input(g_ADigitalPinMap[BTN1_PIN], NRF_GPIO_PIN_PULLUP, NRF_GPIO_PIN_SENSE_LOW);
    nrf_gpio_cfg_sense_input(g_ADigitalPinMap[BTN2_PIN], NRF_GPIO_PIN_PULLUP, NRF_GPIO_PIN_SENSE_LOW);

    // Enter System OFF
    sd_power_system_off();
}

void loop() {
    unsigned long now = millis();

    // 1. Check for deep sleep timeout
    if (now - lastActivityTime > DEEP_SLEEP_TIMEOUT_MS) {
        enterDeepSleep();
    }

    // 2. Handle Button Presses (Polling for state change after ISR wakeup)
    static bool lastBtn1State = HIGH;
    bool currentBtn1State = digitalRead(BTN1_PIN);
    if (currentBtn1State == LOW && lastBtn1State == HIGH) {
        displayManager.nextMode();
        delay(50); // basic debounce
    }
    lastBtn1State = currentBtn1State;

    // 3. Process BLE Uart Data
    // Simple TLV (Type-Length-Value) packet structure
    // Format: [Type: 1 byte] [Length: 2 bytes] [Data: Length bytes]
    // Types: 'M' for Map Chunk, 'H' for Heartrate, 'S' for Settings
    static uint8_t bleState = 0; // 0 = wait for type, 1 = wait for len1, 2 = wait for len2, 3 = read data
    static uint8_t bleType = 0;
    static uint16_t bleLen = 0;
    static uint16_t bleReadIdx = 0;

    while (bleuart.available()) {
        uint8_t ch = bleuart.read();

        if (bleState == 0) {
            if (ch == 'M' || ch == 'H' || ch == 'S') {
                bleType = ch;
                bleState = 1;
            }
        } else if (bleState == 1) {
            bleLen = ch;
            bleState = 2;
        } else if (bleState == 2) {
            bleLen |= (ch << 8);
            bleReadIdx = 0;
            if (bleLen > 0) bleState = 3;
            else bleState = 0;
        } else if (bleState == 3) {
            if (bleType == 'M' && mapRxIndex < 12000) {
                mapRxBuffer[mapRxIndex++] = ch;
                if (mapRxIndex == 12000) {
                    displayManager.updateMap(mapRxBuffer, 12000);
                    mapRxIndex = 0;
                }
            } else if (bleType == 'H' && bleReadIdx == 0) {
                 currentHeartRate = ch; // Simplified heart rate as 1 byte
            }

            bleReadIdx++;
            if (bleReadIdx >= bleLen) {
                bleState = 0;
            }
        }
        lastActivityTime = now;
    }

    // 4. Update Sensors
#ifdef MOCK_MODE
    // Mock constant speed
    currentSpeed = 25.5;

    // Mock Elevation
    currentElevation = 150.0 + sin(now / 1000.0) * 10.0;
    // Mock Heartrate
    currentHeartRate = 120 + (now % 20);
#else
    // Read Elevation from BMP280
    currentElevation = bmp.readAltitude(1013.25); // Assume standard sea level pressure for now

    // Speed decay
    if (now - lastSpeedCalcTime > 3000) {
        currentSpeed = 0.0;
    }
#endif

    // 5. Update Display (e.g., every 500ms)
    if (now - lastDisplayUpdateTime > 500) {
        displayManager.render(currentSpeed, currentHeartRate, currentElevation);
        lastDisplayUpdateTime = now;
    }

    // 6. Power Management (System ON sleep until event)
    // Yield to let the RTOS/SoftDevice sleep
    yield();
    // waitForEvent() puts the CPU to sleep until an interrupt (BLE, Timer, Pin) occurs
    // Only use if we don't have pending display updates or other tasks
    // delay() on nRF52 Arduino core automatically calls __WFE() (Wait For Event)
}
