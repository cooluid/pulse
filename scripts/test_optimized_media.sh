#!/bin/zsh
set -euo pipefail

SCRIPT_DIRECTORY=${0:A:h}
PROJECT_ROOT=${SCRIPT_DIRECTORY:h}
TEST_DESTINATION=${1:-"platform=iOS Simulator,name=iPhone 17 Pro,OS=latest"}

cd "$PROJECT_ROOT"

xcodebuild test \
  -project pulse.xcodeproj \
  -scheme pulse \
  -configuration Debug \
  -destination "$TEST_DESTINATION" \
  -only-testing:pulseTests/ImprintCameraViewTests \
  -only-testing:pulseTests/ImprintImageProcessorTests \
  -only-testing:pulseTests/ImprintMediaRepositoryTests \
  -only-testing:pulseTests/PulseAppModelTests \
  -only-testing:pulseTests/PulseStoreLocationTests \
  SWIFT_OPTIMIZATION_LEVEL=-O \
  SWIFT_COMPILATION_MODE=wholemodule \
  CODE_SIGNING_ALLOWED=NO
