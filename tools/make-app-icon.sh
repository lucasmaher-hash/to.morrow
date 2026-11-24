#!/bin/sh
# Regenerates both app icon appearances. Run from the repo root:
#   sh tools/make-app-icon.sh
#
# The two recipes below ARE the design — every value was settled by eye with
# the founder (2026-09-07) and there is no other record of them.
OUT=shove95/shove95/Assets.xcassets/AppIcon.appiconset

# Light. RELIEF on: on a light ground the lit rim has nowhere brighter to go,
# so the modelling has to come from inside the bubble.
BG_TOP=B4C2DE BG_BOT=8698C0 BUB_TOP=D2DCEE BUB_BOT=9BABC9 \
INK=1E1F22 EDGE_SHADE=233C80 RELIEF=1 \
BOT=0.80 RIM_MID=0.10 TOP_A=0.42 TOPSHADE=0.26 \
OUTFILE=$OUT/icon-1024.png PREVIEW=/tmp/icon-light-preview.png \
  python3 tools/make-app-icon.py

# Dark. RELIEF off: the lit rim has all the room it needs against a dark ground.
BG_TOP=3B4A66 BG_BOT=1E2840 BUB_TOP=46536E BUB_BOT=2A3550 \
INK=DCE5F5 EDGE_LIGHT=D6E5FF EDGE_SHADE=070708 RELIEF=0 \
BOT=0.58 RIM_MID=0.15 TOP_A=0.50 TOPSHADE=0.30 \
OUTFILE=$OUT/icon-1024-dark.png PREVIEW=/tmp/icon-dark-preview.png \
  python3 tools/make-app-icon.py
