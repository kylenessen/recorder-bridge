#!/bin/bash

echo "Building Sony Recorder Helper..."
xcodebuild -project SonyRecorderHelper.xcodeproj -scheme SonyRecorderHelper -configuration Debug clean build

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "App bundle location: ~/Library/Developer/Xcode/DerivedData/SonyRecorderHelper-*/Build/Products/Debug/SonyRecorderHelper.app"
else
    echo "❌ Build failed!"
    exit 1
fi