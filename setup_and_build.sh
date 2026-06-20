#!/bin/bash
set -e

# Setup formatting colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0;37m' # No Color

echo -e "${CYAN}=====================================================${NC}"
echo -e "${CYAN}             CHILLSTICK BUILD ENGINE                 ${NC}"
echo -e "${CYAN}=====================================================${NC}"

# 1. Check for Java
echo -e "\n${BLUE}[1/5] Checking Java Development Kit (JDK 17)...${NC}"
if command -v java >/dev/null 2>&1 && java -version >/dev/null 2>&1; then
    JAVA_VERSION=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2)
    echo -e "${GREEN}✓ Found working Java version: $JAVA_VERSION${NC}"
else
    echo -e "${YELLOW}⚠ Functional JDK not found in PATH. Checking Homebrew openjdk@17...${NC}"
    if [ -d "/opt/homebrew/opt/openjdk@17" ]; then
        echo -e "${GREEN}✓ Found Homebrew openjdk@17 at /opt/homebrew/opt/openjdk@17.${NC}"
        export JAVA_HOME="/opt/homebrew/opt/openjdk@17"
        export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"
    elif [ -d "/usr/local/opt/openjdk@17" ]; then
        echo -e "${GREEN}✓ Found Homebrew openjdk@17 at /usr/local/opt/openjdk@17.${NC}"
        export JAVA_HOME="/usr/local/opt/openjdk@17"
        export PATH="/usr/local/opt/openjdk@17/bin:$PATH"
    else
        echo -e "${YELLOW}Installing openjdk@17 via Homebrew...${NC}"
        brew install openjdk@17
        
        if [ -d "/opt/homebrew/opt/openjdk@17" ]; then
            export JAVA_HOME="/opt/homebrew/opt/openjdk@17"
        else
            export JAVA_HOME="/usr/local/opt/openjdk@17"
        fi
        export PATH="$JAVA_HOME/bin:$PATH"
    fi
fi

# 2. Check for Android SDK
echo -e "\n${BLUE}[2/5] Checking Android SDK...${NC}"
if [ -d "/opt/homebrew/share/android-commandlinetools" ]; then
    echo -e "${GREEN}✓ Found Homebrew Android SDK at /opt/homebrew/share/android-commandlinetools.${NC}"
    export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"
else
    echo -e "${YELLOW}⚠ Android SDK not found. Installing android-commandlinetools via Homebrew...${NC}"
    brew install --cask android-commandlinetools
    export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"
fi

# Set SDK PATH so gradle and sdkmanager can run
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

echo -e "${BLUE}Accepting Android SDK licenses and installing platform components...${NC}"
# Accept licenses
yes | sdkmanager --licenses >/dev/null 2>&1 || true
# Install Android 34 Platform and Build Tools
sdkmanager "platforms;android-34" "build-tools;34.0.0"

# Write local.properties for the gradle build
echo "sdk.dir=$ANDROID_HOME" > tv/local.properties
echo -e "${GREEN}✓ Wrote tv/local.properties: sdk.dir=$ANDROID_HOME${NC}"

# 3. Bootstrap Gradle Wrapper
echo -e "\n${BLUE}[3/5] Bootstrapping Gradle Wrapper...${NC}"
cd tv

if [ ! -f "./gradlew" ]; then
    echo -e "${YELLOW}Generating wrapper in isolated directory...${NC}"
    mkdir -p ../temp_gradle_bootstrap
    cd ../temp_gradle_bootstrap
    
    # Touch a blank settings file to satisfy Gradle 9.x layout requirements
    touch settings.gradle.kts
    
    if command -v gradle >/dev/null 2>&1; then
        gradle wrapper
    else
        echo -e "${YELLOW}Installing Gradle via Homebrew...${NC}"
        brew install gradle
        gradle wrapper
    fi
    
    # Move wrapper files to the tv root project directory
    mv gradlew ../tv/
    mv gradlew.bat ../tv/
    mv -f gradle ../tv/
    
    cd ../tv
    rm -rf ../temp_gradle_bootstrap
    echo -e "${GREEN}✓ Wrapper files generated successfully.${NC}"
else
    echo -e "${GREEN}✓ Gradle Wrapper already exists.${NC}"
fi

# Force wrapper to use Gradle 8.4
echo -e "${BLUE}Configuring Gradle Wrapper to target stable Gradle 8.4...${NC}"
sed -i '' 's/gradle-.*-bin.zip/gradle-8.4-bin.zip/g' gradle/wrapper/gradle-wrapper.properties
echo -e "${GREEN}✓ Configured wrapper: $(grep distributionUrl gradle/wrapper/gradle-wrapper.properties)${NC}"

# 4. Build the Android TV App
echo -e "\n${BLUE}[4/5] Compiling Android TV debug APK...${NC}"
chmod +x ./gradlew
./gradlew assembleDebug

echo -e "\n${GREEN}✓ Build succeeded!${NC}"
APK_PATH="app/build/outputs/apk/debug/app-debug.apk"
if [ -f "$APK_PATH" ]; then
    echo -e "${GREEN}✓ APK compiled to: tv/$APK_PATH${NC}"
else
    echo -e "${RED}✗ Error: APK not found at tv/$APK_PATH${NC}"
    exit 1
fi

# 5. Show installation instructions
echo -e "\n${CYAN}=====================================================${NC}"
echo -e "${GREEN}             INSTALLATION INSTRUCTIONS               ${NC}"
echo -e "${CYAN}=====================================================${NC}"
echo -e "Follow these steps to deploy to your Chromecast HD:"
echo -e "1. Enable ${YELLOW}Developer Options${NC} and ${YELLOW}Wireless Debugging${NC} on your Chromecast."
echo -e "2. Note your Chromecast's IP address (e.g. 192.168.1.15)."
echo -e "3. In your Mac terminal, run the following commands:"
echo -e "   ${BLUE}adb connect <chromecast-ip>:5555${NC}"
echo -e "   ${BLUE}adb install -r tv/$APK_PATH${NC}"
echo -e "4. Launch the ${YELLOW}ChillStick${NC} app on your Android TV."
echo -e "5. Open the ${YELLOW}ios/ChillStick${NC} folder in Xcode, select your iPhone, and run the controller."
echo -e "${CYAN}=====================================================${NC}"
